//      // verilator_coverage annotation
        `timescale 1ns/1ps
        `default_nettype none
        
        module tb_szymon_fixed #(
            parameter [127:0] TEST_KEY = 128'hba2a1918131211100b0a090803020100,
            parameter [63:0] EXPECT = 64'ha67ee743f2808f0f
        );
 397704     reg clk = 0;
 000003     reg rst_n = 0;
 000058     reg abort = 0;
 000066     reg cmd_valid = 0;
 000067     wire cmd_ready;
 000064     reg s_valid = 0;
 000064     wire s_ready;
 000075     reg s_bit = 0;
 000060     reg seal_valid = 0;
 000060     wire seal_ready;
 000004     wire m_valid;
 000004     reg m_ready = 0;
 000052     wire m_bit;
 000004     wire m_last;
            integer bit_index;
~000003     reg [63:0] observed;
            reg [1023:0] round_key_file;
            reg [63:0] expected_round_keys [0:43];
            integer abort_depth;
            integer abort_phase;
            integer wait_cycles;
 006186     reg [63:0] held_data;
        
            szymon_fixed #(.KEY(TEST_KEY)) dut (
                .clk(clk), .rst_n(rst_n), .abort(abort),
                .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
                .s_valid(s_valid), .s_ready(s_ready),
                .s_bit(s_bit), .seal_valid(seal_valid), .seal_ready(seal_ready),
                .m_valid(m_valid), .m_ready(m_ready), .m_bit(m_bit), .m_last(m_last)
            );
        
 397704     always #5 clk = ~clk;
        
 198852     always @(posedge clk) begin
 166778         if (rst_n && !abort && dut.state == 3'd3 && !dut.key_ready) begin
 166778             held_data = {dut.a, dut.b};
 166778             #1;
 166778             if ({dut.a, dut.b} !== held_data)
                        $fatal(1, "data changed during key-only cycle");
                end
            end
        
            // Check actually consumed bits against the independent model schedule.
 198852     always @(negedge clk) begin
 170948         if (rst_n && !abort && dut.state == 3'd3 && dut.key_ready) begin
 027904             if (dut.round_key_bit !== expected_round_keys[dut.round_count]
                            [63 - dut.bit_count])
                        $fatal(1, "consumed key mismatch round=%0d bit=%0d",
                            dut.round_count, dut.bit_count);
                end
            end
        
 000002     task automatic run_block(
                input [63:0] plaintext,
                input [63:0] expected
            );
                time seal_time;
 000002         begin
 000062             while (!cmd_ready) @(posedge clk);
 000002             @(negedge clk);
 000002             cmd_valid = 1'b1;
 000002             @(posedge clk);
 000002             @(negedge clk);
 000002             cmd_valid = 1'b0;
        
 000128             for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
 000128                 @(negedge clk);
 000128                 s_valid = 1'b1;
 000128                 s_bit = plaintext[bit_index];
 000128                 @(posedge clk);
                    end
 000002             @(negedge clk);
 000002             s_valid = 1'b0;
 000002             if (!seal_ready) $fatal(1, "fixed core did not accept 64 bits");
 000002             seal_valid = 1'b1;
 000002             @(posedge clk);
 000002             seal_time = $time;
 000002             @(negedge clk);
 000002             seal_valid = 1'b0;
        
 000002             @(posedge m_valid);
 000002             if (($time - seal_time) != 93440)
                        $fatal(1, "fixed core latency was not 9344 cycles");
        
 000002             observed = 64'b0;
 000128             for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
 000128                 @(negedge clk);
 000128                 if (!m_valid || (m_last !== (bit_index == 0)))
                            $fatal(1, "fixed core output framing bit %0d", bit_index);
 000128                 observed[bit_index] = m_bit;
 000128                 m_ready = 1'b1;
 000128                 @(posedge clk);
                    end
 000002             @(negedge clk);
 000002             m_ready = 1'b0;
 000002             if (observed !== expected)
                        $fatal(1, "fixed core mismatch got=%h expected=%h", observed, expected);
 000002             if (!cmd_ready || {dut.a, dut.b} !== 64'b0)
                        $fatal(1, "fixed core did not erase/rearm");
                end
            endtask
        
 000030     task await_wipe;
                integer w;
 000030         begin
 000030             if (m_valid || m_bit !== 1'b0 || s_ready || seal_ready || cmd_ready)
                        $fatal(1, "interface not blocked on serial wipe entry");
 001890             for (w=1; w<64; w=w+1) begin
 001890                 @(negedge clk);
 001890                 if (m_valid || m_bit !== 1'b0 || s_ready || seal_ready || cmd_ready)
                            $fatal(1, "serial wipe finished early");
                    end
 000030             @(negedge clk);
 000030             if (!cmd_ready || {dut.a,dut.b} !== 64'b0)
                        $fatal(1, "serial wipe did not erase after 64 cycles");
                end
            endtask
        
 000001     initial begin
 000001         if (!$value$plusargs("ROUND_KEYS=%s", round_key_file))
                    $fatal(1, "+ROUND_KEYS path is required");
 000001         $readmemh(round_key_file, expected_round_keys);
 000044         for (bit_index = 0; bit_index < 44; bit_index = bit_index + 1) begin
 000044             if (dut.ROUND_KEYS[(bit_index * 32) +: 32]
                            !== expected_round_keys[bit_index][63:32])
                        $fatal(1, "GOOD round key mismatch at %0d", bit_index);
                end
 000003         repeat (3) @(posedge clk);
 000001         rst_n = 1'b1;
 000002         repeat (2) @(posedge clk);
 000001         run_block(64'h656b696c20646e75, EXPECT);
        
                // Reset during a nonzero load: reject a pending command throughout wipe.
 000001         @(negedge clk); cmd_valid = 1'b1;
 000001         @(negedge clk); cmd_valid = 1'b0; s_valid = 1'b1; s_bit = 1'b1;
 000005         repeat (5) @(posedge clk);
 000001         @(negedge clk); s_valid = 1'b0; rst_n = 1'b0;
 000001         @(negedge clk); rst_n = 1'b1; cmd_valid = 1'b1;
 000001         await_wipe();
 000001         cmd_valid = 1'b0;
        
                // Abort clears data serially during an active load.
 000001         @(negedge clk);
 000001         cmd_valid = 1'b1;
               
 000001         @(posedge clk);
 000001         @(negedge clk);
 000001         cmd_valid = 1'b0;
 000001         s_valid = 1'b1;
 000001         s_bit = 1'b1;
 000005         repeat (5) @(posedge clk);
 000001         @(negedge clk);
 000001         s_valid = 1'b0;
 000001         abort = 1'b1;
 000001         @(posedge clk);
 000001         @(negedge clk);
 000001         abort = 1'b0;
 000001         await_wipe();
 000001         if (!cmd_ready || {dut.a, dut.b} !== 64'b0)
                    $fatal(1, "fixed core abort did not erase/rearm");
        
                // Exercise cancellation at every reconstruction phase and depth.
 000007         for (abort_depth = 0; abort_depth < 7; abort_depth = abort_depth + 1)
 000028             for (abort_phase = 0; abort_phase < 4; abort_phase = abort_phase + 1) begin
 000028                 @(negedge clk); cmd_valid = 1'b1;
 000028                 @(negedge clk); cmd_valid = 1'b0; s_valid = 1'b1; s_bit = 1'b1;
 001792                 repeat (64) @(posedge clk);
 000028                 @(negedge clk); s_valid = 1'b0; seal_valid = 1'b1;
 000028                 @(negedge clk); seal_valid = 1'b0;
 000028                 wait_cycles = 0;
 175994                 while (!(dut.round_count == 6'd28 && dut.key_depth == abort_depth
 175994                         && dut.key_phase == abort_phase) && wait_cycles < 10000) begin
 175994                     @(negedge clk); wait_cycles = wait_cycles + 1;
                        end
 000028                 if (wait_cycles == 10000) $fatal(1, "abort phase unreachable");
 000028                 abort = 1'b1;
 000028                 @(negedge clk); abort = 1'b0;
 000028                 await_wipe();
 000028                 if (!cmd_ready || m_valid || {dut.a,dut.b} !== 64'b0
                                || dut.key_accumulator !== 1'b0 || dut.key_depth !== 3'b0
                                || dut.key_phase !== 2'b0)
                            $fatal(1, "key reconstruction abort failed");
                    end
 000001         run_block(64'h656b696c20646e75, EXPECT);
 000001         $display("PASS tb_szymon_fixed: single-key KAT + 64-cycle wipe, 9344 cycles, key bits, data hold, 28 abort phases, rearm");
 000001         $finish(0);
            end
        endmodule
        
        `default_nettype wire
        
