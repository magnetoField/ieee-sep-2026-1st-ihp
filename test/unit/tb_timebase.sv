`timescale 1ns/1ps
module tb_timebase;
    reg clk = 0, rst_n = 0;
    wire scan_tick, ms_tick;
    integer cycles = 0, scans = 0, millis = 0, last_scan = 0;
    timebase #(.CLK_HZ(64000), .SCAN_HZ(4000)) dut(clk, rst_n, scan_tick, ms_tick);
    always #5 clk = ~clk;
    always @(posedge clk) if (rst_n) begin
        cycles = cycles + 1;
        #1;
        if (scan_tick) begin
            if ((cycles - last_scan) != 16) $fatal(1, "scan period wrong");
            last_scan = cycles; scans = scans + 1;
        end
        if (ms_tick) begin
            if (!scan_tick) $fatal(1, "ms tick without scan tick");
            millis = millis + 1;
        end
    end
    initial begin
        repeat (2) @(posedge clk); @(negedge clk); rst_n = 1;
        repeat (64) @(posedge clk); #2;
        if (scans != 4 || millis != 1) $fatal(1, "tick totals wrong");
        rst_n = 0; #1;
        if (scan_tick || ms_tick) $fatal(1, "ticks high during reset");
        @(negedge clk); rst_n = 1; cycles = 0; scans = 0; millis = 0; last_scan = 0;
        repeat (16) @(posedge clk); #2;
        if (scans != 1) $fatal(1, "phase after reset wrong");
        $display("PASS tb_timebase DIV=16, ms ratio=4, reset phase"); $finish;
    end
endmodule
