//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        // Single-key, bit-serial SIMON64/128 area variant. The 44 round-key words
        // are elaboration-time constants derived from KEY. Sparse
        // checkpoints plus a serial XOR accumulator reconstruct omitted key words.
        // Full 44 rounds take 9344 cycles; no runtime 128-bit key schedule is stored.
        module szymon_fixed #(
            parameter [127:0] KEY = 128'hba2a1918131211100b0a090803020100
        ) (
 1227568     input  wire clk,
 000005     input  wire rst_n,
 000058     input  wire abort,
        
 000066     input  wire cmd_valid,
 000067     output wire cmd_ready,
        
 000382     input  wire s_valid,
 000064     output wire s_ready,
 000110     input  wire s_bit,
        
 000060     input  wire seal_valid,
 000060     output wire seal_ready,
        
 000004     output wire m_valid,
 000256     input  wire m_ready,
 000070     output wire m_bit,
 000004     output wire m_last
        );
            localparam [2:0] ST_IDLE      = 3'd0;
            localparam [2:0] ST_LOAD      = 3'd1;
            localparam [2:0] ST_WAIT_SEAL = 3'd2;
            localparam [2:0] ST_CRYPT     = 3'd3;
            localparam [2:0] ST_OUTPUT    = 3'd4;
            localparam [2:0] ST_WIPE = 3'd5;
            localparam [63:0] Z3 = 64'hfc2ce51207a635db;
        
%000000     function [1407:0] expand_key;
                input [127:0] key;
                reg [1407:0] words;
                reg [31:0] previous;
                reg [31:0] previous_three;
                reg [31:0] previous_four;
                reg [31:0] temporary;
                integer index;
