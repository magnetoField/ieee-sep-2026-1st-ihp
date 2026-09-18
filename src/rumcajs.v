`timescale 1ns/1ps
`default_nettype none

module rumcajs #(
    parameter CLK_HZ = 1000000,
    parameter SCAN_HZ = 4000,
    parameter PRESS_FRAMES = 20,
    parameter RELEASE_FRAMES = 20,
    parameter PIN_LEN = 4,
    parameter [31:0] PIN_VALUE = 32'h00001234,
    parameter MAX_FAILS = 3,
    parameter AUTH_TIMEOUT_MS = 5000,
    parameter BEEP_TICKS_MS = 50,
    parameter TONE_HALF_TICKS = 1,
    parameter FIXED_KEY_CORE = 1,
    parameter [127:0] KEY = 128'hba2a1918131211100b0a090803020100
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [3:0] kb_col_n,
    output wire [3:0] kb_row_oe,
    input  wire       serial_sdi,
    input  wire       serial_sclk,
    input  wire       serial_cs_n,
    output wire       serial_sdo,
    output wire       req,
    output wire       rsp_ready,
    output wire       buzzer_out
);
    wire cold_reset_n;
    wire session_reset_n;
    wire safe_active = rst_n && ena && session_reset_n;
    wire session_async_n = rst_n && ena;

    wire scan_tick;
    wire ms_tick;
    wire [3:0] row_oe_raw;
    wire key_valid;
    wire key_ready;
    wire [3:0] key_id;
    wire kb_flush;

    wire txn_valid;
    wire txn_ready;
    wire locked;
    wire beep_event;
    wire submit_event;
    wire pin_rejected;
    wire session_end;

    wire cmd_valid;
    wire cmd_ready;
    wire core_s_valid;
    wire core_s_ready;
    wire core_s_bit;
    wire seal_valid;
    wire seal_ready;
    wire core_m_valid;
    wire core_m_ready;
    wire core_m_bit;
    wire core_m_last;
    wire cipher_abort;

    wire rx_arm;
    wire tx_arm;
    wire link_cancel;
    wire rx_active;
    wire tx_active;
    wire rx_done;
    wire tx_done;
    wire protocol_error;
    wire frame_start;
    wire link_sdo;
    wire req_raw;
    wire rsp_ready_raw;
    wire buzzer_raw;
    wire buzzer_busy_unused;
    wire unused_internal_status = &{1'b0, locked, buzzer_busy_unused, submit_event};

    reset_release u_cold_release (
        .clk(clk), .async_n(rst_n), .released_n(cold_reset_n)
    );
    reset_release u_session_release (
        .clk(clk), .async_n(session_async_n), .released_n(session_reset_n)
    );

    timebase #(.CLK_HZ(CLK_HZ), .SCAN_HZ(SCAN_HZ)) u_timebase (
        .clk(clk), .rst_n(session_reset_n), .scan_tick(scan_tick), .ms_tick(ms_tick)
    );

    assign kb_flush = session_end || pin_rejected;
    kb #(.PRESS_FRAMES(PRESS_FRAMES), .RELEASE_FRAMES(RELEASE_FRAMES)) u_kb (
        .clk(clk), .rst_n(session_reset_n), .enable(safe_active), .flush(kb_flush),
        .scan_tick(scan_tick), .col_n(kb_col_n), .row_oe(row_oe_raw),
        .key_valid(key_valid), .key_ready(key_ready), .key_id(key_id)
    );

    regs #(
        .PIN_LEN(PIN_LEN), .PIN_VALUE(PIN_VALUE), .MAX_FAILS(MAX_FAILS)
    ) u_regs (
        .clk(clk), .cold_rst_n(cold_reset_n), .session_rst_n(session_reset_n),
        .entry_enable(safe_active), .key_valid(key_valid), .key_ready(key_ready),
        .key_id(key_id), .txn_valid(txn_valid), .txn_ready(txn_ready),
        .session_end(session_end), .locked(locked),
        .beep_event(beep_event), .submit_event(submit_event), .pin_rejected(pin_rejected)
    );

    generate
        if (FIXED_KEY_CORE == 1) begin : g_fixed_key_core
            // The ASIC demo uses one elaboration-time key.  This
            // variant removes 128 working-key DFFs while keeping the same
            // stream protocol; fixed-key reconstruction takes 9344 cycles.
            szymon_fixed #(.KEY(KEY)) u_szymon (
                .clk(clk), .rst_n(session_reset_n), .abort(cipher_abort),
                .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
                .s_valid(core_s_valid), .s_ready(core_s_ready), .s_bit(core_s_bit),
                .seal_valid(seal_valid), .seal_ready(seal_ready),
                .m_valid(core_m_valid), .m_ready(core_m_ready),
                .m_bit(core_m_bit), .m_last(core_m_last)
            );
        end else begin : g_runtime_key_core
            szymon u_szymon (
                .clk(clk), .rst_n(session_reset_n), .abort(cipher_abort),
                .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_key(KEY),
                .s_valid(core_s_valid), .s_ready(core_s_ready), .s_bit(core_s_bit),
                .seal_valid(seal_valid), .seal_ready(seal_ready),
                .m_valid(core_m_valid), .m_ready(core_m_ready),
                .m_bit(core_m_bit), .m_last(core_m_last)
            );
        end
        if ((FIXED_KEY_CORE != 0) && (FIXED_KEY_CORE != 1)) begin : g_invalid_core_mode
            INVALID_CORE_MODE_CONFIGURATION invalid_configuration();
        end
    endgenerate

    serial_link u_link (
        .clk(clk), .rst_n(session_reset_n), .cancel(link_cancel),
        .rx_arm(rx_arm), .tx_arm(tx_arm), .rx_active(rx_active),
        .tx_active(tx_active), .rx_done(rx_done), .tx_done(tx_done),
        .protocol_error(protocol_error), .frame_start(frame_start),
        .serial_sdi(serial_sdi), .serial_sclk(serial_sclk),
        .serial_cs_n(serial_cs_n), .serial_sdo(link_sdo),
        .s_valid(core_s_valid), .s_ready(core_s_ready), .s_bit(core_s_bit),
        .m_valid(core_m_valid), .m_ready(core_m_ready),
        .m_bit(core_m_bit), .m_last(core_m_last)
    );

    auth_ctrl #(.AUTH_TIMEOUT_MS(AUTH_TIMEOUT_MS)) u_auth (
        .clk(clk), .rst_n(session_reset_n), .ms_tick(ms_tick),
        .txn_valid(txn_valid), .txn_ready(txn_ready), .session_end(session_end),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .seal_valid(seal_valid), .seal_ready(seal_ready),
        .cipher_m_valid(core_m_valid), .cipher_abort(cipher_abort),
        .rx_arm(rx_arm), .tx_arm(tx_arm), .link_cancel(link_cancel),
        .rx_active(rx_active), .tx_active(tx_active), .rx_done(rx_done),
        .tx_done(tx_done), .protocol_error(protocol_error),
        .frame_start(frame_start), .req(req_raw), .rsp_ready(rsp_ready_raw)
    );

    buzzer #(
        .BEEP_TICKS_MS(BEEP_TICKS_MS), .TONE_HALF_TICKS(TONE_HALF_TICKS)
    ) u_buzzer (
        .clk(clk), .rst_n(session_reset_n), .ms_tick(ms_tick),
        .scan_tick(scan_tick), .beep_event(beep_event),
        .buzzer_out(buzzer_raw), .busy(buzzer_busy_unused)
    );

    // Combinational fail-safe masking is independent of a running clock.
    assign kb_row_oe = safe_active ? row_oe_raw : 4'b0000;
    assign serial_sdo = safe_active ? link_sdo : 1'b0;
    assign req = safe_active ? req_raw : 1'b0;
    assign rsp_ready = safe_active ? rsp_ready_raw : 1'b0;
    assign buzzer_out = safe_active ? (buzzer_raw | unused_internal_status) : 1'b0;

endmodule

`default_nettype wire
