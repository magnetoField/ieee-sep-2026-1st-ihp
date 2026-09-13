`timescale 1ns/1ps
`default_nettype none

// Deterministic reachability harness: GOOD, terminal BAD, cmd, seal and a
// successful controller cleanup must all be reachable from reset.
module reachability(input wire clk, output wire cover_goal);
    reg [4:0] step;
    wire rst_n = (step != 0);
    wire key_pulse = (step == 5'd2);

    wire good_valid,good_locked;
    wire bad_valid,bad_locked;
    regs #(.PIN_LEN(1),.PIN_VALUE(32'h1),.MAX_FAILS(1)) good_regs(
        .clk(clk),.cold_rst_n(rst_n),.session_rst_n(rst_n),.entry_enable(1'b1),
        .key_valid(key_pulse),.key_ready(),.key_id(4'd0),.txn_valid(good_valid),
        .txn_ready(1'b0),
        .session_end(1'b0),.locked(good_locked),
        .beep_event(),.submit_event());
    regs #(.PIN_LEN(1),.PIN_VALUE(32'h0),.MAX_FAILS(1)) bad_regs(
        .clk(clk),.cold_rst_n(rst_n),.session_rst_n(rst_n),.entry_enable(1'b1),
        .key_valid(key_pulse),.key_ready(),.key_id(4'd0),.txn_valid(bad_valid),
        .txn_ready(1'b0),
        .session_end(1'b0),.locked(bad_locked),
        .beep_event(),.submit_event());

    wire offer = (step == 5'd2);
    wire txn_ready,session_end,cmd_valid,seal_valid,rx_arm,tx_arm,req,rsp_ready;
    reg cmd_seen,seal_seen,success_seen;
    auth_ctrl #(.AUTH_TIMEOUT_MS(20)) auth(
        .clk(clk),.rst_n(rst_n),.ms_tick(1'b0),
        .txn_valid(offer),.txn_ready(txn_ready),
        .session_end(session_end),
        .cmd_valid(cmd_valid),.cmd_ready(1'b1),
        .seal_valid(seal_valid),.seal_ready(1'b1),.cipher_m_valid(1'b1),
        .cipher_abort(),.rx_arm(rx_arm),.tx_arm(tx_arm),.link_cancel(),
        .rx_active(1'b1),.tx_active(1'b1),.rx_done(1'b1),.tx_done(1'b1),
        .protocol_error(1'b0),.frame_start(1'b0),.req(req),.rsp_ready(rsp_ready));

    always @(posedge clk) begin
        if (step != 5'h1f)
            step <= step + 1'b1;
        if (!rst_n) begin
            cmd_seen <= 1'b0;
            seal_seen <= 1'b0;
            success_seen <= 1'b0;
        end else begin
            if (cmd_valid) cmd_seen <= 1'b1;
            if (seal_valid) seal_seen <= 1'b1;
            if (session_end && cmd_seen && seal_seen) success_seen <= 1'b1;
        end
    end

    assign cover_goal = success_seen && good_valid && !bad_valid && bad_locked && !good_locked;
endmodule

`default_nettype wire
