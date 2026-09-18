`timescale 1ns/1ps
`default_nettype none

module buzzer #(
    parameter BEEP_TICKS_MS = 50,
    parameter TONE_HALF_TICKS = 1
) (
    input  wire clk,
    input  wire rst_n,
    input  wire ms_tick,
    input  wire scan_tick,
    input  wire beep_event,
    output wire buzzer_out,
    output reg  busy
);
    function integer width_for;
        input integer maximum;
        integer value;
        begin
            value = maximum;
            width_for = 0;
            while (value > 0) begin
                width_for = width_for + 1;
                value = value >> 1;
            end
            if (width_for < 1)
                width_for = 1;
        end
    endfunction

    localparam integer BEEP_W = width_for(BEEP_TICKS_MS - 1);
    localparam integer TONE_W = width_for(TONE_HALF_TICKS - 1);
    localparam [BEEP_W-1:0] BEEP_LAST = BEEP_TICKS_MS - 1;
    localparam [TONE_W-1:0] TONE_LAST = TONE_HALF_TICKS - 1;
    reg [BEEP_W-1:0] beep_count;
    reg [TONE_W-1:0] tone_count;
    reg tone_phase;

    generate
        if ((BEEP_TICKS_MS < 1) || (TONE_HALF_TICKS < 1)) begin : g_invalid_buzzer
            INVALID_BUZZER_CONFIGURATION invalid_configuration();
        end
    endgenerate

    // Fixed Tiny Tapeout interface: generate the tone for a passive buzzer.
    assign buzzer_out = busy && tone_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            beep_count <= {BEEP_W{1'b0}};
            tone_count <= {TONE_W{1'b0}};
            tone_phase <= 1'b0;
        end else if (!busy) begin
            beep_count <= {BEEP_W{1'b0}};
            tone_count <= {TONE_W{1'b0}};
            tone_phase <= 1'b0;
            if (beep_event)
                busy <= 1'b1;
        end else begin
            // A trigger while busy is intentionally ignored, including the end tick.
            if (ms_tick) begin
                if (beep_count == BEEP_LAST) begin
                    busy       <= 1'b0;
                    beep_count <= {BEEP_W{1'b0}};
                    tone_count <= {TONE_W{1'b0}};
                    tone_phase <= 1'b0;
                end else begin
                    beep_count <= beep_count + 1'b1;
                end
            end
            if (scan_tick && !(ms_tick && (beep_count == BEEP_LAST))) begin
                if (tone_count == TONE_LAST) begin
                    tone_count <= {TONE_W{1'b0}};
                    tone_phase <= ~tone_phase;
                end else begin
                    tone_count <= tone_count + 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
