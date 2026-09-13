`timescale 1ns/1ps
module tb_sync2;
    reg clk = 0, rst_n = 1;
    reg [3:0] async4 = 0;
    wire [3:0] sync4;
    reg async1 = 0;
    wire sync1;
    sync2 #(.WIDTH(4)) d4(clk, rst_n, async4, sync4);
    sync2 #(.WIDTH(1)) d1(clk, rst_n, async1, sync1);
    always #5 clk = ~clk;
    initial begin
        #1; rst_n = 0; #1;
        if (sync4 !== 0 || sync1 !== 0) $fatal(1, "async reset failed");
        rst_n = 1; #7; async4 = 4'ha; async1 = 1;
        @(posedge clk); #1;
        if (sync4 !== 0 || sync1 !== 0) $fatal(1, "first stage leaked");
        @(posedge clk); #1;
        if (sync4 !== 4'ha || sync1 !== 1) $fatal(1, "second stage wrong");
        rst_n = 0; #1;
        if (sync4 !== 0 || sync1 !== 0) $fatal(1, "async assertion failed");
        $display("PASS tb_sync2 WIDTH=1,4"); $finish;
    end
endmodule
