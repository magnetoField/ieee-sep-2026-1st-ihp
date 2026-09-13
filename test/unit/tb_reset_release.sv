`timescale 1ns/1ps
module tb_reset_release;
    reg clk = 0, async_n = 1, run_clk = 0;
    wire released_n;
    reset_release dut(clk, async_n, released_n);
    always begin #5; if (run_clk) clk = ~clk; end
    initial begin
        #1; async_n = 0; #2; if (released_n !== 0) $fatal(1, "assert state wrong");
        async_n = 1; #20;
        if (released_n !== 0) $fatal(1, "released without clock");
        run_clk = 1;
        @(posedge clk); #1; if (released_n !== 0) $fatal(1, "released after one edge");
        @(posedge clk); #1; if (released_n !== 1) $fatal(1, "not released after two edges");
        run_clk = 0; #2; async_n = 0; #1;
        if (released_n !== 0) $fatal(1, "async reassert with stopped clock failed");
        $display("PASS tb_reset_release stopped-clock assertion and 2-edge release"); $finish;
    end
endmodule
