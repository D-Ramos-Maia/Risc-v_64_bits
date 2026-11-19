// decoder.sv
module decoder
    import rv_pkg::*;
(
    input  logic [31:0] instr,

    // campos
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,

    // controle
    output alu_op_e     alu_op,
    output logic        alu_src_a_pc,   // 1 = A vem do PC (AUIPC)
    output logic        alu_src_b_imm,  // 1 = B vem do imediato
    output logic        word_op,        // 1 = operação de 32 bits (*W), resultado sinal-estendido
    output logic        reg_write,
    output wb_sel_e     wb_sel,
    output logic        mem_read,
    output logic        mem_write,
    output mem_size_e   mem_size,
    output logic        is_branch,
    output branch_e     branch_type,
    output logic        is_jal,
    output logic        is_jalr,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic        is_fence,
    output logic        illegal
);

    logic [6:0] opcode, funct7;
    logic [2:0] funct3;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign rd     = instr[11:7];

    assign mem_size    = mem_size_e'(funct3);
    assign branch_type = branch_e'(funct3);

    always_comb begin
        // ---------- valores padrão (evita latches) ----------
        alu_op        = ALU_ADD;
        alu_src_a_pc  = 1'b0;
        alu_src_b_imm = 1'b0;
        word_op       = 1'b0;
        reg_write     = 1'b0;
        wb_sel        = WB_ALU;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        is_branch     = 1'b0;
        is_jal        = 1'b0;
        is_jalr       = 1'b0;
        is_ecall      = 1'b0;
        is_ebreak     = 1'b0;
        is_fence      = 1'b0;
        illegal       = 1'b0;

        unique case (opcode_e'(opcode))

            // ---------------- LUI ----------------
            OP_LUI: begin
                alu_op        = ALU_PASS_B;
                alu_src_b_imm = 1'b1;
                reg_write     = 1'b1;
            end

            // ---------------- AUIPC ----------------
            OP_AUIPC: begin
                alu_op        = ALU_ADD;
                alu_src_a_pc  = 1'b1;
                alu_src_b_imm = 1'b1;
                reg_write     = 1'b1;
            end

            // ---------------- JAL ----------------
            OP_JAL: begin
                is_jal    = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_PC4;
            end

            // ---------------- JALR ----------------
            OP_JALR: begin
                if (funct3 != 3'b000) illegal = 1'b1;
                else begin
                    is_jalr       = 1'b1;
                    alu_op        = ALU_ADD;      // rs1 + imm (alvo)
                    alu_src_b_imm = 1'b1;
                    reg_write     = 1'b1;
                    wb_sel        = WB_PC4;
                end
            end

            // ---------------- BRANCH ----------------
            OP_BRANCH: begin
                is_branch = 1'b1;
                unique case (funct3)
                    3'b000, 3'b001, 3'b100,
                    3'b101, 3'b110, 3'b111: ;
                    default: illegal = 1'b1;
                endcase
            end

            // ---------------- LOAD ----------------
            OP_LOAD: begin
                alu_op        = ALU_ADD;
                alu_src_b_imm = 1'b1;
                mem_read      = 1'b1;
                reg_write     = 1'b1;
                wb_sel        = WB_MEM;
                unique case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b011,
                    3'b100, 3'b101, 3'b110: ;
                    default: illegal = 1'b1;
                endcase
            end

            // ---------------- STORE ----------------
            OP_STORE: begin
                alu_op        = ALU_ADD;
                alu_src_b_imm = 1'b1;
                mem_write     = 1'b1;
                unique case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b011: ;
                    default: illegal = 1'b1;
                endcase
            end

            // ---------------- OP-IMM / OP-IMM-32 ----------------
            OP_IMM, OP_IMM32: begin
                alu_src_b_imm = 1'b1;
                reg_write     = 1'b1;
                word_op       = (opcode_e'(opcode) == OP_IMM32);

                unique case (funct3)
                    3'b000: alu_op = ALU_ADD;                 // ADDI / ADDIW
                    3'b010: alu_op = ALU_SLT;                 // SLTI
                    3'b011: alu_op = ALU_SLTU;                // SLTIU
                    3'b100: alu_op = ALU_XOR;                 // XORI
                    3'b110: alu_op = ALU_OR;                  // ORI
                    3'b111: alu_op = ALU_AND;                 // ANDI

                    3'b001: begin                             // SLLI / SLLIW
                        alu_op = ALU_SLL;
                        // RV64: shamt de 6 bits => funct7[6:1] deve ser 0
                        // (para W, shamt tem 5 bits => funct7 inteiro = 0)
                        if (word_op ? (funct7 != 7'b0)
                                    : (funct7[6:1] != 6'b0))
                            illegal = 1'b1;
                    end

                    3'b101: begin                             // SRLI/SRAI (+W)
                        if (word_op) begin
                            if      (funct7 == 7'b0000000) alu_op = ALU_SRL;
                            else if (funct7 == 7'b0100000) alu_op = ALU_SRA;
                            else                           illegal = 1'b1;
                        end else begin
                            if      (funct7[6:1] == 6'b000000) alu_op = ALU_SRL;
                            else if (funct7[6:1] == 6'b010000) alu_op = ALU_SRA;
                            else                               illegal = 1'b1;
                        end
                    end

                    default: illegal = 1'b1;
                endcase

                // OP-IMM-32 só existe para ADDIW, SLLIW, SRLIW, SRAIW
                if (word_op && !(funct3 inside {3'b000, 3'b001, 3'b101}))
                    illegal = 1'b1;
            end

            // ---------------- OP / OP-32 ----------------
            OP_REG, OP_REG32: begin
                reg_write = 1'b1;
                word_op   = (opcode_e'(opcode) == OP_REG32);

                unique case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_op = ALU_ADD;   // ADD / ADDW
                    {7'b0100000, 3'b000}: alu_op = ALU_SUB;   // SUB / SUBW
                    {7'b0000000, 3'b001}: alu_op = ALU_SLL;   // SLL / SLLW
                    {7'b0000000, 3'b010}: alu_op = ALU_SLT;   // SLT
                    {7'b0000000, 3'b011}: alu_op = ALU_SLTU;  // SLTU
                    {7'b0000000, 3'b100}: alu_op = ALU_XOR;   // XOR
                    {7'b0000000, 3'b101}: alu_op = ALU_SRL;   // SRL / SRLW
                    {7'b0100000, 3'b101}: alu_op = ALU_SRA;   // SRA / SRAW
                    {7'b0000000, 3'b110}: alu_op = ALU_OR;    // OR
                    {7'b0000000, 3'b111}: alu_op = ALU_AND;   // AND
                    default:              illegal = 1'b1;     // inclui ext. M (funct7=1)
                endcase

                // SLT, SLTU, XOR, OR, AND não têm versão W
                if (word_op && (funct3 inside {3'b010, 3'b011,
                                               3'b100, 3'b110, 3'b111}))
                    illegal = 1'b1;
            end

            // ---------------- FENCE ----------------
            OP_FENCE: begin
                is_fence = 1'b1;      // tratado como NOP em single-hart
            end

            // ---------------- SYSTEM ----------------
            OP_SYSTEM: begin
                if (instr == 32'h0000_0073)      is_ecall  = 1'b1;
                else if (instr == 32'h0010_0073) is_ebreak = 1'b1;
                else                             illegal   = 1'b1;  // CSRs: depois
            end

            default: illegal = 1'b1;
        endcase

        // Instrução ilegal nunca escreve nem acessa memória
        if (illegal) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            is_branch = 1'b0;
            is_jal    = 1'b0;
            is_jalr   = 1'b0;
        end
    end

endmodule