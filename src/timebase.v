`timescale 1ns/1ps
`default_nettype none

module timebase #(
    parameter CLK_HZ  = 1000000,
    parameter SCAN_HZ = 4000
) (
    input  wire clk,
    input  wire rst_n,
    output reg  scan_tick,
    output reg  ms_tick
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

    localparam integer SCAN_DIV = (SCAN_HZ > 0) ? (CLK_HZ / SCAN_HZ) : 0;
    localparam integer MS_DIV   = (SCAN_HZ > 0) ? (SCAN_HZ / 1000) : 0;
    localparam integer SCAN_W   = width_for(SCAN_DIV - 1);
    localparam integer MS_W     = width_for(MS_DIV - 1);
    // The counter widths are derived from these values; truncation is exact.
    /* verilator lint_off WIDTHTRUNC */
    localparam [SCAN_W-1:0] SCAN_LAST = SCAN_DIV - 1;
    localparam [MS_W-1:0] MS_LAST = MS_DIV - 1;
    /* verilator lint_on WIDTHTRUNC */

    reg [SCAN_W-1:0] scan_count;
    reg [MS_W-1:0] ms_count;

    generate
        if ((CLK_HZ < 1) || (SCAN_HZ < 1) || ((CLK_HZ % SCAN_HZ) != 0)
            || (SCAN_DIV < 16) || ((SCAN_HZ % 1000) != 0)) begin : g_invalid_timebase
            INVALID_TIMEBASE_CONFIGURATION invalid_configuration();
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_count <= {SCAN_W{1'b0}};
            ms_count   <= {MS_W{1'b0}};
            scan_tick  <= 1'b0;
            ms_tick    <= 1'b0;
        end else begin
            scan_tick <= 1'b0;
            ms_tick   <= 1'b0;
            if (scan_count == SCAN_LAST) begin
                scan_count <= {SCAN_W{1'b0}};
                scan_tick  <= 1'b1;
                if (ms_count == MS_LAST) begin
                    ms_count <= {MS_W{1'b0}};
                    ms_tick  <= 1'b1;
                end else begin
                    ms_count <= ms_count + 1'b1;
                end
            end else begin
                scan_count <= scan_count + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