%000000         begin
%000000             words = {1408{1'b0}};
%000000             words[127:0] = key;
%000000             for (index = 4; index < 44; index = index + 1) begin
%000000                 previous = words[((index - 1) * 32) +: 32];
%000000                 previous_three = words[((index - 3) * 32) +: 32];
%000000                 previous_four = words[((index - 4) * 32) +: 32];
%000000                 temporary = {previous[2:0], previous[31:3]} ^ previous_three;
%000000                 words[(index * 32) +: 32] = 32'hfffffffc ^ previous_four
%000000                     ^ temporary ^ {temporary[0], temporary[31:1]}
%000000                     ^ {31'b0, Z3[index - 4]};
                    end
%000000             expand_key = words;
                end
            endfunction
        
            localparam [1407:0] ROUND_KEYS = expand_key(KEY);
        
 000126     reg [2:0] state;
 013992     reg [31:0] a;
 013512     reg [31:0] b;
 031948     reg [5:0] bit_count;
 000872     reg [5:0] round_count;
        
%000000     function [1407:0] sparse_keys;
                input [1407:0] words;
                integer r;
%000000         begin
%000000             sparse_keys = words;
%000000             for (r = 4; r < 44; r = r + 1)
%000000                 if ((r % 2 == 0) && (r % 32 >= 4))
%000000                     sparse_keys[r*32 +: 32] = {32{1'bx}};
                end
            endfunction
            localparam [1407:0] SPARSE_KEYS = sparse_keys(ROUND_KEYS);
 166792     reg [1:0] key_phase;
 047712     reg [2:0] key_depth;
 085032     reg key_accumulator;
 047932     wire [5:0] work_round = round_count - {1'b0, key_depth, 2'b0};
 023864     wire reconstruct = !work_round[0] && (work_round[4:2] != 3'b0);
 023865     wire key_ready = !reconstruct;
 083060     wire [5:0] lookup_round = reconstruct
                ? work_round - (key_phase[1] ? 6'd3 : 6'd1) : work_round;
~083411     reg [4:0] bit_offset;
 613785     always @* begin
 613785         case (key_phase)
 607833             2'd0: bit_offset = 5'd3;
 041705             2'd1: bit_offset = 5'd4;
 041698             2'd2: bit_offset = 5'd0;
 041691             default: bit_offset = 5'd1;
                endcase
            end
 115331     wire [4:0] lookup_bit = ~bit_count[4:0]
                + (reconstruct ? bit_offset : 5'b0);
 115331     wire [10:0] round_bit_index = {lookup_round, lookup_bit};
 102292     wire lookup_value = SPARSE_KEYS[round_bit_index];
 089144     wire round_key_bit = lookup_value ^ key_accumulator;
            localparam [31:0] RECONSTRUCT_Z = 32'bxxxxxxxxxx0100xx11001001111101xx;
 002801     wire key_constant = (bit_count[4:0] < 5'd30)
                ^ ((bit_count[4:0] == 5'd31) & RECONSTRUCT_Z[work_round[5:1]]);
            // Internal key work is hidden while reset is asserted, like a/b below.
            /* verilator lint_off SYNCASYNCNET */
 613784     always @(posedge clk) begin
 605848         if (!rst_n || abort || state != ST_CRYPT || key_ready) begin
 605848             key_phase <= 2'b0;
 605848             key_depth <= 3'b0;
 605848             key_accumulator <= 1'b0;
 166778         end else begin
 166778             key_phase <= key_phase + 1'b1;
 125094             if (key_phase == 2'd3)
 041684                 key_depth <= key_depth + 1'b1;
 166778             key_accumulator <= key_accumulator ^ lookup_value
 166778                 ^ ((key_phase == 2'd0) & key_constant);
                end
            end
            /* verilator lint_on SYNCASYNCNET */
 000873     wire even_round = ~round_count[0];
 090126     wire data_feedback_even = (a[30] & a[23]) ^ a[29] ^ b[31]
                ^ round_key_bit;
 089482     wire data_feedback_odd = (b[30] & b[23]) ^ b[29] ^ a[31]
                ^ round_key_bit;
        
            assign cmd_ready  = (state == ST_IDLE);
            assign s_ready    = (state == ST_LOAD);
            assign seal_ready = (state == ST_WAIT_SEAL);
            assign m_valid    = (state == ST_OUTPUT);
            assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;
            assign m_last     = (state == ST_OUTPUT) && (bit_count == 6'd63);
        
        
 613785     always @(posedge clk or negedge rst_n) begin
 000015         if (!rst_n) begin
 000015             state       <= ST_WIPE;
 000015             bit_count   <= 6'b0;
 000015             round_count <= 6'b0;
 613777         end else if (abort) begin
 000029             state       <= ST_WIPE;
 000029             bit_count   <= 6'b0;
 000029             round_count <= 6'b0;
 613777         end else begin
 613777             case (state)
 570972                 ST_IDLE: begin
 570972                     bit_count   <= 6'b0;
 570972                     round_count <= 6'b0;
 570971                     if (cmd_valid && cmd_ready) begin
 000032                         state      <= ST_LOAD;
                            end
                        end
        
 028837                 ST_LOAD: begin
 028773                     if (s_valid && s_ready) begin
 001900                         if (bit_count == 6'd63) begin
 000030                             bit_count <= 6'b0;
 000030                             state     <= ST_WAIT_SEAL;
 001900                         end else begin
 001900                             bit_count <= bit_count + 1'b1;
                                end
                            end
                        end
        
 000082                 ST_WAIT_SEAL: begin
~000080                     if (seal_valid && seal_ready) begin
 000030                         bit_count   <= 6'b0;
 000030                         round_count <= 6'b0;
 000030                         state       <= ST_CRYPT;
                            end
                        end
        
 194682                 ST_CRYPT: if (key_ready) begin
 027032                     if (bit_count == 6'd31) begin
 000872                         bit_count <= 6'b0;
 000870                         if (round_count == 6'd43) begin
 000002                             round_count <= 6'b0;
 000002                             state       <= ST_OUTPUT;
 000870                         end else begin
 000870                             round_count <= round_count + 1'b1;
                                end
 027032                     end else begin
 027032                         bit_count <= bit_count + 1'b1;
                            end
                        end
        
 008910                 ST_OUTPUT: begin
~008782                     if (m_valid && m_ready) begin
 000126                         if (bit_count == 6'd63) begin
 000002                             state       <= ST_IDLE;
 000002                             bit_count   <= 6'b0;
 000002                             round_count <= 6'b0;
 000126                         end else begin
 000126                             bit_count <= bit_count + 1'b1;
                                end
                            end
                        end
        
 001984                 ST_WIPE: begin
 001953                     if (bit_count == 6'd63) begin
 000031                         state <= ST_IDLE;
 000031                         bit_count <= 6'b0;
 001953                     end else bit_count <= bit_count + 1'b1;
                        end
%000000                 default: begin
%000000                     state       <= ST_WIPE;
%000000                     bit_count   <= 6'b0;
%000000                     round_count <= 6'b0;
                        end
                    endcase
                end
            end
        
            // The interface/control state above retains asynchronous reset so every
            // valid/ready output becomes safe immediately. The 64-bit shared data
            // register is not externally observable during reset or the 64-clock wipe.
            // No new command is accepted until the serial erase has completed.
            /* verilator lint_off SYNCASYNCNET */
 023868     wire crypt_step = (state == ST_CRYPT) && key_ready;
 000382     wire load_step = (state == ST_LOAD) && s_valid;
 000256     wire output_step = (state == ST_OUTPUT) && m_ready;
 023936     wire shift_data = crypt_step || load_step || output_step;
 019264     wire a_input = crypt_step
                ? (even_round ? a[31] : data_feedback_odd) : b[31];
 019940     wire b_input = crypt_step
                ? (even_round ? data_feedback_even : b[31]) : (load_step && s_bit);
            // Serial wipe takes 64 clocks with every ready/valid output blocked.
 613784     always @(posedge clk) begin
 001986         if (state == ST_WIPE) begin
 001986             a <= {a[30:0], b[31]};
 001986             b <= {b[30:0], 1'b0};
 612115         end else if (shift_data) begin
 029962             a <= {a[30:0], a_input};
 029962             b <= {b[30:0], b_input};
                end
            end
            /* verilator lint_on SYNCASYNCNET */
        
        `ifdef FORMAL
            reg f_past_valid;
            reg f_prev_m_stall;
            reg f_prev_m_bit;
            reg f_prev_m_last;
            always @(posedge clk) begin
                if (!rst_n) begin
                    f_past_valid <= 1'b0;
                end else begin
                    f_past_valid <= 1'b1;
                    f_prev_m_stall <= m_valid && !m_ready && !abort;
                    f_prev_m_bit <= m_bit;
                    f_prev_m_last <= m_last;
                end
            end
            always @* begin
                if (f_past_valid) begin
                    assert(state <= ST_WIPE);
                    assert(bit_count <= 6'd63);
                    assert(round_count <= 6'd43);
                    if (f_prev_m_stall && rst_n && !abort) begin
                        assert(m_valid);
                        assert(m_bit == f_prev_m_bit);
                        assert(m_last == f_prev_m_last);
                    end
                    assert(!m_valid || (state == ST_OUTPUT));
                end
            end
        `endif
        endmodule
        
        `default_nettype wire
        
