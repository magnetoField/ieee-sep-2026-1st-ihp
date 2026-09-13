//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_buzzer_params;
 000022     reg clk=0,rst_n=0,ms_tick=0,scan_tick=0,beep_event=0;
 000004     wire beep1_out,beep1_busy,tone1_out,tone1_busy,tone2_out,tone2_busy,tone3_out,tone3_busy;
            buzzer #(.ACTIVE_BUZZER(1),.BEEP_TICKS_MS(1),.TONE_HALF_TICKS(1)) beep1(
                clk,rst_n,ms_tick,scan_tick,beep_event,beep1_out,beep1_busy);
            buzzer #(.ACTIVE_BUZZER(0),.BEEP_TICKS_MS(5),.TONE_HALF_TICKS(1)) tone1(
                clk,rst_n,ms_tick,scan_tick,beep_event,tone1_out,tone1_busy);
            buzzer #(.ACTIVE_BUZZER(0),.BEEP_TICKS_MS(5),.TONE_HALF_TICKS(2)) tone2(
                clk,rst_n,ms_tick,scan_tick,beep_event,tone2_out,tone2_busy);
            buzzer #(.ACTIVE_BUZZER(0),.BEEP_TICKS_MS(5),.TONE_HALF_TICKS(3)) tone3(
                clk,rst_n,ms_tick,scan_tick,beep_event,tone3_out,tone3_busy);
 000022     always #5 clk=~clk;
 000003     task pulse_scan;begin @(negedge clk);scan_tick=1;@(posedge clk);@(negedge clk);scan_tick=0;end endtask
 000001     task pulse_ms;begin @(negedge clk);ms_tick=1;@(posedge clk);@(negedge clk);ms_tick=0;end endtask
 000001     initial begin
 000002         repeat(2)@(posedge clk);@(negedge clk);rst_n=1;
 000001         beep_event=1;@(posedge clk);@(negedge clk);beep_event=0;
 000001         if(!beep1_busy||!beep1_out||!tone1_busy||!tone2_busy||!tone3_busy)
                    $fatal(1,"edge configurations did not start");
 000001         pulse_scan();
 000001         if(tone1_out!==1||tone2_out!==0||tone3_out!==0)$fatal(1,"half tick 1 mismatch");
 000001         pulse_scan();
 000001         if(tone1_out!==0||tone2_out!==1||tone3_out!==0)$fatal(1,"half tick 2 mismatch");
 000001         pulse_scan();
 000001         if(tone1_out!==1||tone2_out!==1||tone3_out!==1)$fatal(1,"half tick 3 mismatch");
 000001         pulse_ms();
 000001         if(beep1_busy||beep1_out)$fatal(1,"BEEP_TICKS_MS=1 did not end on first future tick");
 000001         if(!tone1_busy||!tone2_busy||!tone3_busy)$fatal(1,"long beeps ended early");
 000001         rst_n=0;#1;
 000001         if(beep1_out||tone1_out||tone2_out||tone3_out||beep1_busy||tone1_busy)
                    $fatal(1,"parameterized buzzer reset unsafe");
 000001         $display("PASS tb_buzzer_params BEEP=1 and passive HALF_TICKS=1,2,3");$finish;
            end
        endmodule
        
