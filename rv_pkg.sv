// rv_pkg.sv
package rv_pkg;

    // ---------------- Opcodes (inst[6:0]) ----------------
    typedef enum logic [6:0] {
        OP_LUI      = 7'b0110111,
        OP_AUIPC    = 7'b0010111,
        OP_JAL      = 7'b1101111,
        OP_JALR     = 7'b1100111,
        OP_BRANCH   = 7'b1100011,
        OP_LOAD     = 7'b0000011,
        OP_STORE    = 7'b0100011,
        OP_IMM      = 7'b0010011,
        OP_REG      = 7'b0110011,
        OP_IMM32    = 7'b0011011,   // ADDIW, SLLIW, SRLIW, SRAIW
        OP_REG32    = 7'b0111011,   // ADDW, SUBW, SLLW, SRLW, SRAW
        OP_FENCE    = 7'b0001111,
        OP_SYSTEM   = 7'b1110011
    } opcode_e;

    // ---------------- Operações da ULA ----------------
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_SLL  = 4'd2,
        ALU_SLT  = 4'd3,
        ALU_SLTU = 4'd4,
        ALU_XOR  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_OR   = 4'd8,
        ALU_AND  = 4'd9,
        ALU_PASS_B = 4'd10          // usado pelo LUI (resultado = imm)
    } alu_op_e;

    // ---------------- Tipo de branch (funct3) ----------------
    typedef enum logic [2:0] {
        BR_EQ  = 3'b000,
        BR_NE  = 3'b001,
        BR_LT  = 3'b100,
        BR_GE  = 3'b101,
        BR_LTU = 3'b110,
        BR_GEU = 3'b111
    } branch_e;

    // ---------------- Origem do dado de write-back ----------------
    typedef enum logic [1:0] {
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC4 = 2'd2               // JAL / JALR
    } wb_sel_e;

    // ---------------- Tamanho de acesso à memória (funct3) ----------------
    typedef enum logic [2:0] {
        MEM_B  = 3'b000,
        MEM_H  = 3'b001,
        MEM_W  = 3'b010,
        MEM_D  = 3'b011,
        MEM_BU = 3'b100,
        MEM_HU = 3'b101,
        MEM_WU = 3'b110
    } mem_size_e;

endpackage