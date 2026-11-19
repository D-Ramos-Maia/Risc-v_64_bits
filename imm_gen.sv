// imm_gen.sv
module imm_gen
    import rv_pkg::*;
(
    input  logic [31:0] instr,
    output logic [63:0] imm
);

    always_comb begin
        unique case (opcode_e'(instr[6:0]))
            // I-type
            OP_IMM, OP_IMM32, OP_LOAD, OP_JALR:
                imm = {{52{instr[31]}}, instr[31:20]};

            // S-type
            OP_STORE:
                imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type
            OP_BRANCH:
                imm = {{51{instr[31]}}, instr[31], instr[7],
                       instr[30:25], instr[11:8], 1'b0};

            // U-type (já sinal-estendido de 32 para 64 bits)
            OP_LUI, OP_AUIPC:
                imm = {{32{instr[31]}}, instr[31:12], 12'b0};

            // J-type
            OP_JAL:
                imm = {{43{instr[31]}}, instr[31], instr[19:12],
                       instr[20], instr[30:21], 1'b0};

            default:
                imm = 64'h0;
        endcase
    end

endmodule