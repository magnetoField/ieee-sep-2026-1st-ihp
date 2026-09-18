`timescale 1ns/1ps
`default_nettype none

// Single-key, bit-serial SIMON64/128 area variant. The 44 round-key words
// are elaboration-time constants derived from KEY. Sparse
// checkpoints plus a serial XOR accumulator reconstruct omitted key words.
// Full 44 rounds take 9344 cycles; no runtime 128-bit key schedule is stored.
module szymon_fixed #(
    parameter [127:0] KEY = 128'hba2a1918131211100b0a090803020100
) (
    input  wire clk,
    input  wire rst_n,
    input  wire abort,

    input  wire cmd_valid,
    output wire cmd_ready,

    input  wire s_valid,
    output wire s_ready,
    input  wire s_bit,

    input  wire seal_valid,
    output wire seal_ready,

    output wire m_valid,
    input  wire m_ready,
    output wire m_bit,
    output wire m_last
);
    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_LOAD      = 3'd1;
    localparam [2:0] ST_WAIT_SEAL = 3'd2;
    localparam [2:0] ST_CRYPT     = 3'd3;
    localparam [2:0] ST_OUTPUT    = 3'd4;
    localparam [2:0] ST_WIPE = 3'd5;
    localparam [63:0] Z3 = 64'hfc2ce51207a635db;

    function [1407:0] expand_key;
        input [127:0] key;
        reg [1407:0] words;
        reg [31:0] previous;
        reg [31:0] previous_three;
        reg [31:0] previous_four;
        reg [31:0] temporary;
        integer index;
        begin
            words = {1408{1'b0}};
            words[127:0] = key;
            for (index = 4; index < 44; index = index + 1) begin
                previous = words[((index - 1) * 32) +: 32];
                previous_three = words[((index - 3) * 32) +: 32];
                previous_four = words[((index - 4) * 32) +: 32];
                temporary = {previous[2:0], previous[31:3]} ^ previous_three;
                words[(index * 32) +: 32] = 32'hfffffffc ^ previous_four
                    ^ temporary ^ {temporary[0], temporary[31:1]}
                    ^ {31'b0, Z3[index - 4]};
            end
            expand_key = words;
        end
    endfunction

    localparam [1407:0] ROUND_KEYS = expand_key(KEY);

    reg [2:0] state;
    reg [31:0] a;
    reg [31:0] b;
    reg [5:0] bit_count;
    reg [5:0] round_count;

    function [1407:0] sparse_keys;
        input [1407:0] words;
        integer r;
        begin
            sparse_keys = words;
            for (r = 4; r < 44; r = r + 1)
                if ((r % 2 == 0) && (r % 32 >= 4))
                    sparse_keys[r*32 +: 32] = {32{1'bx}};
        end
    endfunction
    localparam [1407:0] SPARSE_KEYS = sparse_keys(ROUND_KEYS);
    reg [1:0] key_phase;
    reg [2:0] key_depth;
    reg key_accumulator;
    wire [5:0] work_round = round_count - {1'b0, key_depth, 2'b0};
    wire reconstruct = !work_round[0] && (work_round[4:2] != 3'b0);
    wire key_ready = !reconstruct;
    wire [5:0] lookup_round = reconstruct
        ? work_round - (key_phase[1] ? 6'd3 : 6'd1) : work_round;
    reg [4:0] bit_offset;
    always @* begin
        case (key_phase)
            2'd0: bit_offset = 5'd3;
            2'd1: bit_offset = 5'd4;
            2'd2: bit_offset = 5'd0;
            default: bit_offset = 5'd1;
        endcase
    end
    wire [4:0] lookup_bit = ~bit_count[4:0]
        + (reconstruct ? bit_offset : 5'b0);
    wire [10:0] round_bit_index = {lookup_round, lookup_bit};
    wire lookup_value = SPARSE_KEYS[round_bit_index];
    wire round_key_bit = lookup_value ^ key_accumulator;
    localparam [31:0] RECONSTRUCT_Z = 32'bxxxxxxxxxx0100xx11001001111101xx;
    wire key_constant = (bit_count[4:0] < 5'd30)
        ^ ((bit_count[4:0] == 5'd31) & RECONSTRUCT_Z[work_round[5:1]]);
    // Internal key work is hidden while reset is asserted, like a/b below.
    /* verilator lint_off SYNCASYNCNET */
    always @(posedge clk) begin
        if (!rst_n || abort || state != ST_CRYPT || key_ready) begin
            key_phase <= 2'b0;
            key_depth <= 3'b0;
            key_accumulator <= 1'b0;
        end else begin
            key_phase <= key_phase + 1'b1;
            if (key_phase == 2'd3)
                key_depth <= key_depth + 1'b1;
            key_accumulator <= key_accumulator ^ lookup_value
                ^ ((key_phase == 2'd0) & key_constant);
        end
    end
    /* verilator lint_on SYNCASYNCNET */
    wire even_round = ~round_count[0];
    wire data_feedback_even = (a[30] & a[23]) ^ a[29] ^ b[31]
        ^ round_key_bit;
    wire data_feedback_odd = (b[30] & b[23]) ^ b[29] ^ a[31]
        ^ round_key_bit;

    assign cmd_ready  = (state == ST_IDLE);
    assign s_ready    = (state == ST_LOAD);
    assign seal_ready = (state == ST_WAIT_SEAL);
    assign m_valid    = (state == ST_OUTPUT);
    assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;
    assign m_last     = (state == ST_OUTPUT) && (bit_count == 6'd63);


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_WIPE;
            bit_count   <= 6'b0;
            round_count <= 6'b0;
        end else if (abort) begin
            state       <= ST_WIPE;
            bit_count   <= 6'b0;
            round_count <= 6'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    bit_count   <= 6'b0;
                    round_count <= 6'b0;
                    if (cmd_valid && cmd_ready) begin
                        state      <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    if (s_valid && s_ready) begin
                        if (bit_count == 6'd63) begin
                            bit_count <= 6'b0;
                            state     <= ST_WAIT_SEAL;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                ST_WAIT_SEAL: begin
                    if (seal_valid && seal_ready) begin
                        bit_count   <= 6'b0;
                        round_count <= 6'b0;
                        state       <= ST_CRYPT;
                    end
                end

                ST_CRYPT: if (key_ready) begin
                    if (bit_count == 6'd31) begin
                        bit_count <= 6'b0;
                        if (round_count == 6'd43) begin
                            round_count <= 6'b0;
                            state       <= ST_OUTPUT;
                        end else begin
                            round_count <= round_count + 1'b1;
                        end
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                ST_OUTPUT: begin
                    if (m_valid && m_ready) begin
                        if (bit_count == 6'd63) begin
                            state       <= ST_IDLE;
                            bit_count   <= 6'b0;
                            round_count <= 6'b0;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                ST_WIPE: begin
                    if (bit_count == 6'd63) begin
                        state <= ST_IDLE;
                        bit_count <= 6'b0;
                    end else bit_count <= bit_count + 1'b1;
                end
                default: begin
                    state       <= ST_WIPE;
                    bit_count   <= 6'b0;
                    round_count <= 6'b0;
                end
            endcase
        end
    end

    // The interface/control state above retains asynchronous reset so every
    // valid/ready output becomes safe immediately. The 64-bit shared data
    // register is not externally observable during reset or the 64-clock wipe.
    // No new command is accepted until the serial erase has completed.
    /* verilator lint_off SYNCASYNCNET */
    wire crypt_step = (state == ST_CRYPT) && key_ready;
    wire load_step = (state == ST_LOAD) && s_valid;
    wire output_step = (state == ST_OUTPUT) && m_ready;
    wire shift_data = crypt_step || load_step || output_step;
    wire a_input = crypt_step
        ? (even_round ? a[31] : data_feedback_odd) : b[31];
    wire b_input = crypt_step
        ? (even_round ? data_feedback_even : b[31]) : (load_step && s_bit);
    // Serial wipe takes 64 clocks with every ready/valid output blocked.
    always @(posedge clk) begin
        if (state == ST_WIPE) begin
            a <= {a[30:0], b[31]};
            b <= {b[30:0], 1'b0};
        end else if (shift_data) begin
            a <= {a[30:0], a_input};
            b <= {b[30:0], b_input};
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
