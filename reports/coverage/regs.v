//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module regs #(
            parameter PIN_LEN = 4,
            parameter [31:0] PIN_VALUE = 32'h00001234,
            parameter MAX_FAILS = 3
        ) (
 1227568     input  wire         clk,
 000011     input  wire         cold_rst_n,
 000049     input  wire         session_rst_n,
 000005     input  wire         entry_enable,
 000096     input  wire         key_valid,
 000010     output wire         key_ready,
~000030     input  wire [3:0]   key_id,
 000008     output reg          txn_valid,
 000010     input  wire         txn_ready,
 000010     input  wire         session_end,
~000002     output wire         locked,
 000082     output wire         beep_event,
 000022     output wire         submit_event,
 000020     output wire         pin_rejected
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
        
%000000     function bcd_is_valid;
                input [31:0] value;
                integer index;
%000000         begin
%000000             bcd_is_valid = 1'b1;
%000000             for (index = 0; index < PIN_LEN; index = index + 1)
%000000                 if (((value >> (index * 4)) & 32'h0000000f) > 9)
%000000                     bcd_is_valid = 1'b0;
                end
            endfunction
        
            localparam integer DIGIT_W = width_for(PIN_LEN - 1);
            localparam integer FAIL_W  = width_for(MAX_FAILS);
            // DIGIT_W is derived from PIN_LEN, so this elaboration-time truncation is exact.
            /* verilator lint_off WIDTHTRUNC */
            localparam [DIGIT_W-1:0] DIGIT_LAST = PIN_LEN - 1;
            /* verilator lint_on WIDTHTRUNC */
            localparam PIN_BCD_VALID = bcd_is_valid(PIN_VALUE);
        
~000036     reg [31:0] pin_shift;
 000048     reg [DIGIT_W-1:0] digit_count;
~000008     reg [FAIL_W-1:0] fail_count;
 000008     reg session_busy;
%000000     wire unused_pin_upper = &{1'b0, pin_shift[31:28]};
        
 000015     reg digit_valid;
~000010     reg star_key;
~000035     reg [3:0] digit;
 000092     wire key_fire;
~000036     wire [31:0] next_pin = {pin_shift[27:0], digit};
 000008     wire pin_matches = next_pin[(PIN_LEN*4)-1:0] == PIN_VALUE[(PIN_LEN*4)-1:0];
        
            generate
                if ((PIN_LEN < 1) || (PIN_LEN > 8) || (MAX_FAILS < 1)
                    || !PIN_BCD_VALID) begin : g_invalid_regs
                    INVALID_REGS_CONFIGURATION invalid_configuration();
                end
            endgenerate
        
 613786     always @* begin
 613786         digit_valid = 1'b1;
 613786         star_key = 1'b0;
 613786         digit = 4'd0;
 613786         case (key_id)
 221024             4'd0:  digit = 4'd1;
 134000             4'd1:  digit = 4'd2;
 134000             4'd2:  digit = 4'd3;
 083761             4'd4:  digit = 4'd4;
 041001             4'd5:  digit = 4'd5;
~000896             4'd6:  digit = 4'd6;
~000020             4'd8:  digit = 4'd7;
~000020             4'd9:  digit = 4'd8;
~000200             4'd10: digit = 4'd9;
~000020             4'd13: digit = 4'd0;
~000704             4'd12: begin digit_valid = 1'b0; star_key = 1'b1; end
~000125             default: digit_valid = 1'b0;
                endcase
            end
        
            assign locked = fail_count >= MAX_FAILS;
            assign key_ready = entry_enable && !session_busy && !locked;
            assign key_fire = key_valid && key_ready;
            assign beep_event = (key_fire && (digit_valid || star_key)) | unused_pin_upper;
            assign submit_event = key_fire && digit_valid && (digit_count == DIGIT_LAST);
            assign pin_rejected = submit_event && !pin_matches;
        
            // The volatile demo fail counter belongs only to the cold-reset domain.
 613784     always @(posedge clk or negedge cold_rst_n) begin
 000012         if (!cold_rst_n) begin
 000012             fail_count <= {FAIL_W{1'b0}};
 613777         end else if (submit_event && !pin_matches) begin
~000004             if (fail_count < MAX_FAILS)
 000004                 fail_count <= fail_count + 1'b1;
                end
            end
        
            // PIN entry and transaction context belong to the session-reset domain.
 613785     always @(posedge clk or negedge session_rst_n) begin
 000026         if (!session_rst_n) begin
 000026             pin_shift    <= 32'b0;
 000026             digit_count  <= {DIGIT_W{1'b0}};
 000026             txn_valid    <= 1'b0;
 000026             session_busy <= 1'b0;
 613777         end else if (session_end) begin
 000005             pin_shift    <= 32'b0;
 000005             digit_count  <= {DIGIT_W{1'b0}};
 000005             txn_valid    <= 1'b0;
 000005             session_busy <= 1'b0;
 613777         end else begin
 613776             if (txn_valid && txn_ready)
 000004                 txn_valid <= 1'b0;
        
 613769             if (key_fire) begin
~000005                 if (star_key) begin
~000005                     pin_shift   <= 32'b0;
~000005                     digit_count <= {DIGIT_W{1'b0}};
~000036                 end else if (digit_valid) begin
 000031                     if (digit_count == DIGIT_LAST) begin
 000007                         txn_valid    <= pin_matches;
 000007                         session_busy <= pin_matches;
 000007                         pin_shift    <= 32'b0;
 000007                         digit_count  <= {DIGIT_W{1'b0}};
 000031                     end else begin
 000031                         pin_shift   <= next_pin;
 000031                         digit_count <= digit_count + 1'b1;
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
        
