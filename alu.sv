// alu.sv
module alu
    import rv_pkg::*;
(
    input  alu_op_e     alu_op,
    input  logic        word_op,    // 1 = operação de 32 bits (*W)
    input  logic [63:0] a,
    input  logic [63:0] b,
    output logic [63:0] result
);

    // shamt: 6 bits em 64-bit, 5 bits nas variantes W
    logic [5:0] shamt64;
    logic [4:0] shamt32;
    assign shamt64 = b[5:0];
    assign shamt32 = b[4:0];

    // operandos de 32 bits para as variantes W
    logic        [31:0] a32u;
    logic signed [31:0] a32s;
    assign a32u = a[31:0];
    assign a32s = a[31:0];

    // operandos de 64 bits com sinal
    logic signed [63:0] a_s, b_s;
    assign a_s = a;
    assign b_s = b;

    // resultado de 64 bits antes da extensão de sinal em operações W
    logic [63:0] raw;

    always_comb begin
        raw = 64'h0;

        unique case (alu_op)
            ALU_ADD:    raw = a + b;
            ALU_SUB:    raw = a - b;

            ALU_SLL:    raw = word_op ? 64'(a32u << shamt32)
                                      : (a << shamt64);

            ALU_SRL:    raw = word_op ? 64'(a32u >> shamt32)
                                      : (a >> shamt64);

            ALU_SRA:    raw = word_op ? 64'(a32s >>> shamt32)
                                      : 64'(a_s >>> shamt64);

            ALU_SLT:    raw = {63'b0, (a_s < b_s)};
            ALU_SLTU:   raw = {63'b0, (a < b)};

            ALU_XOR:    raw = a ^ b;
            ALU_OR:     raw = a | b;
            ALU_AND:    raw = a & b;

            ALU_PASS_B: raw = b;

            default:    raw = 64'h0;
        endcase
    end

    // Operações *W: resultado = sinal-estendido de raw[31:0]
    assign result = word_op ? {{32{raw[31]}}, raw[31:0]} : raw;

endmodule