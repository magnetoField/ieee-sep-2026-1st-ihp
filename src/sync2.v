`timescale 1ns/1ps
`default_nettype none

module sync2 #(
    parameter WIDTH = 1
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,
    output reg  [WIDTH-1:0] sync_out
);
    reg [WIDTH-1:0] stage1;

    generate
        if (WIDTH < 1) begin : g_invalid_width
            INVALID_SYNC2_WIDTH invalid_configuration();
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1   <= {WIDTH{1'b0}};
            sync_out <= {WIDTH{1'b0}};
        end else begin
            stage1   <= async_in;
            sync_out <= stage1;
        end
    end
endmodule

`default_nettype wire
