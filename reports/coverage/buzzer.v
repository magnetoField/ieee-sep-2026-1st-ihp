//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module buzzer #(
            parameter BEEP_TICKS_MS = 50,
            parameter TONE_HALF_TICKS = 1
        ) (
 1227568     input  wire clk,
 000005     input  wire rst_n,
 001926     input  wire ms_tick,
 007708     input  wire scan_tick,
 000060     input  wire beep_event,
 001528     output wire buzzer_out,
 000060     output reg  busy
        );
%000000     function integer width_for;
                input integer maximum;
                integer value;
%000000         begin
%000000             value = maximum;
%000000             width_for = 0;
%000000             while (value > 0) begin
%000000                 width_for = width_for + 1;
%000000                 value = value >> 1;
                    end
%000000             if (width_for < 1)
%000000                 width_for = 1;
                end
            endfunction
        
            localparam integer BEEP_W = width_for(BEEP_TICKS_MS - 1);
            localparam integer TONE_W = width_for(TONE_HALF_TICKS - 1);
            localparam [BEEP_W-1:0] BEEP_LAST = BEEP_TICKS_MS - 1;
            localparam [TONE_W-1:0] TONE_LAST = TONE_HALF_TICKS - 1;
~000386     reg [BEEP_W-1:0] beep_count;
~000004     reg [TONE_W-1:0] tone_count;
 001528     reg tone_phase;
        
            generate
                if ((BEEP_TICKS_MS < 1) || (TONE_HALF_TICKS < 1)) begin : g_invalid_buzzer
                    INVALID_BUZZER_CONFIGURATION invalid_configuration();
                end
            endgenerate
        
            // Fixed Tiny Tapeout interface: generate the tone for a passive buzzer.
            assign buzzer_out = busy && tone_phase;
        
 613785     always @(posedge clk or negedge rst_n) begin
 000015         if (!rst_n) begin
 000015             busy       <= 1'b0;
 000015             beep_count <= {BEEP_W{1'b0}};
 000015             tone_count <= {TONE_W{1'b0}};
 000015             tone_phase <= 1'b0;
 382769         end else if (!busy) begin
 231009             beep_count <= {BEEP_W{1'b0}};
 231009             tone_count <= {TONE_W{1'b0}};
 231009             tone_phase <= 1'b0;
~231001             if (beep_event)
 000030                 busy <= 1'b1;
 382769         end else begin
                    // A trigger while busy is intentionally ignored, including the end tick.
 382384             if (ms_tick) begin
~000378                 if (beep_count == BEEP_LAST) begin
~000030                     busy       <= 1'b0;
~000030                     beep_count <= {BEEP_W{1'b0}};
~000030                     tone_count <= {TONE_W{1'b0}};
~000030                     tone_phase <= 1'b0;
~000378                 end else begin
~000378                     beep_count <= beep_count + 1'b1;
                        end
                    end
 381245             if (scan_tick && !(ms_tick && (beep_count == BEEP_LAST))) begin
~001524                 if (tone_count == TONE_LAST) begin
 001524                     tone_count <= {TONE_W{1'b0}};
 001524                     tone_phase <= ~tone_phase;
~000002                 end else begin
~000002                     tone_count <= tone_count + 1'b1;
                        end
                    end
                end
            end
        endmodule
        
        `default_nettype wire
        
