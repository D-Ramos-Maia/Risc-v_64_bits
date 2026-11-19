// imem.sv
module imem #(
    parameter int    DEPTH_WORDS = 1024,                 // 1024 x 4 B = 4 KiB
    parameter string INIT_FILE   = "program.hex",
    parameter logic [63:0] BASE_ADDR = 64'h0000_0000_0000_0000
) (
    input  logic [63:0] addr,         // normalmente o PC
    output logic [31:0] instr,
    output logic        addr_fault    // 1 = endereço desalinhado ou fora da faixa
);

    localparam int AW = $clog2(DEPTH_WORDS);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    // NOP (addi x0, x0, 0) como padrão, evita X na simulação
    initial begin
        for (int i = 0; i < DEPTH_WORDS; i++)
            mem[i] = 32'h0000_0013;
        $readmemh(INIT_FILE, mem);
    end

    logic [63:0] offset;
    logic        misaligned, out_of_range;

    assign offset       = addr - BASE_ADDR;
    assign misaligned   = |addr[1:0];
    assign out_of_range = (addr < BASE_ADDR) ||
                          (offset[63:2] >= 64'(DEPTH_WORDS));

    assign addr_fault = misaligned | out_of_range;

    // leitura combinacional por palavra
    assign instr = addr_fault ? 32'h0000_0013
                              : mem[offset[AW+1:2]];

endmodule