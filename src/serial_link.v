`timescale 1ns/1ps
`default_nettype none

module serial_link (
    input  wire clk,
    input  wire rst_n,
    input  wire cancel,

    input  wire rx_arm,
    input  wire tx_arm,
    output wire rx_active,
    output wire tx_active,
    output reg  rx_done,
    output reg  tx_done,
    output reg  protocol_error,
    output reg  frame_start,

    input  wire serial_sdi,
    input  wire serial_sclk,
    input  wire serial_cs_n,
    output wire serial_sdo,

    output wire s_valid,
    input  wire s_ready,
    output wire s_bit,

    input  wire m_valid,
    output wire m_ready,
    input  wire m_bit,
    input  wire m_last
);
    localparam [2:0] ST_IDLE        = 3'd0;
    localparam [2:0] ST_WAIT_RX     = 3'd1;
    localparam [2:0] ST_RX          = 3'd2;
    localparam [2:0] ST_WAIT_TX     = 3'd3;
    localparam [2:0] ST_TX          = 3'd4;
    localparam [2:0] ST_WAIT_TX_END = 3'd5;

    wire [2:0] serial_sync;
    wire cs_n_sync = serial_sync[2];
    wire sclk_sync = serial_sync[1];
    wire sdi_sync  = serial_sync[0];
    reg cs_n_d;
    reg sclk_d;
    wire cs_fall   = cs_n_d && !cs_n_sync;
    wire cs_rise   = !cs_n_d && cs_n_sync;
    wire sclk_rise = !sclk_d && sclk_sync;
    wire sclk_fall = sclk_d && !sclk_sync;

    reg [2:0] state;
    reg seen_cs_high;
    reg [6:0] bit_count;
    reg rx_pending;
    reg rx_bit_hold;
    reg tx_hold_valid;
    reg tx_hold_bit;
    reg tx_hold_last;
    reg tx_sampled_wait_fall;
    reg tx_last_sampled;

    wire rx_fire = rx_pending && s_ready;
    wire tx_fire = m_valid && m_ready;

    sync2 #(.WIDTH(3)) u_serial_sync (
        .clk(clk),
        .rst_n(rst_n),
        .async_in({serial_cs_n, serial_sclk, serial_sdi}),
        .sync_out(serial_sync)
    );

    assign rx_active = (state == ST_RX);
    assign tx_active = (state == ST_TX) || (state == ST_WAIT_TX_END);
    assign s_valid = rx_pending;
    assign s_bit = rx_bit_hold;
    assign m_ready = ((state == ST_WAIT_TX) || (state == ST_TX))
        && !tx_hold_valid && !tx_sampled_wait_fall && !tx_last_sampled;
    assign serial_sdo = ((state == ST_TX) && !cs_n_sync && tx_hold_valid)
        ? tx_hold_bit : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                <= ST_IDLE;
            cs_n_d               <= 1'b1;
            sclk_d               <= 1'b0;
            seen_cs_high         <= 1'b0;
            bit_count            <= 7'd0;
            rx_pending           <= 1'b0;
            rx_bit_hold          <= 1'b0;
            tx_hold_valid        <= 1'b0;
            tx_hold_bit          <= 1'b0;
            tx_hold_last         <= 1'b0;
            tx_sampled_wait_fall <= 1'b0;
            tx_last_sampled      <= 1'b0;
            rx_done              <= 1'b0;
            tx_done              <= 1'b0;
            protocol_error       <= 1'b0;
            frame_start          <= 1'b0;
        end else if (cancel) begin
            state                <= ST_IDLE;
            cs_n_d               <= cs_n_sync;
            sclk_d               <= sclk_sync;
            seen_cs_high         <= 1'b0;
            bit_count            <= 7'd0;
            rx_pending           <= 1'b0;
            rx_bit_hold          <= 1'b0;
            tx_hold_valid        <= 1'b0;
            tx_hold_bit          <= 1'b0;
            tx_hold_last         <= 1'b0;
            tx_sampled_wait_fall <= 1'b0;
            tx_last_sampled      <= 1'b0;
            rx_done              <= 1'b0;
            tx_done              <= 1'b0;
            protocol_error       <= 1'b0;
            frame_start          <= 1'b0;
        end else begin
            cs_n_d         <= cs_n_sync;
            sclk_d         <= sclk_sync;
            rx_done        <= 1'b0;
            tx_done        <= 1'b0;
            protocol_error <= 1'b0;
            frame_start    <= cs_fall;

            if (rx_fire)
                rx_pending <= 1'b0;
            if (tx_fire) begin
                tx_hold_valid <= 1'b1;
                tx_hold_bit   <= m_bit;
                tx_hold_last  <= m_last;
            end

            case (state)
                ST_IDLE: begin
                    seen_cs_high         <= 1'b0;
                    bit_count            <= 7'd0;
                    rx_pending           <= 1'b0;
                    tx_hold_valid        <= 1'b0;
                    tx_sampled_wait_fall <= 1'b0;
                    tx_last_sampled      <= 1'b0;
                    if (rx_arm) begin
                        state        <= ST_WAIT_RX;
                        seen_cs_high <= cs_n_sync;
                    end else if (tx_arm) begin
                        state        <= ST_WAIT_TX;
                        seen_cs_high <= cs_n_sync;
                    end
                end

                ST_WAIT_RX: begin
                    if (cs_n_sync)
                        seen_cs_high <= 1'b1;
                    if (cs_fall && seen_cs_high) begin
                        state     <= ST_RX;
                        bit_count <= 7'd0;
                    end
                end

                ST_RX: begin
                    if (cs_rise) begin
                        bit_count <= 7'd0;
                        if ((bit_count == 7'd64) && (!rx_pending || s_ready)) begin
                            state      <= ST_IDLE;
                            rx_done    <= 1'b1;
                            rx_pending <= 1'b0;
                        end else begin
                            state          <= ST_IDLE;
                            protocol_error <= 1'b1;
                            rx_pending     <= 1'b0;
                        end
                    end else if (sclk_rise) begin
                        if (bit_count >= 7'd64) begin
                            state          <= ST_IDLE;
                            protocol_error <= 1'b1;
                            rx_pending     <= 1'b0;
                        end else if (rx_pending && !s_ready) begin
                            state          <= ST_IDLE;
                            protocol_error <= 1'b1;
                            rx_pending     <= 1'b0;
                        end else begin
                            rx_pending  <= 1'b1;
                            rx_bit_hold <= sdi_sync;
                            bit_count   <= bit_count + 1'b1;
                        end
                    end
                end

                ST_WAIT_TX: begin
                    if (cs_n_sync)
                        seen_cs_high <= 1'b1;
                    if (cs_fall && seen_cs_high) begin
                        if (tx_hold_valid || tx_fire) begin
                            state     <= ST_TX;
                            bit_count <= 7'd0;
                        end else begin
                            state          <= ST_IDLE;
                            protocol_error <= 1'b1;
                        end
                    end
                end

                ST_TX: begin
                    if (cs_rise) begin
                        state                <= ST_IDLE;
                        protocol_error       <= 1'b1;
                        tx_hold_valid        <= 1'b0;
                        tx_sampled_wait_fall <= 1'b0;
                    end else if (sclk_rise) begin
                        if (!tx_hold_valid || tx_sampled_wait_fall ||
                            (tx_hold_last != (bit_count == 7'd63))) begin
                            state                <= ST_IDLE;
                            protocol_error       <= 1'b1;
                            tx_hold_valid        <= 1'b0;
                            tx_sampled_wait_fall <= 1'b0;
                        end else begin
                            tx_sampled_wait_fall <= 1'b1;
                            bit_count            <= bit_count + 1'b1;
                            if (bit_count == 7'd63)
                                tx_last_sampled <= 1'b1;
                        end
                    end else if (sclk_fall && tx_sampled_wait_fall) begin
                        tx_hold_valid        <= 1'b0;
                        tx_sampled_wait_fall <= 1'b0;
                        if (tx_last_sampled)
                            state <= ST_WAIT_TX_END;
                    end
                end

                ST_WAIT_TX_END: begin
                    if (cs_rise) begin
                        state           <= ST_IDLE;
                        tx_done         <= 1'b1;
                        tx_last_sampled <= 1'b0;
                    end else if (sclk_rise) begin
                        state          <= ST_IDLE;
                        protocol_error <= 1'b1;
                    end
                end

                default: begin
                    state          <= ST_IDLE;
                    protocol_error <= 1'b1;
                end
            endcase
        end
    end

`ifdef FORMAL
    reg f_past_valid;
    reg f_prev_s_stall;
    reg f_prev_s_bit;
    always @(posedge clk) begin
        if (!rst_n) begin
            f_past_valid <= 1'b0;
        end else begin
            f_past_valid <= 1'b1;
            f_prev_s_stall <= s_valid && !s_ready && !cancel
                && !protocol_error && !sclk_rise && !cs_rise;
            f_prev_s_bit <= s_bit;
        end
    end
    always @* begin
        if (f_past_valid) begin
            assert(state <= ST_WAIT_TX_END);
            assert(bit_count <= 7'd64);
            if (rx_pending) assert(state == ST_RX);
            if (tx_sampled_wait_fall) assert(state == ST_TX);
            if (tx_last_sampled)
                assert((state == ST_TX) || (state == ST_WAIT_TX_END));
            if (state != ST_TX) assert(serial_sdo == 1'b0);           // F-07
            if (rx_done) assert(bit_count == 7'd0);                  // F-05
            if (f_prev_s_stall && rst_n && !cancel) begin
                assert(s_valid);                                     // F-06
                assert(s_bit == f_prev_s_bit);
            end
        end
    end
`endif
endmodule

`default_nettype wire
