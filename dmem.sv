// dmem.sv
module dmem
    import rv_pkg::*;
#(
    parameter int          DEPTH_DWORDS = 8192,              // 64 KiB
    parameter string       INIT_FILE    = "prog64.hex",      // 1 dword (64 bits) por linha
    parameter logic [63:0] BASE_ADDR    = 64'h0000_0000_8000_0000
) (
    input  logic        clk,
    input  logic [63:0] addr,
    input  logic        we,
    input  mem_size_e   size,
    input  logic [63:0] wdata,
    output logic [63:0] rdata,
    output logic        misaligned,
    output logic        access_fault
);

    localparam int AW = $clog2(DEPTH_DWORDS);

    logic [63:0] mem [0:DEPTH_DWORDS-1];

    initial begin
        for (int i = 0; i < DEPTH_DWORDS; i++) mem[i] = 64'h0;
        $readmemh(INIT_FILE, mem);
    end

    // ---------------- endereço / faults ----------------
    logic [63:0]   offset;
    logic [AW-1:0] idx;
    logic [2:0]    boff;
    logic          bad;

    assign offset = addr - BASE_ADDR;
    assign boff   = addr[2:0];

    assign access_fault = (addr < BASE_ADDR) ||
                          (offset >= (64'(DEPTH_DWORDS) << 3));

    always_comb begin
        case (size)
            MEM_H, MEM_HU: misaligned = addr[0];
            MEM_W, MEM_WU: misaligned = |addr[1:0];
            MEM_D:         misaligned = |addr[2:0];
            default:       misaligned = 1'b0;      // byte
        endcase
    end

    assign bad = misaligned | access_fault;
    assign idx = bad ? '0 : offset[AW+2:3];

    // ---------------- escrita com byte enables ----------------
    logic [7:0]  be;
    logic [63:0] wdata_sh;

    always_comb begin
        case (size)
            MEM_B:   be = 8'h01 << boff;
            MEM_H:   be = 8'h03 << boff;
            MEM_W:   be = 8'h0F << boff;
            MEM_D:   be = 8'hFF;
            default: be = 8'h00;
        endcase
    end

    assign wdata_sh = wdata << (boff * 8);

    always_ff @(posedge clk) begin
        if (we && !bad) begin
            for (int i = 0; i < 8; i++)
                if (be[i]) mem[idx][8*i +: 8] <= wdata_sh[8*i +: 8];
        end
    end

    // ---------------- leitura combinacional + extensão ----------------
    logic [63:0] raw;
    assign raw = mem[idx] >> (boff * 8);

    always_comb begin
        case (size)
            MEM_B:   rdata = {{56{raw[7]}},  raw[7:0]};
            MEM_BU:  rdata = {56'b0,         raw[7:0]};
            MEM_H:   rdata = {{48{raw[15]}}, raw[15:0]};
            MEM_HU:  rdata = {48'b0,         raw[15:0]};
            MEM_W:   rdata = {{32{raw[31]}}, raw[31:0]};
            MEM_WU:  rdata = {32'b0,         raw[31:0]};
            MEM_D:   rdata = raw;
            default: rdata = 64'h0;
        endcase
    end

endmodule