//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none

        module kb #(
            parameter PRESS_FRAMES = 20,
            parameter RELEASE_FRAMES = 20
        ) (
 1227568     input  wire       clk,
 000005     input  wire       rst_n,
 000005     input  wire       enable,
 000650     input  wire       flush,
 024136     input  wire       scan_tick,
 001511     input  wire [3:0] col_n,
 006684     output wire [3:0] row_oe,
 000061     output reg        key_valid,
 000042     input  wire       key_ready,
~000025     output reg  [3:0] key_id
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
        
 000001     function [1:0] hit_count;
                input [3:0] hits;
                integer count;
 000001         begin
 000001             count = {31'b0, hits[0]} + {31'b0, hits[1]}
 000001                 + {31'b0, hits[2]} + {31'b0, hits[3]};
 000001             hit_count = (count >= 2) ? 2'd2 : count[1:0];
                end
            endfunction
        
 613786     function [1:0] first_column;
                input [3:0] hits;
 613786         begin
 016443             if (hits[0]) first_column = 2'd0;
 016434             else if (hits[1]) first_column = 2'd1;
 010956             else if (hits[2]) first_column = 2'd2;
~569953             else if (hits[3]) first_column = 2'd3;
 569953             else first_column = 2'd0;
                end
            endfunction
        
            localparam integer PRESS_W   = width_for(PRESS_FRAMES);
            localparam integer RELEASE_W = width_for(RELEASE_FRAMES);
            localparam integer COUNT_W = (PRESS_W > RELEASE_W) ? PRESS_W : RELEASE_W;
            localparam [COUNT_W-1:0] PRESS_LAST = PRESS_FRAMES - 1;
            localparam [COUNT_W-1:0] RELEASE_LAST = RELEASE_FRAMES - 1;
        
 012068     reg [1:0] row_index;
 024785     reg blank_cycle;
~001480     reg [1:0] frame_hits;
~000396     reg [3:0] frame_first_id;
        
 000687     reg armed;
 000652     reg gesture_active;
 000064     reg gesture_qualified;
~000606     reg gesture_poisoned;
 000656     reg releasing;
~001394     reg [COUNT_W-1:0] debounce_count;
        
 001511     wire [3:0] col_sync;
 001512     wire [3:0] sample_hits = ~col_sync;
 002308     wire [1:0] sample_count = hit_count(sample_hits);
~004832     wire [2:0] count_sum = frame_hits + sample_count;
 002562     wire [1:0] combined_count = (count_sum >= 2) ? 2'd2 : count_sum[1:0];
 012068     wire [3:0] sample_id = {row_index, first_column(sample_hits)};
 009174     wire [3:0] combined_id = (frame_hits != 0) ? frame_first_id : sample_id;

            generate
                if ((PRESS_FRAMES < 1) || (RELEASE_FRAMES < 1)) begin : g_invalid_kb
                    INVALID_KB_CONFIGURATION invalid_configuration();
                end
            endgenerate
        
            sync2 #(.WIDTH(4)) u_col_sync (
                .clk(clk),
                .rst_n(rst_n),
                .async_in(col_n),
                .sync_out(col_sync)
            );
        
            assign row_oe = blank_cycle ? 4'b0000 : (4'b0001 << row_index);
        
 613785     always @(posedge clk or negedge rst_n) begin
 000015         if (!rst_n) begin
 000015             row_index           <= 2'b00;
 000015             blank_cycle         <= 1'b1;
 000015             frame_hits          <= 2'b00;
 000015             frame_first_id      <= 4'b0000;
 000015             armed               <= 1'b0;
 000015             gesture_active      <= 1'b0;
 000015             gesture_qualified   <= 1'b0;
 000015             gesture_poisoned    <= 1'b0;
 000015             releasing           <= 1'b0;
 000015             debounce_count      <= {COUNT_W{1'b0}};
 000015             key_valid           <= 1'b0;
 000015             key_id              <= 4'b0000;
 613776         end else if (flush) begin
 000325             row_index           <= 2'b00;
 000325             blank_cycle         <= 1'b1;
 000325             frame_hits          <= 2'b00;
 000325             frame_first_id      <= 4'b0000;
 000325             armed               <= 1'b0;
 000325             gesture_active      <= 1'b0;
 000325             gesture_qualified   <= 1'b0;
 000325             gesture_poisoned    <= 1'b0;
 000325             releasing           <= 1'b0;
 000325             debounce_count      <= {COUNT_W{1'b0}};
 000325             key_valid           <= 1'b0;
 000325             key_id              <= 4'b0000;
 613776         end else begin
                    // A pending event is a real ready-valid item even if scanning disables.
 613769             if (key_valid && key_ready) begin
 000027                 key_valid         <= 1'b0;
 000027                 armed             <= 1'b0;
 000027                 gesture_active    <= 1'b0;
 000027                 gesture_qualified <= 1'b0;
 000027                 gesture_poisoned  <= 1'b0;
 000027                 releasing         <= 1'b0;
 000027                 debounce_count    <= {COUNT_W{1'b0}};
                    end
        
~000005             if (!enable) begin
~000005                 row_index         <= 2'b00;
~000005                 blank_cycle       <= 1'b1;
~000005                 frame_hits        <= 2'b00;
~000005                 frame_first_id    <= 4'b0000;
~000005                 armed             <= 1'b0;
~000005                 gesture_active    <= 1'b0;
~000005                 gesture_qualified <= 1'b0;
~000005                 gesture_poisoned  <= 1'b0;
~000005                 releasing         <= 1'b0;
~000005                 debounce_count    <= {COUNT_W{1'b0}};
 012392             end else if (blank_cycle) begin
                        // Required break-before-make cycle between active rows.
 012392                 blank_cycle <= 1'b0;
 608863             end else if (scan_tick) begin
 012068                 blank_cycle <= 1'b1;
        
 009051                 if (row_index == 2'd3) begin
 003017                     row_index      <= 2'd0;
 003017                     frame_hits     <= 2'd0;
 003017                     frame_first_id <= 4'd0;
        
                            // Ignore frames while a pending event exists or is consumed.
~003011                     if (!key_valid && !(key_valid && key_ready)) begin
 001044                         if (!armed) begin
~001032                             if (combined_count == 0) begin
~000688                                 if (debounce_count == RELEASE_LAST) begin
 000344                                     armed          <= 1'b1;
 000344                                     debounce_count <= {COUNT_W{1'b0}};
~000688                                 end else begin
~000688                                     debounce_count <= debounce_count + 1'b1;
                                        end
~000012                             end else begin
~000012                                 debounce_count <= {COUNT_W{1'b0}};
                                    end
 001636                         end else if (!gesture_active) begin
 000032                             if (combined_count == 1) begin
 000032                                 gesture_active   <= 1'b1;
 000032                                 gesture_poisoned <= 1'b0;
 000032                                 releasing        <= 1'b0;
 000032                                 key_id           <= combined_id;
~000032                                 if (PRESS_FRAMES == 1) begin
~000032                                     gesture_qualified <= 1'b1;
~000032                                     debounce_count    <= {COUNT_W{1'b0}};
~000026                                 end else begin
~000026                                     gesture_qualified <= 1'b0;
~000026                                     debounce_count    <= {{(COUNT_W-1){1'b0}}, 1'b1};
                                        end
~000805                             end else if (combined_count >= 2) begin
~000300                                 gesture_active    <= 1'b1;
~000300                                 gesture_poisoned  <= 1'b1;
~000300                                 gesture_qualified <= 1'b0;
~000300                                 releasing         <= 1'b0;
~000300                                 debounce_count    <= {COUNT_W{1'b0}};
                                    end
 001636                         end else begin
 000977                             if (combined_count == 0) begin
 000328                                 if (!releasing) begin
 000328                                     releasing <= 1'b1;
~000328                                     if (RELEASE_FRAMES == 1) begin
~000031                                         if (gesture_qualified && !gesture_poisoned) begin
~000031                                             key_valid <= 1'b1;
~000031                                             armed     <= 1'b0;
~000004                                         end else begin
~000004                                             armed <= 1'b1;
                                                end
~000035                                         gesture_active    <= 1'b0;
~000035                                         gesture_qualified <= 1'b0;
~000035                                         gesture_poisoned  <= 1'b0;
~000035                                         debounce_count    <= {COUNT_W{1'b0}};
~000328                                     end else begin
~000328                                         debounce_count <= {{(COUNT_W-1){1'b0}}, 1'b1};
                                            end
~000325                                 end else if (debounce_count == RELEASE_LAST) begin
~000304                                     if (gesture_qualified && !gesture_poisoned) begin
~000020                                         key_valid <= 1'b1;
~000020                                         armed     <= 1'b0;
~000304                                     end else begin
~000304                                         armed <= 1'b1;
                                            end
~000324                                     gesture_active    <= 1'b0;
~000324                                     gesture_qualified <= 1'b0;
~000324                                     gesture_poisoned  <= 1'b0;
~000324                                     releasing         <= 1'b0;
~000324                                     debounce_count    <= {COUNT_W{1'b0}};
~000325                                 end else begin
~000325                                     debounce_count <= debounce_count + 1'b1;
                                        end
 000659                             end else begin
 000659                                 releasing      <= 1'b0;
 000659                                 debounce_count <= {COUNT_W{1'b0}};
~000603                                 if ((combined_count >= 2) ||
~000603                                     ((combined_count == 1) && (combined_id != key_id))) begin
~000603                                     gesture_poisoned <= 1'b1;
~000152                                 end else if (!gesture_qualified && !gesture_poisoned) begin
~000144                                     if (debounce_count == PRESS_LAST) begin
~000024                                         gesture_qualified <= 1'b1;
~000024                                         debounce_count    <= {COUNT_W{1'b0}};
~000144                                     end else begin
~000144                                         debounce_count <= debounce_count + 1'b1;
                                            end
                                        end
                                    end
                                end
                            end
 009051                 end else begin
 009051                     row_index <= row_index + 1'b1;
~007486                     if (combined_count >= 2) begin
~001565                         frame_hits <= 2'd2;
 007486                     end else begin
 007486                         frame_hits <= combined_count;
 007108                         if ((frame_hits == 0) && (sample_count != 0))
 000378                             frame_first_id <= sample_id;
                            end
                        end
                    end
                end
            end
        
        `ifdef FORMAL
            reg f_past_valid;
            reg f_prev_key_stall;
            reg [3:0] f_prev_key_id;
            always @(posedge clk) begin
                if (!rst_n) begin
                    f_past_valid <= 1'b0;
                end else begin
                    f_past_valid <= 1'b1;
                    f_prev_key_stall <= key_valid && !key_ready && !flush;
                    f_prev_key_id <= key_id;
                end
            end
            always @* begin
                if (f_past_valid) begin
                    assert((row_oe & (row_oe - 1'b1)) == 0);                 // F-08
                    if (gesture_poisoned) assert(!key_valid);                // F-09
                    if (f_prev_key_stall && rst_n && !flush) begin
                        assert(key_valid);                                   // F-06
                        assert(key_id == f_prev_key_id);
                    end
                end
            end
        `endif
        endmodule
        
        `default_nettype wire
        
