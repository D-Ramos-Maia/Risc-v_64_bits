// core.sv
module core
    import rv_pkg::*;
#(
    parameter logic [63:0] RESET_VECTOR = 64'h0000_0000_8000_0000
) (
    input  logic        clk,
    input  logic        rst_n,

    // porta de instruções
    output logic [63:0] imem_addr,
    input  logic [31:0] imem_instr,
    input  logic        imem_fault,

    // porta de dados
    output logic [63:0] dmem_addr,
    output logic        dmem_we,
    output mem_size_e   dmem_size,
    output logic [63:0] dmem_wdata,
    input  logic [63:0] dmem_rdata,
    input  logic        dmem_misaligned,
    input  logic        dmem_access_fault,

    // interrupções
    input  logic        irq_timer,
    input  logic        irq_ext,
    input  logic        irq_sw
);

    // =====================================================================
    // Fetch
    // =====================================================================
    logic [63:0] pc_q, pc_next, pc_plus4, np_next;
    logic [31:0] instr;

    assign instr     = imem_instr;
    assign imem_addr = pc_q;

    pc #(.RESET_VECTOR(RESET_VECTOR)) u_pc (
        .clk(clk), .rst_n(rst_n), .pc_en(1'b1),
        .pc_next(pc_next), .pc_o(pc_q)
    );

    // =====================================================================
    // Decode
    // =====================================================================
    logic [4:0]  rs1, rs2, rd;
    alu_op_e     alu_op;
    logic        alu_src_a_pc, alu_src_b_imm, word_op, reg_write;
    wb_sel_e     wb_sel;
    logic        mem_read, mem_write;
    mem_size_e   mem_size;
    logic        is_branch, is_jal, is_jalr, is_ecall, is_ebreak, is_fence, illegal;
    branch_e     branch_type;
    logic [63:0] imm;

    decoder u_dec (
        .instr, .rs1, .rs2, .rd, .alu_op, .alu_src_a_pc, .alu_src_b_imm,
        .word_op, .reg_write, .wb_sel, .mem_read, .mem_write, .mem_size,
        .is_branch, .branch_type, .is_jal, .is_jalr, .is_ecall, .is_ebreak,
        .is_fence, .illegal
    );

    logic is_muldiv, is_csr, is_mret, is_wfi, ext_reg_write, ext_hit;

    ext_decoder u_ext (
        .instr, .is_muldiv, .is_csr, .is_mret, .is_wfi,
        .ext_reg_write, .ext_hit
    );

    imm_gen u_imm (.instr, .imm);

    // =====================================================================
    // Execute
    // =====================================================================
    logic [63:0] rs1_data, rs2_data, wb_data;
    logic        rf_we;

    regfile u_rf (
        .clk, .rs1, .rs1_data, .rs2, .rs2_data,
        .we(rf_we), .rd, .rd_data(wb_data)
    );

    logic [63:0] alu_a, alu_b, alu_result, md_result, ex_result;

    assign alu_a = alu_src_a_pc  ? pc_q : rs1_data;
    assign alu_b = alu_src_b_imm ? imm  : rs2_data;

    alu u_alu (
        .alu_op, .word_op, .a(alu_a), .b(alu_b), .result(alu_result)
    );

    muldiv u_md (
        .funct3(instr[14:12]), .word_op,
        .a(rs1_data), .b(rs2_data), .result(md_result)
    );

    assign ex_result = is_muldiv ? md_result : alu_result;

    logic br_taken;

    branch_unit u_br (
        .is_branch, .branch_type, .rs1_data, .rs2_data, .taken(br_taken)
    );

    // =====================================================================
    // Alvos de salto
    // =====================================================================
    logic [63:0] pc_plus_imm, branch_target;
    logic        take_branch, target_misaligned;

    assign pc_plus_imm   = pc_q + imm;
    assign branch_target = is_jalr ? {alu_result[63:1], 1'b0} : pc_plus_imm;
    assign take_branch   = br_taken | is_jal | is_jalr;
    assign target_misaligned = take_branch & branch_target[1];   // sem ext. C

    next_pc u_npc (
        .pc(pc_q), .branch_target, .take_branch,
        .pc_plus4, .pc_next(np_next)
    );

    // =====================================================================
    // Memória de dados
    // =====================================================================
    logic irq_pending;

    assign dmem_addr  = alu_result;
    assign dmem_size  = mem_size;
    assign dmem_wdata = rs2_data;
    assign dmem_we    = mem_write & ~irq_pending;   // a dmem bloqueia sozinha em fault

    // =====================================================================
    // CSRs e traps
    // =====================================================================
    logic [63:0] csr_rdata, irq_cause, trap_vector, mepc;
    logic        csr_illegal;
    logic        trap_taken, mret_taken;
    logic [63:0] trap_cause, trap_val;
    logic        illegal_final;

    assign illegal_final = (illegal & ~ext_hit) | csr_illegal;

    // prioridade: interrupção > fetch fault > ilegal > ebreak > ecall > ...
    always_comb begin
        trap_taken = 1'b1;
        trap_cause = 64'd0;
        trap_val   = 64'd0;

        if (irq_pending) begin
            trap_cause = irq_cause;
        end else if (imem_fault) begin
            trap_cause = 64'd1;  trap_val = pc_q;                 // instr access fault
        end else if (illegal_final) begin
            trap_cause = 64'd2;  trap_val = {32'b0, instr};       // illegal instruction
        end else if (is_ebreak) begin
            trap_cause = 64'd3;  trap_val = pc_q;                 // breakpoint
        end else if (is_ecall) begin
            trap_cause = 64'd11;                                  // ecall de M-mode
        end else if (target_misaligned) begin
            trap_cause = 64'd0;  trap_val = branch_target;        // instr misaligned
        end else if (mem_read && dmem_misaligned) begin
            trap_cause = 64'd4;  trap_val = dmem_addr;            // load misaligned
        end else if (mem_read && dmem_access_fault) begin
            trap_cause = 64'd5;  trap_val = dmem_addr;            // load access fault
        end else if (mem_write && dmem_misaligned) begin
            trap_cause = 64'd6;  trap_val = dmem_addr;            // store misaligned
        end else if (mem_write && dmem_access_fault) begin
            trap_cause = 64'd7;  trap_val = dmem_addr;            // store access fault
        end else begin
            trap_taken = 1'b0;
        end
    end

    assign mret_taken = is_mret & ~trap_taken;

    csr_unit u_csr (
        .clk, .rst_n,
        .csr_en(is_csr), .csr_funct3(instr[14:12]), .csr_addr(instr[31:20]),
        .csr_rs1_idx(rs1), .rs1_data,
        .csr_rdata, .csr_illegal,
        .trap_taken, .trap_pc(pc_q), .trap_cause, .trap_val,
        .mret_taken, .retire(~trap_taken),
        .irq_timer, .irq_ext, .irq_sw, .irq_pending, .irq_cause,
        .trap_vector, .mepc_o(mepc)
    );

    // =====================================================================
    // Write-back
    // =====================================================================
    assign rf_we = (reg_write | ext_reg_write) & ~trap_taken;

    always_comb begin
        case (wb_sel)
            WB_MEM:  wb_data = dmem_rdata;
            WB_PC4:  wb_data = pc_plus4;
            default: wb_data = is_csr ? csr_rdata : ex_result;
        endcase
    end

    // =====================================================================
    // Próximo PC
    // =====================================================================
    always_comb begin
        if      (trap_taken) pc_next = trap_vector;
        else if (mret_taken) pc_next = mepc;
        else                 pc_next = np_next;
    end

endmodule