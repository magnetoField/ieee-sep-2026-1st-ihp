//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        /* verilator lint_off DECLFILENAME */
        module tt_um_rumcajs (
 613781     input  wire [7:0] ui_in,
~000062     output wire [7:0] uo_out,
 613781     input  wire [7:0] uio_in,
%000000     output wire [7:0] uio_out,
~001230     output wire [7:0] uio_oe,
 000002     input  wire       ena,
 1227568     input  wire       clk,
 000001     input  wire       rst_n
        );
 001230     wire [3:0] row_oe;
 000002     wire req;
 000002     wire rsp_ready;
 000062     wire serial_sdo;
 000016     wire buzzer_out;
%000000     wire unused = &{1'b0, ui_in[7], uio_in, rsp_ready};
        
            rumcajs u_rumcajs (
                .clk(clk), .rst_n(rst_n), .ena(ena),
                .kb_col_n(ui_in[3:0]), .kb_row_oe(row_oe),
                .serial_sdi(ui_in[4]), .serial_sclk(ui_in[5]),
                .serial_cs_n(ui_in[6]), .serial_sdo(serial_sdo),
                .req(req), .rsp_ready(rsp_ready), .buzzer_out(buzzer_out)
            );
        
            // One external status pin: READY for a fresh challenge after a valid PIN.
            assign uo_out = {4'b0000, buzzer_out, serial_sdo, 1'b0, req};
            assign uio_out = 8'b00000000;
            assign uio_oe = {4'b0000, row_oe};
        `ifdef FORMAL
            always @* begin
                assert(uio_out == 8'b0);                                     // F-08
                assert(uio_oe[7:4] == 4'b0);
                assert(uo_out[7:4] == 4'b0);
            end
        `endif
        endmodule
        /* verilator lint_on DECLFILENAME */
        
        `default_nettype wire
        
