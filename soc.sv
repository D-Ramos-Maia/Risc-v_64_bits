// soc.sv
module soc
    import rv_pkg::*;
#(
    parameter int          MEM_BYTES   = 65536,
    parameter logic [63:0] RAM_BASE    = 64'h0000_0000_8000_0000,
    parameter string       IMEM_INIT   = "prog32.hex",
    parameter string       DMEM_INIT   = "prog64.hex",
    parameter logic [63:0] TOHOST_ADDR = 64'h0000_0000_8000_1000   // riscv-tests
) (
    input logic clk,
    input logic rst_n
);

    logic [63:0] imem_addr, dmem_addr, dmem_wdata, dmem_rdata;
    logic [63:0] ram_rdata, clint_rdata;
    logic [31:0] imem_instr;
    logic        imem_fault, dmem_we;
    mem_size_e   dmem_size;
    logic        ram_misaligned, ram_access_fault;
    logic        irq_timer, irq_sw;

    // ---------------- decodificação de endereços ----------------
    logic is_clint, is_host, is_mmio;
    assign is_clint = (dmem_addr[63:16] == 48'h0200);     // 0x0200_0000
    assign is_host  = (dmem_addr[63:12] == 52'h10000);    // 0x1000_0000 (só simulação)
    assign is_mmio  = is_clint | is_host;

    // ---------------- core ----------------
    core #(.RESET_VECTOR(RAM_BASE)) u_core (
        .clk, .rst_n,
        .imem_addr, .imem_instr, .imem_fault,
        .dmem_addr, .dmem_we, .dmem_size, .dmem_wdata, .dmem_rdata,
        .dmem_misaligned   (is_mmio ? 1'b0 : ram_misaligned),
        .dmem_access_fault (is_mmio ? 1'b0 : ram_access_fault),
        .irq_timer, .irq_ext(1'b0), .irq_sw
    );

    // ---------------- memórias ----------------
    imem #(
        .DEPTH_WORDS(MEM_BYTES/4), .INIT_FILE(IMEM_INIT), .BASE_ADDR(RAM_BASE)
    ) u_imem (
        .addr(imem_addr), .instr(imem_instr), .addr_fault(imem_fault)
    );

    dmem #(
        .DEPTH_DWORDS(MEM_BYTES/8), .INIT_FILE(DMEM_INIT), .BASE_ADDR(RAM_BASE)
    ) u_dmem (
        .clk, .addr(dmem_addr), .we(dmem_we & ~is_mmio), .size(dmem_size),
        .wdata(dmem_wdata), .rdata(ram_rdata),
        .misaligned(ram_misaligned), .access_fault(ram_access_fault)
    );

    clint u_clint (
        .clk, .rst_n, .addr(dmem_addr), .we(dmem_we & is_clint),
        .wdata(dmem_wdata), .rdata(clint_rdata),
        .irq_timer, .irq_sw
    );

    assign dmem_rdata = is_clint ? clint_rdata :
                        is_host  ? 64'h0       : ram_rdata;

    // ---------------- apenas simulação ----------------
`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (rst_n && dmem_we) begin
            if (is_host) begin
                case (dmem_addr[3:0])
                    4'h0: $write("%c", dmem_wdata[7:0]);                // putchar
                    4'h8: begin                                         // exit(code)
                        $display("\n[exit] code = %0d", dmem_wdata[31:0]);
                        $finish;
                    end
                    default: ;
                endcase
            end else if (dmem_addr == TOHOST_ADDR) begin                // riscv-tests
                if (dmem_wdata[31:0] == 32'd1) $display("PASS");
                else                           $display("FAIL (teste %0d)", dmem_wdata[31:1]);
                $finish;
            end
        end
    end
`endif

endmodule