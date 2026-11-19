// csr_unit.sv
module csr_unit (
    input  logic        clk,
    input  logic        rst_n,

    // acesso Zicsr
    input  logic        csr_en,
    input  logic [2:0]  csr_funct3,
    input  logic [11:0] csr_addr,
    input  logic [4:0]  csr_rs1_idx,     // índice rs1 ou zimm
    input  logic [63:0] rs1_data,
    output logic [63:0] csr_rdata,
    output logic        csr_illegal,

    // traps
    input  logic        trap_taken,      // exceção OU interrupção sendo tomada
    input  logic [63:0] trap_pc,
    input  logic [63:0] trap_cause,
    input  logic [63:0] trap_val,
    input  logic        mret_taken,
    input  logic        retire,

    // interrupções externas ao core
    input  logic        irq_timer,
    input  logic        irq_ext,
    input  logic        irq_sw,
    output logic        irq_pending,
    output logic [63:0] irq_cause,

    output logic [63:0] trap_vector,
    output logic [63:0] mepc_o
);

    localparam logic [63:0] MISA = 64'h8000_0000_0000_1100;   // RV64 + I + M

    // ---------------- estado ----------------
    logic        mie_bit, mpie_bit;           // mstatus.MIE / MPIE
    logic [63:0] mie_q, mtvec_q, mscratch_q, mepc_q, mcause_q, mtval_q;
    logic [63:0] mcycle_q, minstret_q;

    logic [63:0] mstatus, mip;
    assign mstatus = {51'b0, 2'b11, 3'b0, mpie_bit, 3'b0, mie_bit, 3'b0};  // MPP = M
    assign mip     = {52'b0, irq_ext, 3'b0, irq_timer, 3'b0, irq_sw, 3'b0};

    assign mepc_o = mepc_q;

    // ---------------- leitura ----------------
    logic known;

    always_comb begin
        csr_rdata = 64'h0;
        known     = 1'b1;
        case (csr_addr)
            12'h300: csr_rdata = mstatus;
            12'h301: csr_rdata = MISA;
            12'h304: csr_rdata = mie_q;
            12'h305: csr_rdata = mtvec_q;
            12'h340: csr_rdata = mscratch_q;
            12'h341: csr_rdata = mepc_q;
            12'h342: csr_rdata = mcause_q;
            12'h343: csr_rdata = mtval_q;
            12'h344: csr_rdata = mip;
            12'hB00, 12'hC00: csr_rdata = mcycle_q;
            12'hB02, 12'hC02: csr_rdata = minstret_q;
            // somente leitura = 0
            12'hF11, 12'hF12, 12'hF13, 12'hF14: csr_rdata = 64'h0;
            // RAZ/WI (exigidos pelo código de init do riscv-tests)
            12'h180, 12'h302, 12'h303, 12'h3A0, 12'h3B0: csr_rdata = 64'h0;
            default: known = 1'b0;
        endcase
    end

    // ---------------- cálculo da escrita ----------------
    logic [63:0] operand, new_val;
    logic        does_write, read_only, do_write;

    assign operand    = csr_funct3[2] ? {59'b0, csr_rs1_idx} : rs1_data;
    assign does_write = (csr_funct3[1:0] == 2'b01) || (csr_rs1_idx != 5'd0);
    assign read_only  = (csr_addr[11:10] == 2'b11);

    assign csr_illegal = csr_en && (!known || (does_write && read_only));
    assign do_write    = csr_en && does_write && !csr_illegal && !trap_taken;

    always_comb begin
        case (csr_funct3[1:0])
            2'b01:   new_val = operand;                  // CSRRW(I)
            2'b10:   new_val = csr_rdata | operand;      // CSRRS(I)
            2'b11:   new_val = csr_rdata & ~operand;     // CSRRC(I)
            default: new_val = csr_rdata;
        endcase
    end

    // ---------------- interrupções ----------------
    assign irq_pending = mie_bit & (|(mip & mie_q));

    always_comb begin
        if      (mip[11] & mie_q[11]) irq_cause = {1'b1, 59'd0, 4'd11};  // externa
        else if (mip[3]  & mie_q[3])  irq_cause = {1'b1, 59'd0, 4'd3};   // software
        else                          irq_cause = {1'b1, 59'd0, 4'd7};   // timer
    end

    // ---------------- vetor de trap ----------------
    logic [63:0] base;
    assign base = {mtvec_q[63:2], 2'b00};
    assign trap_vector = (mtvec_q[0] && trap_cause[63])
                         ? base + {trap_cause[61:0], 2'b00}
                         : base;

    // ---------------- escrita sequencial ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mie_bit    <= 1'b0;
            mpie_bit   <= 1'b0;
            mie_q      <= 64'h0;
            mtvec_q    <= 64'h0;
            mscratch_q <= 64'h0;
            mepc_q     <= 64'h0;
            mcause_q   <= 64'h0;
            mtval_q    <= 64'h0;
            mcycle_q   <= 64'h0;
            minstret_q <= 64'h0;
        end else begin
            mcycle_q <= mcycle_q + 64'd1;
            if (retire) minstret_q <= minstret_q + 64'd1;

            if (do_write) begin
                case (csr_addr)
                    12'h300: begin mie_bit <= new_val[3]; mpie_bit <= new_val[7]; end
                    12'h304: mie_q      <= new_val & 64'h0000_0000_0000_0888;
                    12'h305: mtvec_q    <= {new_val[63:2], 1'b0, new_val[0]};
                    12'h340: mscratch_q <= new_val;
                    12'h341: mepc_q     <= new_val & ~64'h3;
                    12'h342: mcause_q   <= new_val;
                    12'h343: mtval_q    <= new_val;
                    12'hB00: mcycle_q   <= new_val;
                    12'hB02: minstret_q <= new_val;
                    default: ;
                endcase
            end

            // trap e MRET têm prioridade
            if (trap_taken) begin
                mepc_q   <= trap_pc & ~64'h3;
                mcause_q <= trap_cause;
                mtval_q  <= trap_val;
                mpie_bit <= mie_bit;
                mie_bit  <= 1'b0;
            end else if (mret_taken) begin
                mie_bit  <= mpie_bit;
                mpie_bit <= 1'b1;
            end
        end
    end

endmodule