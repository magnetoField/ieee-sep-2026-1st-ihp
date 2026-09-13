`timescale 1ns/1ps
`default_nettype none

// Asynchronous assertion, two-rising-edge synchronous release.
module reset_release (
    input  wire clk,
    input  wire async_n,
    output wire released_n
);
    reg [1:0] release_pipe;

    always @(posedge clk or negedge async_n) begin
        if (!async_n)
            release_pipe <= 2'b00;
        else
            release_pipe <= {release_pipe[0], 1'b1};
    end

    assign released_n = release_pipe[1];
endmodule

`default_nettype wire
