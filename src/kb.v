`timescale 1ns/1ps
`default_nettype none

module kb #(
    parameter PRESS_FRAMES = 20,
    parameter RELEASE_FRAMES = 20
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       flush,
    input  wire       scan_tick,
    input  wire [3:0] col_n,
    output wire [3:0] row_oe,
    output reg        key_valid,
    input  wire       key_ready,
    output reg  [3:0] key_id
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

    function [1:0] hit_count;
        input [3:0] hits;
        integer count;
        begin
            count = {31'b0, hits[0]} + {31'b0, hits[1]}
                + {31'b0, hits[2]} + {31'b0, hits[3]};
            hit_count = (count >= 2) ? 2'd2 : count[1:0];
        end
    endfunction

    function [1:0] first_column;
        input [3:0] hits;
        begin
            if (hits[0]) first_column = 2'd0;
            else if (hits[1]) first_column = 2'd1;
            else if (hits[2]) first_column = 2'd2;
            else if (hits[3]) first_column = 2'd3;
            else first_column = 2'd0;
        end
    endfunction

    localparam integer PRESS_W   = width_for(PRESS_FRAMES);
    localparam integer RELEASE_W = width_for(RELEASE_FRAMES);
    localparam integer COUNT_W = (PRESS_W > RELEASE_W) ? PRESS_W : RELEASE_W;
    localparam [COUNT_W-1:0] PRESS_LAST = PRESS_FRAMES - 1;
    localparam [COUNT_W-1:0] RELEASE_LAST = RELEASE_FRAMES - 1;

    reg [1:0] row_index;
    reg blank_cycle;
    reg [1:0] frame_hits;
    reg [3:0] frame_first_id;

    reg armed;
    reg gesture_active;
    reg gesture_qualified;
    reg gesture_poisoned;
    reg releasing;
    reg [COUNT_W-1:0] debounce_count;

    wire [3:0] col_sync;
    wire [3:0] sample_hits = ~col_sync;
    wire [1:0] sample_count = hit_count(sample_hits);
    wire [2:0] count_sum = frame_hits + sample_count;
    wire [1:0] combined_count = (count_sum >= 2) ? 2'd2 : count_sum[1:0];
    wire [3:0] sample_id = {row_index, first_column(sample_hits)};
    wire [3:0] combined_id = (frame_hits != 0) ? frame_first_id : sample_id;

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_index           <= 2'b00;
            blank_cycle         <= 1'b1;
            frame_hits          <= 2'b00;
            frame_first_id      <= 4'b0000;
            armed               <= 1'b0;
            gesture_active      <= 1'b0;
            gesture_qualified   <= 1'b0;
            gesture_poisoned    <= 1'b0;
            releasing           <= 1'b0;
            debounce_count      <= {COUNT_W{1'b0}};
            key_valid           <= 1'b0;
            key_id              <= 4'b0000;
        end else if (flush) begin
            row_index           <= 2'b00;
            blank_cycle         <= 1'b1;
            frame_hits          <= 2'b00;
            frame_first_id      <= 4'b0000;
            armed               <= 1'b0;
            gesture_active      <= 1'b0;
            gesture_qualified   <= 1'b0;
            gesture_poisoned    <= 1'b0;
            releasing           <= 1'b0;
            debounce_count      <= {COUNT_W{1'b0}};
            key_valid           <= 1'b0;
            key_id              <= 4'b0000;
        end else begin
            // A pending event is a real ready-valid item even if scanning disables.
            if (key_valid && key_ready) begin
                key_valid         <= 1'b0;
                armed             <= 1'b0;
                gesture_active    <= 1'b0;
                gesture_qualified <= 1'b0;
                gesture_poisoned  <= 1'b0;
                releasing         <= 1'b0;
                debounce_count    <= {COUNT_W{1'b0}};
            end

            if (!enable) begin
                row_index         <= 2'b00;
                blank_cycle       <= 1'b1;
                frame_hits        <= 2'b00;
                frame_first_id    <= 4'b0000;
                armed             <= 1'b0;
                gesture_active    <= 1'b0;
                gesture_qualified <= 1'b0;
                gesture_poisoned  <= 1'b0;
                releasing         <= 1'b0;
                debounce_count    <= {COUNT_W{1'b0}};
            end else if (blank_cycle) begin
                // Required break-before-make cycle between active rows.
                blank_cycle <= 1'b0;
            end else if (scan_tick) begin
                blank_cycle <= 1'b1;

                if (row_index == 2'd3) begin
                    row_index      <= 2'd0;
                    frame_hits     <= 2'd0;
                    frame_first_id <= 4'd0;

                    // Ignore frames while a pending event exists or is consumed.
                    if (!key_valid && !(key_valid && key_ready)) begin
                        if (!armed) begin
                            if (combined_count == 0) begin
                                if (debounce_count == RELEASE_LAST) begin
                                    armed          <= 1'b1;
                                    debounce_count <= {COUNT_W{1'b0}};
                                end else begin
                                    debounce_count <= debounce_count + 1'b1;
                                end
                            end else begin
                                debounce_count <= {COUNT_W{1'b0}};
                            end
                        end else if (!gesture_active) begin
                            if (combined_count == 1) begin
                                gesture_active   <= 1'b1;
                                gesture_poisoned <= 1'b0;
                                releasing        <= 1'b0;
                                key_id           <= combined_id;
                                if (PRESS_FRAMES == 1) begin
                                    gesture_qualified <= 1'b1;
                                    debounce_count    <= {COUNT_W{1'b0}};
                                end else begin
                                    gesture_qualified <= 1'b0;
                                    debounce_count    <= {{(COUNT_W-1){1'b0}}, 1'b1};
                                end
                            end else if (combined_count >= 2) begin
                                gesture_active    <= 1'b1;
                                gesture_poisoned  <= 1'b1;
                                gesture_qualified <= 1'b0;
                                releasing         <= 1'b0;
                                debounce_count    <= {COUNT_W{1'b0}};
                            end
                        end else begin
                            if (combined_count == 0) begin
                                if (!releasing) begin
                                    releasing <= 1'b1;
                                    if (RELEASE_FRAMES == 1) begin
                                        if (gesture_qualified && !gesture_poisoned) begin
                                            key_valid <= 1'b1;
                                            armed     <= 1'b0;
                                        end else begin
                                            armed <= 1'b1;
                                        end
                                        gesture_active    <= 1'b0;
                                        gesture_qualified <= 1'b0;
                                        gesture_poisoned  <= 1'b0;
                                        debounce_count    <= {COUNT_W{1'b0}};
                                    end else begin
                                        debounce_count <= {{(COUNT_W-1){1'b0}}, 1'b1};
                                    end
                                end else if (debounce_count == RELEASE_LAST) begin
                                    if (gesture_qualified && !gesture_poisoned) begin
                                        key_valid <= 1'b1;
                                        armed     <= 1'b0;
                                    end else begin
                                        armed <= 1'b1;
                                    end
                                    gesture_active    <= 1'b0;
                                    gesture_qualified <= 1'b0;
                                    gesture_poisoned  <= 1'b0;
                                    releasing         <= 1'b0;
                                    debounce_count    <= {COUNT_W{1'b0}};
                                end else begin
                                    debounce_count <= debounce_count + 1'b1;
                                end
                            end else begin
                                releasing      <= 1'b0;
                                debounce_count <= {COUNT_W{1'b0}};
                                if ((combined_count >= 2) ||
                                    ((combined_count == 1) && (combined_id != key_id))) begin
                                    gesture_poisoned <= 1'b1;
                                end else if (!gesture_qualified && !gesture_poisoned) begin
                                    if (debounce_count == PRESS_LAST) begin
                                        gesture_qualified <= 1'b1;
                                        debounce_count    <= {COUNT_W{1'b0}};
                                    end else begin
                                        debounce_count <= debounce_count + 1'b1;
                                    end
                                end
                            end
                        end
                    end
                end else begin
                    row_index <= row_index + 1'b1;
                    if (combined_count >= 2) begin
                        frame_hits <= 2'd2;
                    end else begin
                        frame_hits <= combined_count;
                        if ((frame_hits == 0) && (sample_count != 0))
                            frame_first_id <= sample_id;
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
