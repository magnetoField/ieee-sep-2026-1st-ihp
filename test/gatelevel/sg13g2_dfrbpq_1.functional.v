`timescale 1ns/1ps

// Zero-delay simulation replacement for the sole sequential cell selected by
// the IHP mapping. See scripts/test_gatelevel_ihp.sh for the Icarus limitation.
module sg13g2_dfrbpq_1 (
    output reg Q,
    input wire D,
    input wire RESET_B,
    input wire CLK
);
    always @(posedge CLK or negedge RESET_B) begin
        if (!RESET_B)
            Q <= 1'b0;
        else
            Q <= D;
    end
endmodule

