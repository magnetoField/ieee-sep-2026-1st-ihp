//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module auth_ctrl #(
            parameter AUTH_TIMEOUT_MS = 5000
        ) (
 1227568     input  wire         clk,
 000057     input  wire         rst_n,
 001926     input  wire         ms_tick,
        
 000040     input  wire         txn_valid,
 000041     output wire         txn_ready,
 000022     output wire         session_end,
        
 000040     output wire         cmd_valid,
 000034     input  wire         cmd_ready,
 000022     output wire         seal_valid,
 000018     input  wire         seal_ready,
 000014     input  wire         cipher_m_valid,
 000022     output wire         cipher_abort,
        
 000034     output wire         rx_arm,
 000014     output wire         tx_arm,
 000022     output wire         link_cancel,
 000026     input  wire         rx_active,
 000006     input  wire         tx_active,
 000022     input  wire         rx_done,
 000004     input  wire         tx_done,
~000020     input  wire         protocol_error,
~000018     input  wire         frame_start,
        
 000030     output wire         req,
 000014     output wire         rsp_ready
        );
%000000     function integer width_for;
                input integer maximum;
                integer value;
%000000         begin
%000000             value = maximum;
%000000             width_for = 0;
%000000             while (value > 0) begin
%000000                 width_for = width_for + 1;
%000000                 value = value >> 1;
                    end
%000000             if (width_for < 1)
%000000                 width_for = 1;
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
        
 000112     reg [3:0] state;
 000040     reg timeout_active;
~000656     reg [TIMEOUT_W-1:0] timeout_count;
~000002     wire timeout_now = timeout_active && ms_tick
                && (timeout_count == AUTH_TIMEOUT_MS - 1);
~000010     wire unexpected_frame = frame_start
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
        
 613785     always @(posedge clk or negedge rst_n) begin
 613778         if (!rst_n) begin
 000059             state              <= ST_IDLE;
 000059             timeout_active     <= 1'b0;
 000059             timeout_count      <= {TIMEOUT_W{1'b0}};
 613778         end else begin
 000020             if (txn_valid && txn_ready) begin
 000020                 timeout_active <= 1'b1;
 000020                 timeout_count  <= {TIMEOUT_W{1'b0}};
 613735             end else if (timeout_active && ms_tick) begin
~000653                 if (!timeout_now)
 000653                     timeout_count <= timeout_count + 1'b1;
                    end
        
~000001             if (timeout_now && (state != ST_CLEANUP)) begin
~000001                 state <= ST_CLEANUP;
~613778             end else if ((protocol_error || unexpected_frame)
~000010                     && (state != ST_IDLE) && (state != ST_CLEANUP)) begin
~000010                 state <= ST_CLEANUP;
 613778             end else begin
 613778                 case (state)
 571019                     ST_IDLE: begin
 571018                         if (txn_valid && txn_ready) begin
 000020                             state <= ST_CMD;
                                end
                            end
 000017                     ST_CMD:
~000017                         if (cmd_valid && cmd_ready)
 000017                             state <= ST_ARM_RX;
 000015                     ST_ARM_RX:
 000015                         state <= ST_WAIT_RX;
 025016                     ST_WAIT_RX:
~025015                         if (rx_active)
 000013                             state <= ST_RX;
 009215                     ST_RX:
~009213                         if (rx_done)
 000011                             state <= ST_SEAL;
 000009                     ST_SEAL:
~000009                         if (seal_valid && seal_ready)
 000009                             state <= ST_CRYPT;
 018690                     ST_CRYPT:
~018688                         if (cipher_m_valid)
 000007                             state <= ST_ARM_TX;
 000005                     ST_ARM_TX:
 000005                         state <= ST_WAIT_TX;
 001346                     ST_WAIT_TX:
~001344                         if (tx_active)
 000003                             state <= ST_TX;
 007720                     ST_TX:
~007718                         if (tx_done)
~000002                             state <= ST_CLEANUP;
 000011                     ST_CLEANUP: begin
 000011                         state            <= ST_IDLE;
 000011                         timeout_active   <= 1'b0;
 000011                         timeout_count    <= {TIMEOUT_W{1'b0}};
                            end
%000000                     default:
%000000                         state <= ST_CLEANUP;
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
        
