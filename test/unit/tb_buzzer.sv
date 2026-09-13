`timescale 1ns/1ps
module tb_buzzer;
    reg clk=0, rst_n=0, ms_tick=0, scan_tick=0, beep_event=0;
    wire active_out, active_busy, tone_out, tone_busy;
    buzzer #(.ACTIVE_BUZZER(1),.BEEP_TICKS_MS(3),.TONE_HALF_TICKS(2)) active(
        clk,rst_n,ms_tick,scan_tick,beep_event,active_out,active_busy);
    buzzer #(.ACTIVE_BUZZER(0),.BEEP_TICKS_MS(3),.TONE_HALF_TICKS(2)) tone(
        clk,rst_n,ms_tick,scan_tick,beep_event,tone_out,tone_busy);
    always #5 clk=~clk;
    task pulse_ms; begin @(negedge clk); ms_tick=1; @(posedge clk); @(negedge clk); ms_tick=0; end endtask
    task pulse_scan; begin @(negedge clk); scan_tick=1; @(posedge clk); @(negedge clk); scan_tick=0; end endtask
    initial begin
        repeat(2) @(posedge clk); rst_n=1;
        @(negedge clk); beep_event=1; ms_tick=1; @(posedge clk); @(negedge clk); beep_event=0; ms_tick=0;
        if (!active_busy || !active_out || !tone_busy || tone_out) $fatal(1,"trigger priority/start wrong");
        pulse_scan(); if (tone_out) $fatal(1,"tone toggled early");
        pulse_scan(); if (!tone_out) $fatal(1,"tone half period wrong");
        pulse_ms(); if (!active_busy) $fatal(1,"ended after first future tick");
        @(negedge clk); beep_event=1; @(posedge clk); @(negedge clk); beep_event=0;
        pulse_ms(); if (!active_busy) $fatal(1,"ended after second future tick");
        @(negedge clk); beep_event=1; ms_tick=1; @(posedge clk); @(negedge clk); beep_event=0; ms_tick=0;
        if (active_busy || active_out || tone_busy || tone_out) $fatal(1,"busy trigger extended/end wrong");
        beep_event=1; @(posedge clk); @(negedge clk); beep_event=0;
        if (!active_busy) $fatal(1,"did not rearm");
        rst_n=0; #1; if(active_out || tone_out || active_busy) $fatal(1,"reset unsafe");
        $display("PASS tb_buzzer active/passive timing and busy trigger policy"); $finish;
    end
endmodule
