`timescale 1ns/1ps
`default_nettype none

// Bit-serial SIMON64/128 core. The 64-bit A/B state is shared by RX, rounds,
// and TX; there is no separate plaintext or ciphertext buffer.
module szymon (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         abort,

    input  wire         cmd_valid,
    output wire         cmd_ready,
    input  wire [127:0] cmd_key,

    input  wire         s_valid,
    output wire         s_ready,
    input  wire         s_bit,

    input  wire         seal_valid,
    output wire         seal_ready,

    output wire         m_valid,
    input  wire         m_ready,
    output wire         m_bit,
    output wire         m_last
);

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_LOAD      = 3'd1;
    localparam [2:0] ST_WAIT_SEAL = 3'd2;
    localparam [2:0] ST_CRYPT     = 3'd3;
    localparam [2:0] ST_OUTPUT    = 3'd4;
    localparam [63:0] Z3 = 64'hfc2ce51207a635db;

    reg [2:0] state;
    reg [31:0] a;
    reg [31:0] b;
    reg [31:0] k0;
    reg [31:0] k1;
    reg [31:0] k2;
    reg [31:0] k3;
    reg [5:0] bit_count;
    reg [5:0] round_count;

    wire even_round = ~round_count[0];
    wire data_feedback_even = (a[31] & a[24]) ^ a[30] ^ b[0] ^ k0[0];
    wire data_feedback_odd  = (b[31] & b[24]) ^ b[30] ^ a[0] ^ k0[0];
    wire generate_key = round_count < 6'd40;
    wire key_feedback = generate_key
        ? (k0[0] ^ k3[3] ^ k3[4] ^ k1[0] ^ k1[1]
           ^ (bit_count >= 6'd2)
           ^ ((bit_count == 6'd0) & Z3[round_count]))
        : 1'b0;
    wire [31:0] k0_shifted = {key_feedback, k0[31:1]};
    wire [31:0] k1_rotated = {k1[0], k1[31:1]};
    wire [31:0] k2_rotated = {k2[0], k2[31:1]};
    wire [31:0] k3_rotated = {k3[0], k3[31:1]};

    assign cmd_ready  = (state == ST_IDLE);
    assign s_ready    = (state == ST_LOAD);
    assign seal_ready = (state == ST_WAIT_SEAL);
    assign m_valid    = (state == ST_OUTPUT);
    assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;
    assign m_last     = (state == ST_OUTPUT) && (bit_count == 6'd63);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            a           <= 32'b0;
            b           <= 32'b0;
            k0          <= 32'b0;
            k1          <= 32'b0;
            k2          <= 32'b0;
            k3          <= 32'b0;
            bit_count   <= 6'b0;
            round_count <= 6'b0;
        end else if (abort) begin
            state       <= ST_IDLE;
            a           <= 32'b0;
            b           <= 32'b0;
            k0          <= 32'b0;
            k1          <= 32'b0;
            k2          <= 32'b0;
            k3          <= 32'b0;
            bit_count   <= 6'b0;
            round_count <= 6'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    a           <= 32'b0;
                    b           <= 32'b0;
                    bit_count   <= 6'b0;
                    round_count <= 6'b0;
                    if (cmd_valid && cmd_ready) begin
                        k0    <= cmd_key[31:0];
                        k1    <= cmd_key[63:32];
                        k2    <= cmd_key[95:64];
                        k3    <= cmd_key[127:96];
                        state <= ST_LOAD;
                    end else begin
                        k0 <= 32'b0;
                        k1 <= 32'b0;
                        k2 <= 32'b0;
                        k3 <= 32'b0;
                    end
                end

                ST_LOAD: begin
                    if (s_valid && s_ready) begin
                        a <= {a[30:0], b[31]};
                        b <= {b[30:0], s_bit};
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

                ST_CRYPT: begin
                    if (even_round) begin
                        a <= {a[0], a[31:1]};
                        b <= {data_feedback_even, b[31:1]};
                    end else begin
                        b <= {b[0], b[31:1]};
                        a <= {data_feedback_odd, a[31:1]};
                    end

                    if (bit_count == 6'd31) begin
                        k0        <= k1_rotated;
                        k1        <= k2_rotated;
                        k2        <= k3_rotated;
                        k3        <= k0_shifted;
                        bit_count <= 6'b0;
                        if (round_count == 6'd43) begin
                            round_count <= 6'b0;
                            state       <= ST_OUTPUT;
                        end else begin
                            round_count <= round_count + 1'b1;
                        end
                    end else begin
                        k0        <= k0_shifted;
                        k1        <= k1_rotated;
                        k2        <= k2_rotated;
                        k3        <= k3_rotated;
                        bit_count <= bit_count + 1'b1;
                    end
                end

                ST_OUTPUT: begin
                    if (m_valid && m_ready) begin
                        a <= {a[30:0], b[31]};
                        b <= {b[30:0], 1'b0};
                        if (bit_count == 6'd63) begin
                            state       <= ST_IDLE;
                            a           <= 32'b0;
                            b           <= 32'b0;
                            k0          <= 32'b0;
                            k1          <= 32'b0;
                            k2          <= 32'b0;
                            k3          <= 32'b0;
                            bit_count   <= 6'b0;
                            round_count <= 6'b0;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end

                default: begin
                    state       <= ST_IDLE;
                    a           <= 32'b0;
                    b           <= 32'b0;
                    k0          <= 32'b0;
                    k1          <= 32'b0;
                    k2          <= 32'b0;
                    k3          <= 32'b0;
                    bit_count   <= 6'b0;
                    round_count <= 6'b0;
                end
            endcase
        end
    end

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
            assert(state <= ST_OUTPUT);
            assert(bit_count <= 6'd63);
            assert(round_count <= 6'd43);
            if (f_prev_m_stall && rst_n && !abort) begin
                assert(m_valid);                                     // F-06
                assert(m_bit == f_prev_m_bit);
                assert(m_last == f_prev_m_last);
            end
            assert(!m_valid || (state == ST_OUTPUT));
        end
    end
`endif

endmodule

`default_nettype wire
