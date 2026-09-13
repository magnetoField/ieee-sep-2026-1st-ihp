`timescale 1ns/1ps
`default_nettype none

// Bounded liveness harness for F-13. Time is scaled to one ms_tick per cycle
// and AUTH_TIMEOUT_MS=3 while preserving the controller's counter semantics.
module auth_liveness;
    (* anyseq *) reg clk;
    reg [3:0] step;
    reg accepted;
    reg ended;
    wire rst_n = (step != 0);
    wire offer = (step == 4'd2);
    wire txn_ready;
    wire session_end,cmd_valid,seal_valid,cipher_abort,rx_arm,tx_arm,link_cancel;
    wire req,rsp_ready;

    (* anyseq *) reg cmd_ready;
    (* anyseq *) reg seal_ready;
    (* anyseq *) reg cipher_m_valid;
    (* anyseq *) reg rx_active;
    (* anyseq *) reg tx_active;
    (* anyseq *) reg rx_done;
    (* anyseq *) reg tx_done;
    (* anyseq *) reg protocol_error;
    (* anyseq *) reg frame_start;

    auth_ctrl #(.AUTH_TIMEOUT_MS(3)) dut(
        .clk(clk),.rst_n(rst_n),.ms_tick(rst_n),
        .txn_valid(offer),.txn_ready(txn_ready),
        .session_end(session_end),
        .cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .seal_valid(seal_valid),.seal_ready(seal_ready),
        .cipher_m_valid(cipher_m_valid),.cipher_abort(cipher_abort),
        .rx_arm(rx_arm),.tx_arm(tx_arm),.link_cancel(link_cancel),
        .rx_active(rx_active),.tx_active(tx_active),.rx_done(rx_done),
        .tx_done(tx_done),.protocol_error(protocol_error),.frame_start(frame_start),
        .req(req),.rsp_ready(rsp_ready));

    always @(posedge clk) begin
        if (step != 4'hf)
            step <= step + 1'b1;
        if (!rst_n) begin
            accepted <= 1'b0;
            ended <= 1'b0;
        end else begin
            if (offer && txn_ready)
                accepted <= 1'b1;
            if (session_end)
                ended <= 1'b1;
        end
    end

    always @* begin
        if (step >= 4'd4)
            assert(accepted);
        if (step >= 4'd8)
            assert(ended || session_end);
    end
endmodule

`default_nettype wire
