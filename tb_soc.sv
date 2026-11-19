// tb_soc.sv
module tb_soc;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    soc dut (.clk, .rst_n);

    initial begin
        // $dumpfile("soc.vcd"); $dumpvars(0, tb_soc);
        #27 rst_n = 1;
        repeat (5_000_000) @(posedge clk);
        $display("TIMEOUT");
        $finish;
    end
endmodule