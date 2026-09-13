//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module serial_link (
 1227568     input  wire clk,
 000005     input  wire rst_n,
 000028     input  wire cancel,
        
 000014     input  wire rx_arm,
 000012     input  wire tx_arm,
 000014     output wire rx_active,
 000010     output wire tx_active,
 000004     output reg  rx_done,
 000004     output reg  tx_done,
~000022     output reg  protocol_error,
 000030     output reg  frame_start,
        
 000448     input  wire serial_sdi,
 001292     input  wire serial_sclk,
 000029     input  wire serial_cs_n,
 000128     output wire serial_sdo,
        
 000640     output wire s_valid,
 000008     input  wire s_ready,
 000318     output wire s_bit,
        
 000010     input  wire m_valid,
 000390     output wire m_ready,
 000056     input  wire m_bit,
 000007     input  wire m_last
        );
            localparam [2:0] ST_IDLE        = 3'd0;
            localparam [2:0] ST_WAIT_RX     = 3'd1;
            localparam [2:0] ST_RX          = 3'd2;
            localparam [2:0] ST_WAIT_TX     = 3'd3;
            localparam [2:0] ST_TX          = 3'd4;
            localparam [2:0] ST_WAIT_TX_END = 3'd5;
        
 001292     wire [2:0] serial_sync;
 000030     wire cs_n_sync = serial_sync[2];
 001292     wire sclk_sync = serial_sync[1];
 000448     wire sdi_sync  = serial_sync[0];
 000031     reg cs_n_d;
 001292     reg sclk_d;
 000031     wire cs_fall   = cs_n_d && !cs_n_sync;
 000030     wire cs_rise   = !cs_n_d && cs_n_sync;
 001292     wire sclk_rise = !sclk_d && sclk_sync;
 001292     wire sclk_fall = sclk_d && !sclk_sync;
        
 000030     reg [2:0] state;
 000026     reg seen_cs_high;
 000514     reg [6:0] bit_count;
 000640     reg rx_pending;
 000318     reg rx_bit_hold;
 000388     reg tx_hold_valid;
 000056     reg tx_hold_bit;
 000008     reg tx_hold_last;
 000382     reg tx_sampled_wait_fall;
 000004     reg tx_last_sampled;
        
 000640     wire rx_fire = rx_pending && s_ready;
 000388     wire tx_fire = m_valid && m_ready;
        
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
        
 613785     always @(posedge clk or negedge rst_n) begin
 000015         if (!rst_n) begin
 000015             state                <= ST_IDLE;
 000015             cs_n_d               <= 1'b1;
 000015             sclk_d               <= 1'b0;
 000015             seen_cs_high         <= 1'b0;
 000015             bit_count            <= 7'd0;
 000015             rx_pending           <= 1'b0;
 000015             rx_bit_hold          <= 1'b0;
 000015             tx_hold_valid        <= 1'b0;
 000015             tx_hold_bit          <= 1'b0;
 000015             tx_hold_last         <= 1'b0;
 000015             tx_sampled_wait_fall <= 1'b0;
 000015             tx_last_sampled      <= 1'b0;
 000015             rx_done              <= 1'b0;
 000015             tx_done              <= 1'b0;
 000015             protocol_error       <= 1'b0;
 000015             frame_start          <= 1'b0;
 613777         end else if (cancel) begin
 000014             state                <= ST_IDLE;
 000014             cs_n_d               <= cs_n_sync;
 000014             sclk_d               <= sclk_sync;
 000014             seen_cs_high         <= 1'b0;
 000014             bit_count            <= 7'd0;
 000014             rx_pending           <= 1'b0;
 000014             rx_bit_hold          <= 1'b0;
 000014             tx_hold_valid        <= 1'b0;
 000014             tx_hold_bit          <= 1'b0;
 000014             tx_hold_last         <= 1'b0;
 000014             tx_sampled_wait_fall <= 1'b0;
 000014             tx_last_sampled      <= 1'b0;
 000014             rx_done              <= 1'b0;
 000014             tx_done              <= 1'b0;
 000014             protocol_error       <= 1'b0;
 000014             frame_start          <= 1'b0;
 613777         end else begin
 613777             cs_n_d         <= cs_n_sync;
 613777             sclk_d         <= sclk_sync;
 613777             rx_done        <= 1'b0;
 613777             tx_done        <= 1'b0;
 613777             protocol_error <= 1'b0;
 613777             frame_start    <= cs_fall;
        
 613713             if (rx_fire)
 000320                 rx_pending <= 1'b0;
 613713             if (tx_fire) begin
 000194                 tx_hold_valid <= 1'b1;
 000194                 tx_hold_bit   <= m_bit;
 000194                 tx_hold_last  <= m_last;
                    end
        
 613777             case (state)
 580370                 ST_IDLE: begin
 580370                     seen_cs_high         <= 1'b0;
 580370                     bit_count            <= 7'd0;
 580370                     rx_pending           <= 1'b0;
 580370                     tx_hold_valid        <= 1'b0;
 580370                     tx_sampled_wait_fall <= 1'b0;
 580370                     tx_last_sampled      <= 1'b0;
 000007                     if (rx_arm) begin
 000007                         state        <= ST_WAIT_RX;
 000007                         seen_cs_high <= cs_n_sync;
 580368                     end else if (tx_arm) begin
 000006                         state        <= ST_WAIT_TX;
 000006                         seen_cs_high <= cs_n_sync;
                            end
                        end
        
 025015                 ST_WAIT_RX: begin
 025014                     if (cs_n_sync)
 025014                         seen_cs_high <= 1'b1;
 025014                     if (cs_fall && seen_cs_high) begin
 000007                         state     <= ST_RX;
 000007                         bit_count <= 7'd0;
                            end
                        end
        
 019393                 ST_RX: begin
 000004                     if (cs_rise) begin
 000004                         bit_count <= 7'd0;
