// ext_decoder.sv
module ext_decoder (
    input  logic [31:0] instr,
    output logic        is_muldiv,
    output logic        is_csr,
    output logic        is_mret,
    output logic        is_wfi,
    output logic        ext_reg_write,
    output logic        ext_hit
);

    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        is_muldiv = 1'b0;
        is_csr    = 1'b0;
        is_mret   = 1'b0;
        is_wfi    = 1'b0;

        case (opcode)
            7'b0110011:                                   // OP: MUL, MULH, DIV...
                if (funct7 == 7'b0000001) is_muldiv = 1'b1;

            7'b0111011:                                   // OP-32: MULW, DIVW...
                if (funct7 == 7'b0000001 &&
                    funct3 inside {3'b000, 3'b100, 3'b101, 3'b110, 3'b111})
                    is_muldiv = 1'b1;

            7'b1110011: begin                             // SYSTEM
                if (funct3 != 3'b000 && funct3 != 3'b100)
                    is_csr = 1'b1;
                else if (instr == 32'h3020_0073) is_mret = 1'b1;
                else if (instr == 32'h1050_0073) is_wfi  = 1'b1;
            end

            default: ;
        endcase

        ext_reg_write = is_muldiv | is_csr;
        ext_hit       = is_muldiv | is_csr | is_mret | is_wfi;
    end

endmodule