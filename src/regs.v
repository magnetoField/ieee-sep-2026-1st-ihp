`timescale 1ns/1ps
`default_nettype none

module regs #(
    parameter PIN_LEN = 4,
    parameter [31:0] PIN_VALUE = 32'h00001234,
    parameter MAX_FAILS = 3
) (
    input  wire         clk,
    input  wire         cold_rst_n,
    input  wire         session_rst_n,
    input  wire         entry_enable,
    input  wire         key_valid,
    output wire         key_ready,
    input  wire [3:0]   key_id,
    output reg          txn_valid,
    input  wire         txn_ready,
    input  wire         session_end,
    output wire         locked,
    output wire         beep_event,
    output wire         submit_event,
    output wire         pin_rejected
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

    function bcd_is_valid;
        input [31:0] value;
        integer index;
        begin
            bcd_is_valid = 1'b1;
            for (index = 0; index < PIN_LEN; index = index + 1)
                if (((value >> (index * 4)) & 32'h0000000f) > 9)
                    bcd_is_valid = 1'b0;
        end
    endfunction

    localparam integer DIGIT_W = width_for(PIN_LEN - 1);
    localparam integer FAIL_W  = width_for(MAX_FAILS);
    // DIGIT_W is derived from PIN_LEN, so this elaboration-time truncation is exact.
    /* verilator lint_off WIDTHTRUNC */
    localparam [DIGIT_W-1:0] DIGIT_LAST = PIN_LEN - 1;
    /* verilator lint_on WIDTHTRUNC */
    localparam PIN_BCD_VALID = bcd_is_valid(PIN_VALUE);

    reg [31:0] pin_shift;
    reg [DIGIT_W-1:0] digit_count;
    reg [FAIL_W-1:0] fail_count;
    reg session_busy;
    wire unused_pin_upper = &{1'b0, pin_shift[31:28]};

    reg digit_valid;
    reg star_key;
    reg [3:0] digit;
    wire key_fire;
    wire [31:0] next_pin = {pin_shift[27:0], digit};
    wire pin_matches = next_pin[(PIN_LEN*4)-1:0] == PIN_VALUE[(PIN_LEN*4)-1:0];

    generate
        if ((PIN_LEN < 1) || (PIN_LEN > 8) || (MAX_FAILS < 1)
            || !PIN_BCD_VALID) begin : g_invalid_regs
            INVALID_REGS_CONFIGURATION invalid_configuration();
        end
    endgenerate

    always @* begin
        digit_valid = 1'b1;
        star_key = 1'b0;
        digit = 4'd0;
        case (key_id)
            4'd0:  digit = 4'd1;
            4'd1:  digit = 4'd2;
            4'd2:  digit = 4'd3;
            4'd4:  digit = 4'd4;
            4'd5:  digit = 4'd5;
            4'd6:  digit = 4'd6;
            4'd8:  digit = 4'd7;
            4'd9:  digit = 4'd8;
            4'd10: digit = 4'd9;
            4'd13: digit = 4'd0;
            4'd12: begin digit_valid = 1'b0; star_key = 1'b1; end
            default: digit_valid = 1'b0;
        endcase
    end

    assign locked = fail_count >= MAX_FAILS;
    assign key_ready = entry_enable && !session_busy && !locked;
    assign key_fire = key_valid && key_ready;
    assign beep_event = (key_fire && (digit_valid || star_key)) | unused_pin_upper;
    assign submit_event = key_fire && digit_valid && (digit_count == DIGIT_LAST);
    assign pin_rejected = submit_event && !pin_matches;

    // The volatile demo fail counter belongs only to the cold-reset domain.
    always @(posedge clk or negedge cold_rst_n) begin
        if (!cold_rst_n) begin
            fail_count <= {FAIL_W{1'b0}};
        end else if (submit_event && !pin_matches) begin
            if (fail_count < MAX_FAILS)
                fail_count <= fail_count + 1'b1;
        end
    end

    // PIN entry and transaction context belong to the session-reset domain.
    always @(posedge clk or negedge session_rst_n) begin
        if (!session_rst_n) begin
            pin_shift    <= 32'b0;
            digit_count  <= {DIGIT_W{1'b0}};
            txn_valid    <= 1'b0;
            session_busy <= 1'b0;
        end else if (session_end) begin
            pin_shift    <= 32'b0;
            digit_count  <= {DIGIT_W{1'b0}};
            txn_valid    <= 1'b0;
            session_busy <= 1'b0;
        end else begin
            if (txn_valid && txn_ready)
                txn_valid <= 1'b0;

            if (key_fire) begin
                if (star_key) begin
                    pin_shift   <= 32'b0;
                    digit_count <= {DIGIT_W{1'b0}};
                end else if (digit_valid) begin
                    if (digit_count == DIGIT_LAST) begin
                        txn_valid    <= pin_matches;
                        session_busy <= pin_matches;
                        pin_shift    <= 32'b0;
                        digit_count  <= {DIGIT_W{1'b0}};
                    end else begin
                        pin_shift   <= next_pin;
                        digit_count <= digit_count + 1'b1;
                    end
                end
            end
        end
    end

`ifdef FORMAL
    reg f_past_valid;
    reg f_prev_cold;
    reg [FAIL_W-1:0] f_prev_fail_count;
    reg f_prev_submit_bad;
    reg f_prev_txn_stall;
    always @(posedge clk) begin
        if (!cold_rst_n) begin
            f_past_valid <= 1'b0;
        end else begin
            f_past_valid <= 1'b1;
            f_prev_cold <= cold_rst_n;
            f_prev_fail_count <= fail_count;
            f_prev_submit_bad <= submit_event && !pin_matches;
            f_prev_txn_stall <= txn_valid && !txn_ready && session_rst_n && !session_end;
        end
    end
    always @* begin
        if (f_past_valid) begin
            assert(fail_count <= MAX_FAILS);                          // F-01
            if (locked) assert(!key_ready);                           // F-03
            if (f_prev_cold && cold_rst_n) begin
                assert(fail_count >= f_prev_fail_count);              // F-01/F-10
                if (fail_count > f_prev_fail_count)
                    assert(f_prev_submit_bad);                        // F-02
                if (f_prev_txn_stall && session_rst_n && !session_end) begin
                    assert(txn_valid);                                // F-06
                end
            end
        end
    end
`endif
endmodule

`default_nettype wire
