// pc.sv
module pc #(
    parameter logic [63:0] RESET_VECTOR = 64'h0000_0000_0000_0000
) (
    input  logic        clk,
    input  logic        rst_n,    // reset assíncrono, ativo em baixo
    input  logic        pc_en,    // 0 = congela o PC (stall)
    input  logic [63:0] pc_next,  // próximo valor do PC
    output logic [63:0] pc_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_o <= RESET_VECTOR;
        else if (pc_en)
            pc_o <= pc_next;
    end

endmodule