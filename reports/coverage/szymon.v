//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        // Bit-serial SIMON64/128 core. The 64-bit A/B state is shared by RX, rounds,
        // and TX; there is no separate plaintext or ciphertext buffer.
        module szymon (
 079693     input  wire         clk,
 000049     input  wire         rst_n,
 000048     input  wire         abort,
        
 000098     input  wire         cmd_valid,
 000097     output wire         cmd_ready,
 000096     input  wire [127:0] cmd_key,
        
 006144     input  wire         s_valid,
 000096     output wire         s_ready,
 001821     input  wire         s_bit,
        
 000094     input  wire         seal_valid,
 000096     output wire         seal_ready,
        
 000004     output wire         m_valid,
%000000     input  wire         m_ready,
%000000     output wire         m_bit,
%000000     output wire         m_last
        );
        
            localparam [2:0] ST_IDLE      = 3'd0;
            localparam [2:0] ST_LOAD      = 3'd1;
            localparam [2:0] ST_WAIT_SEAL = 3'd2;
            localparam [2:0] ST_CRYPT     = 3'd3;
            localparam [2:0] ST_OUTPUT    = 3'd4;
            localparam [63:0] Z3 = 64'hfc2ce51207a635db;
        
 000188     reg [2:0] state;
 018622     reg [31:0] a;
 016906     reg [31:0] b;
 016428     reg [31:0] k0;
 016482     reg [31:0] k1;
 016508     reg [31:0] k2;
 016520     reg [31:0] k3;
 036512     reg [5:0] bit_count;
 001056     reg [5:0] round_count;
        
 001057     wire even_round = ~round_count[0];
 018706     wire data_feedback_even = (a[31] & a[24]) ^ a[30] ^ b[0] ^ k0[0];
 017678     wire data_feedback_odd  = (b[31] & b[24]) ^ b[30] ^ a[0] ^ k0[0];
 000013     wire generate_key = round_count < 6'd40;
 016163     wire key_feedback = generate_key
                ? (k0[0] ^ k3[3] ^ k3[4] ^ k1[0] ^ k1[1]
                   ^ (bit_count >= 6'd2)
                   ^ ((bit_count == 6'd0) & Z3[round_count]))
                : 1'b0;
 016428     wire [31:0] k0_shifted = {key_feedback, k0[31:1]};
 016482     wire [31:0] k1_rotated = {k1[0], k1[31:1]};
 016508     wire [31:0] k2_rotated = {k2[0], k2[31:1]};
 016520     wire [31:0] k3_rotated = {k3[0], k3[31:1]};
        
            assign cmd_ready  = (state == ST_IDLE);
            assign s_ready    = (state == ST_LOAD);
            assign seal_ready = (state == ST_WAIT_SEAL);
            assign m_valid    = (state == ST_OUTPUT);
            assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;
            assign m_last     = (state == ST_OUTPUT) && (bit_count == 6'd63);
        
 039871     always @(posedge clk or negedge rst_n) begin
 000051         if (!rst_n) begin
 000051             state       <= ST_IDLE;
 000051             a           <= 32'b0;
 000051             b           <= 32'b0;
 000051             k0          <= 32'b0;
 000051             k1          <= 32'b0;
 000051             k2          <= 32'b0;
 000051             k3          <= 32'b0;
 000051             bit_count   <= 6'b0;
 000051             round_count <= 6'b0;
 039796         end else if (abort) begin
 000024             state       <= ST_IDLE;
 000024             a           <= 32'b0;
 000024             b           <= 32'b0;
 000024             k0          <= 32'b0;
 000024             k1          <= 32'b0;
 000024             k2          <= 32'b0;
 000024             k3          <= 32'b0;
 000024             bit_count   <= 6'b0;
 000024             round_count <= 6'b0;
 039796         end else begin
 039796             case (state)
 000146                 ST_IDLE: begin
 000146                     a           <= 32'b0;
 000146                     b           <= 32'b0;
 000146                     bit_count   <= 6'b0;
 000146                     round_count <= 6'b0;
 000098                     if (cmd_valid && cmd_ready) begin
 000048                         k0    <= cmd_key[31:0];
 000048                         k1    <= cmd_key[63:32];
 000048                         k2    <= cmd_key[95:64];
 000048                         k3    <= cmd_key[127:96];
 000048                         state <= ST_LOAD;
 000098                     end else begin
 000098                         k0 <= 32'b0;
 000098                         k1 <= 32'b0;
 000098                         k2 <= 32'b0;
 000098                         k3 <= 32'b0;
                            end
                        end
        
 006148                 ST_LOAD: begin
 003076                     if (s_valid && s_ready) begin
 003072                         a <= {a[30:0], b[31]};
 003072                         b <= {b[30:0], s_bit};
 003024                         if (bit_count == 6'd63) begin
 000048                             bit_count <= 6'b0;
 000048                             state     <= ST_WAIT_SEAL;
 003024                         end else begin
 003024                             bit_count <= bit_count + 1'b1;
                                end
                            end
                        end
        
 000103                 ST_WAIT_SEAL: begin
 000057                     if (seal_valid && seal_ready) begin
 000046                         bit_count   <= 6'b0;
 000046                         round_count <= 6'b0;
 000046                         state       <= ST_CRYPT;
                            end
                        end
        
 033396                 ST_CRYPT: begin
 017050                     if (even_round) begin
 017050                         a <= {a[0], a[31:1]};
 017050                         b <= {data_feedback_even, b[31:1]};
 016346                     end else begin
 016346                         b <= {b[0], b[31:1]};
 016346                         a <= {data_feedback_odd, a[31:1]};
                            end
        
 032362                     if (bit_count == 6'd31) begin
 001034                         k0        <= k1_rotated;
 001034                         k1        <= k2_rotated;
 001034                         k2        <= k3_rotated;
 001034                         k3        <= k0_shifted;
 001034                         bit_count <= 6'b0;
 001032                         if (round_count == 6'd43) begin
 000002                             round_count <= 6'b0;
 000002                             state       <= ST_OUTPUT;
 001032                         end else begin
 001032                             round_count <= round_count + 1'b1;
                                end
 032362                     end else begin
 032362                         k0        <= k0_shifted;
 032362                         k1        <= k1_rotated;
 032362                         k2        <= k2_rotated;
 032362                         k3        <= k3_rotated;
 032362                         bit_count <= bit_count + 1'b1;
                            end
                        end
        
 000003                 ST_OUTPUT: begin
~000003                     if (m_valid && m_ready) begin
%000000                         a <= {a[30:0], b[31]};
%000000                         b <= {b[30:0], 1'b0};
%000000                         if (bit_count == 6'd63) begin
%000000                             state       <= ST_IDLE;
%000000                             a           <= 32'b0;
%000000                             b           <= 32'b0;
%000000                             k0          <= 32'b0;
%000000                             k1          <= 32'b0;
%000000                             k2          <= 32'b0;
%000000                             k3          <= 32'b0;
%000000                             bit_count   <= 6'b0;
%000000                             round_count <= 6'b0;
%000000                         end else begin
%000000                             bit_count <= bit_count + 1'b1;
                                end
                            end
                        end
        
%000000                 default: begin
%000000                     state       <= ST_IDLE;
%000000                     a           <= 32'b0;
%000000                     b           <= 32'b0;
%000000                     k0          <= 32'b0;
%000000                     k1          <= 32'b0;
%000000                     k2          <= 32'b0;
%000000                     k3          <= 32'b0;
%000000                     bit_count   <= 6'b0;
%000000                     round_count <= 6'b0;
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
        
