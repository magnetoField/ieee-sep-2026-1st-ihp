//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module timebase #(
            parameter CLK_HZ  = 1000000,
            parameter SCAN_HZ = 4000
        ) (
 1227568     input  wire clk,
 000005     input  wire rst_n,
 007708     output reg  scan_tick,
 001926     output reg  ms_tick
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
        
            localparam integer SCAN_DIV = (SCAN_HZ > 0) ? (CLK_HZ / SCAN_HZ) : 0;
            localparam integer MS_DIV   = (SCAN_HZ > 0) ? (SCAN_HZ / 1000) : 0;
            localparam integer SCAN_W   = width_for(SCAN_DIV - 1);
            localparam integer MS_W     = width_for(MS_DIV - 1);
            // The counter widths are derived from these values; truncation is exact.
            /* verilator lint_off WIDTHTRUNC */
            localparam [SCAN_W-1:0] SCAN_LAST = SCAN_DIV - 1;
            localparam [MS_W-1:0] MS_LAST = MS_DIV - 1;
            /* verilator lint_on WIDTHTRUNC */
        
 613778     reg [SCAN_W-1:0] scan_count;
~003854     reg [MS_W-1:0] ms_count;
        
            generate
                if ((CLK_HZ < 1) || (SCAN_HZ < 1) || ((CLK_HZ % SCAN_HZ) != 0)
                    || (SCAN_DIV < 16) || ((SCAN_HZ % 1000) != 0)) begin : g_invalid_timebase
                    INVALID_TIMEBASE_CONFIGURATION invalid_configuration();
                end
            endgenerate
        
 613785     always @(posedge clk or negedge rst_n) begin
 613778         if (!rst_n) begin
 000015             scan_count <= {SCAN_W{1'b0}};
 000015             ms_count   <= {MS_W{1'b0}};
 000015             scan_tick  <= 1'b0;
 000015             ms_tick    <= 1'b0;
 613778         end else begin
 613778             scan_tick <= 1'b0;
 613778             ms_tick   <= 1'b0;
 611323             if (scan_count == SCAN_LAST) begin
 003854                 scan_count <= {SCAN_W{1'b0}};
 003854                 scan_tick  <= 1'b1;
~002891                 if (ms_count == MS_LAST) begin
 000963                     ms_count <= {MS_W{1'b0}};
 000963                     ms_tick  <= 1'b1;
~002891                 end else begin
~002891                     ms_count <= ms_count + 1'b1;
                        end
 611323             end else begin
 611323                 scan_count <= scan_count + 1'b1;
                    end
                end
            end
        endmodule
        
        `default_nettype wire
        
