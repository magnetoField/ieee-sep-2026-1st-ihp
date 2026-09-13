//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module sync2 #(
            parameter WIDTH = 1
        ) (
 1227568     input  wire             clk,
 000005     input  wire             rst_n,
 001511     input  wire [WIDTH-1:0] async_in,
 001511     output reg  [WIDTH-1:0] sync_out
        );
 001511     reg [WIDTH-1:0] stage1;
        
            generate
                if (WIDTH < 1) begin : g_invalid_width
                    INVALID_SYNC2_WIDTH invalid_configuration();
                end
            endgenerate
        
 613785     always @(posedge clk or negedge rst_n) begin
 613778         if (!rst_n) begin
 000015             stage1   <= {WIDTH{1'b0}};
 000015             sync_out <= {WIDTH{1'b0}};
 613778         end else begin
 613778             stage1   <= async_in;
 613778             sync_out <= stage1;
                end
            end
        endmodule
        
        `default_nettype wire
        
