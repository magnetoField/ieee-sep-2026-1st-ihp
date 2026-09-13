`timescale 1ns/1ps
`default_nettype none

module auth_ctrl #(
    parameter AUTH_TIMEOUT_MS = 5000
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         ms_tick,

    input  wire         txn_valid,
    output wire         txn_ready,
    output wire         session_end,

    output wire         cmd_valid,
    input  wire         cmd_ready,
    output wire         seal_valid,
    input  wire         seal_ready,
    input  wire         cipher_m_valid,
    output wire         cipher_abort,

    output wire         rx_arm,
    output wire         tx_arm,
    output wire         link_cancel,
    input  wire         rx_active,
    input  wire         tx_active,
    input  wire         rx_done,
    input  wire         tx_done,
    input  wire         protocol_error,
    input  wire         frame_start,

    output wire         req,
    output wire         rsp_ready
);
    function integer width_for;
        input integer maximum;
        integer value;
        begin
            value = maximum;
            width_for = 0;
            while (value > 0) begin
                width_for = width_for + 1;
                value = value >> 1;
            end
            if (width_for < 1)
                width_for = 1;
        end
    endfunction

    localparam [3:0] ST_IDLE     = 4'd0;
    localparam [3:0] ST_CMD      = 4'd1;
    localparam [3:0] ST_ARM_RX   = 4'd2;
    localparam [3:0] ST_WAIT_RX  = 4'd3;
    localparam [3:0] ST_RX       = 4'd4;
    localparam [3:0] ST_SEAL     = 4'd5;
    localparam [3:0] ST_CRYPT    = 4'd6;
    localparam [3:0] ST_ARM_TX   = 4'd7;
    localparam [3:0] ST_WAIT_TX  = 4'd8;
    localparam [3:0] ST_TX       = 4'd9;
    localparam [3:0] ST_CLEANUP  = 4'd10;
    localparam integer TIMEOUT_W = width_for(AUTH_TIMEOUT_MS - 1);

    reg [3:0] state;
    reg timeout_active;
    reg [TIMEOUT_W-1:0] timeout_count;
    wire timeout_now = timeout_active && ms_tick
        && (timeout_count == AUTH_TIMEOUT_MS - 1);
    wire unexpected_frame = frame_start
        && (state != ST_WAIT_RX) && (state != ST_RX)
        && (state != ST_WAIT_TX) && (state != ST_TX);

    generate
        if (AUTH_TIMEOUT_MS < 1) begin : g_invalid_auth_timeout
            INVALID_AUTH_TIMEOUT_CONFIGURATION invalid_configuration();
        end
    endgenerate

    assign txn_ready = (state == ST_IDLE) && !timeout_now;
    assign cmd_valid = (state == ST_CMD);
    assign seal_valid = (state == ST_SEAL);
    assign rx_arm = (state == ST_ARM_RX);
    assign tx_arm = (state == ST_ARM_TX);
    assign session_end = (state == ST_CLEANUP);
    assign cipher_abort = (state == ST_CLEANUP);
    assign link_cancel = (state == ST_CLEANUP);
    assign req = (state == ST_WAIT_RX) && !rx_active;
    assign rsp_ready = (state == ST_ARM_TX) || (state == ST_WAIT_TX) || (state == ST_TX);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= ST_IDLE;
            timeout_active     <= 1'b0;
            timeout_count      <= {TIMEOUT_W{1'b0}};
        end else begin
            if (txn_valid && txn_ready) begin
                timeout_active <= 1'b1;
                timeout_count  <= {TIMEOUT_W{1'b0}};
            end else if (timeout_active && ms_tick) begin
                if (!timeout_now)
                    timeout_count <= timeout_count + 1'b1;
            end

            if (timeout_now && (state != ST_CLEANUP)) begin
                state <= ST_CLEANUP;
            end else if ((protocol_error || unexpected_frame)
                    && (state != ST_IDLE) && (state != ST_CLEANUP)) begin
                state <= ST_CLEANUP;
            end else begin
                case (state)
                    ST_IDLE: begin
                        if (txn_valid && txn_ready) begin
                            state <= ST_CMD;
                        end
                    end
                    ST_CMD:
                        if (cmd_valid && cmd_ready)
                            state <= ST_ARM_RX;
                    ST_ARM_RX:
                        state <= ST_WAIT_RX;
                    ST_WAIT_RX:
                        if (rx_active)
                            state <= ST_RX;
                    ST_RX:
                        if (rx_done)
                            state <= ST_SEAL;
                    ST_SEAL:
                        if (seal_valid && seal_ready)
                            state <= ST_CRYPT;
                    ST_CRYPT:
                        if (cipher_m_valid)
                            state <= ST_ARM_TX;
                    ST_ARM_TX:
                        state <= ST_WAIT_TX;
                    ST_WAIT_TX:
                        if (tx_active)
                            state <= ST_TX;
                    ST_TX:
                        if (tx_done)
                            state <= ST_CLEANUP;
                    ST_CLEANUP: begin
                        state            <= ST_IDLE;
                        timeout_active   <= 1'b0;
                        timeout_count    <= {TIMEOUT_W{1'b0}};
                    end
                    default:
                        state <= ST_CLEANUP;
                endcase
            end
        end
    end

`ifdef FORMAL
    reg f_token;
    reg f_cmd_seen;
    reg f_seal_seen;
    reg f_rx_complete;
    reg f_past_valid;
    reg f_prev_timeout_now;
    reg [3:0] f_prev_state;
    always @(posedge clk) begin
        if (!rst_n) begin
            f_token <= 1'b0;
            f_cmd_seen <= 1'b0;
            f_seal_seen <= 1'b0;
            f_rx_complete <= 1'b0;
            f_past_valid <= 1'b0;
            f_prev_timeout_now <= 1'b0;
            f_prev_state <= ST_IDLE;
        end else begin
            if (txn_valid && txn_ready) begin
                f_token <= 1'b1;
                f_cmd_seen <= 1'b0;
                f_seal_seen <= 1'b0;
                f_rx_complete <= 1'b0;
            end
            if (cmd_valid && cmd_ready)
                f_cmd_seen <= 1'b1;
            if (seal_valid && seal_ready)
                f_seal_seen <= 1'b1;
            if ((state == ST_RX) && rx_done)
                f_rx_complete <= 1'b1;
            if (session_end) begin
                f_token <= 1'b0;
                f_rx_complete <= 1'b0;
            end
            f_past_valid <= 1'b1;
            f_prev_timeout_now <= timeout_now;
            f_prev_state <= state;
        end
    end
    always @* begin
        if (f_past_valid && rst_n) begin
            assert(state <= ST_CLEANUP);
            assert(timeout_count < AUTH_TIMEOUT_MS);
            if (state == ST_IDLE)
                assert(!f_token);
            if ((state >= ST_CMD) && (state <= ST_TX))
                assert(f_token);
            if ((state >= ST_ARM_RX) && (state <= ST_TX))
                assert(f_cmd_seen);
            if ((state >= ST_SEAL) && (state <= ST_TX))
                assert(f_rx_complete);
            if ((state >= ST_CRYPT) && (state <= ST_TX))
                assert(f_seal_seen);
            if (txn_valid && txn_ready) assert(!f_token);
            if (cmd_valid && cmd_ready) assert(f_token && !f_cmd_seen); // F-04
            if (seal_valid && seal_ready)
                assert(f_token && f_cmd_seen && !f_seal_seen);        // F-04/F-05
            if (f_prev_timeout_now && (f_prev_state != ST_CLEANUP))
                assert(state == ST_CLEANUP);                         // F-13 transition
            assert(!seal_valid || f_cmd_seen);                         // F-05
            assert(!seal_valid || f_rx_complete);                      // F-05
        end
    end
`endif
endmodule

`default_nettype wire
