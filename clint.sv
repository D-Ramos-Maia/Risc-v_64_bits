// clint.sv: mtime/mtimecmp/msip, no mapa padrão do SiFive (base 0x0200_0000)
module clint (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] addr,
    input  logic        we,
    input  logic [63:0] wdata,
    output logic [63:0] rdata,
    output logic        irq_timer,
    output logic        irq_sw
);

    logic [63:0] mtime, mtimecmp;
    logic        msip;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime    <= 64'h0;
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
            msip     <= 1'b0;
        end else begin
            mtime <= mtime + 64'd1;
            if (we) begin
                case (addr[15:0])
                    16'h0000: msip     <= wdata[0];
                    16'h4000: mtimecmp <= wdata;
                    16'hBFF8: mtime    <= wdata;
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        case (addr[15:0])
            16'h0000: rdata = {63'b0, msip};
            16'h4000: rdata = mtimecmp;
            16'hBFF8: rdata = mtime;
            default:  rdata = 64'h0;
        endcase
    end

    assign irq_timer = (mtime >= mtimecmp);
    assign irq_sw    = msip;

endmodule