// regfile.sv
module regfile (
    input  logic        clk,

    // porto de leitura A
    input  logic [4:0]  rs1,
    output logic [63:0] rs1_data,

    // porto de leitura B
    input  logic [4:0]  rs2,
    output logic [63:0] rs2_data,

    // porto de escrita
    input  logic        we,
    input  logic [4:0]  rd,
    input  logic [63:0] rd_data
);

    logic [63:0] regs [1:31];   // x0 não é armazenado

    // ---------------- escrita ----------------
    always_ff @(posedge clk) begin
        if (we && (rd != 5'd0))
            regs[rd] <= rd_data;
    end

    // ---------------- leitura (com bypass da escrita) ----------------
    always_comb begin
        if (rs1 == 5'd0)
            rs1_data = 64'h0;
        else if (we && (rs1 == rd))
            rs1_data = rd_data;
        else
            rs1_data = regs[rs1];
    end

    always_comb begin
        if (rs2 == 5'd0)
            rs2_data = 64'h0;
        else if (we && (rs2 == rd))
            rs2_data = rd_data;
        else
            rs2_data = regs[rs2];
    end

    // ---------------- inicialização (apenas simulação) ----------------
    initial begin
        for (int i = 1; i < 32; i++)
            regs[i] = 64'h0;
    end

endmodule