~000003                         if ((bit_count == 7'd64) && (!rx_pending || s_ready)) begin
 000002                             state      <= ST_IDLE;
 000002                             rx_done    <= 1'b1;
 000002                             rx_pending <= 1'b0;
~000003                         end else begin
~000003                             state          <= ST_IDLE;
~000003                             protocol_error <= 1'b1;
~000003                             rx_pending     <= 1'b0;
                                end
 019066                     end else if (sclk_rise) begin
~000003                         if (bit_count >= 7'd64) begin
~000003                             state          <= ST_IDLE;
~000003                             protocol_error <= 1'b1;
~000003                             rx_pending     <= 1'b0;
~000320                         end else if (rx_pending && !s_ready) begin
~000001                             state          <= ST_IDLE;
~000001                             protocol_error <= 1'b1;
~000001                             rx_pending     <= 1'b0;
 000320                         end else begin
 000320                             rx_pending  <= 1'b1;
 000320                             rx_bit_hold <= sdi_sync;
 000320                             bit_count   <= bit_count + 1'b1;
                                end
                            end
                        end
        
 001344                 ST_WAIT_TX: begin
 001342                     if (cs_n_sync)
 001342                         seen_cs_high <= 1'b1;
 001342                     if (cs_fall && seen_cs_high) begin
~000005                         if (tx_hold_valid || tx_fire) begin
 000005                             state     <= ST_TX;
 000005                             bit_count <= 7'd0;
~000001                         end else begin
~000001                             state          <= ST_IDLE;
~000001                             protocol_error <= 1'b1;
                                end
                            end
                        end
        
 010388                 ST_TX: begin
~000002                     if (cs_rise) begin
~000002                         state                <= ST_IDLE;
~000002                         protocol_error       <= 1'b1;
~000002                         tx_hold_valid        <= 1'b0;
~000002                         tx_sampled_wait_fall <= 1'b0;
 000192                     end else if (sclk_rise) begin
~000191                         if (!tx_hold_valid || tx_sampled_wait_fall ||
~000001                             (tx_hold_last != (bit_count == 7'd63))) begin
~000001                             state                <= ST_IDLE;
~000001                             protocol_error       <= 1'b1;
~000001                             tx_hold_valid        <= 1'b0;
~000001                             tx_sampled_wait_fall <= 1'b0;
 000191                         end else begin
 000191                             tx_sampled_wait_fall <= 1'b1;
 000191                             bit_count            <= bit_count + 1'b1;
 000189                             if (bit_count == 7'd63)
 000002                                 tx_last_sampled <= 1'b1;
                                end
 010003                     end else if (sclk_fall && tx_sampled_wait_fall) begin
 000191                         tx_hold_valid        <= 1'b0;
 000191                         tx_sampled_wait_fall <= 1'b0;
 000189                         if (tx_last_sampled)
 000002                             state <= ST_WAIT_TX_END;
                            end
                        end
        
 000056                 ST_WAIT_TX_END: begin
 000002                     if (cs_rise) begin
 000002                         state           <= ST_IDLE;
 000002                         tx_done         <= 1'b1;
 000002                         tx_last_sampled <= 1'b0;
~000054                     end else if (sclk_rise) begin
~000001                         state          <= ST_IDLE;
~000001                         protocol_error <= 1'b1;
                            end
                        end
        
%000000                 default: begin
%000000                     state          <= ST_IDLE;
%000000                     protocol_error <= 1'b1;
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
        
