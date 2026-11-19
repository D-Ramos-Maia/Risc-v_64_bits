// muldiv.sv
module muldiv (
    input  logic [2:0]  funct3,
    input  logic        word_op,     // *W
    input  logic [63:0] a,
    input  logic [63:0] b,
    output logic [63:0] result
);

    logic signed [63:0] a_s, b_s;
    logic signed [31:0] a32s, b32s;
    logic        [31:0] a32u, b32u;

    assign a_s = a;        assign b_s = b;
    assign a32s = a[31:0]; assign b32s = b[31:0];
    assign a32u = a[31:0]; assign b32u = b[31:0];

    // produtos de 128 bits
    logic signed [127:0] a_x, b_x, bu_x, p_ss, p_su;
    logic        [127:0] p_uu;

    assign a_x  = {{64{a[63]}}, a};
    assign b_x  = {{64{b[63]}}, b};
    assign bu_x = {64'b0, b};
    assign p_ss = a_x * b_x;                  // MUL / MULH
    assign p_su = a_x * bu_x;                 // MULHSU
    assign p_uu = {64'b0, a} * {64'b0, b};    // MULHU

    logic [31:0] r32;
    logic [63:0] r64;

    always_comb begin
        r32 = 32'h0;
        r64 = 64'h0;

        if (word_op) begin
            case (funct3)
                3'b000: r32 = p_ss[31:0];                              // MULW
                3'b100: begin                                          // DIVW
                    if (b32u == 32'h0)
                        r32 = 32'hFFFF_FFFF;
                    else if (a32u == 32'h8000_0000 && b32u == 32'hFFFF_FFFF)
                        r32 = 32'h8000_0000;
                    else
                        r32 = a32s / b32s;
                end
                3'b101: r32 = (b32u == 32'h0) ? 32'hFFFF_FFFF : (a32u / b32u);   // DIVUW
                3'b110: begin                                          // REMW
                    if (b32u == 32'h0)
                        r32 = a32u;
                    else if (a32u == 32'h8000_0000 && b32u == 32'hFFFF_FFFF)
                        r32 = 32'h0;
                    else
                        r32 = a32s % b32s;
                end
                3'b111: r32 = (b32u == 32'h0) ? a32u : (a32u % b32u);            // REMUW
                default: r32 = 32'h0;
            endcase
        end else begin
            case (funct3)
                3'b000: r64 = p_ss[63:0];                              // MUL
                3'b001: r64 = p_ss[127:64];                            // MULH
                3'b010: r64 = p_su[127:64];                            // MULHSU
                3'b011: r64 = p_uu[127:64];                            // MULHU
                3'b100: begin                                          // DIV
                    if (b == 64'h0)
                        r64 = 64'hFFFF_FFFF_FFFF_FFFF;
                    else if (a == 64'h8000_0000_0000_0000 && b == 64'hFFFF_FFFF_FFFF_FFFF)
                        r64 = 64'h8000_0000_0000_0000;
                    else
                        r64 = a_s / b_s;
                end
                3'b101: r64 = (b == 64'h0) ? 64'hFFFF_FFFF_FFFF_FFFF : (a / b);   // DIVU
                3'b110: begin                                          // REM
                    if (b == 64'h0)
                        r64 = a;
                    else if (a == 64'h8000_0000_0000_0000 && b == 64'hFFFF_FFFF_FFFF_FFFF)
                        r64 = 64'h0;
                    else
                        r64 = a_s % b_s;
                end
                3'b111: r64 = (b == 64'h0) ? a : (a % b);                         // REMU
                default: r64 = 64'h0;
            endcase
        end
    end

    assign result = word_op ? {{32{r32[31]}}, r32} : r64;

endmodule