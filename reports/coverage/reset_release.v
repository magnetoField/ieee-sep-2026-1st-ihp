//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        // Asynchronous assertion, two-rising-edge synchronous release.
        module reset_release (
 2455136     input  wire clk,
 000008     input  wire async_n,
 000008     output wire released_n
        );
 000008     reg [1:0] release_pipe;
        
 1227568     always @(posedge clk or negedge async_n) begin
 1227559         if (!async_n)
 000017             release_pipe <= 2'b00;
                else
 1227559             release_pipe <= {release_pipe[0], 1'b1};
            end
        
            assign released_n = release_pipe[1];
        endmodule
        
        `default_nettype wire
        
