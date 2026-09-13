`timescale 1ns/1ps
`default_nettype none

module tb_szymon_fixed #(
    parameter [127:0] TEST_KEY = 128'h1b1a1918131211100b0a090803020100,
    parameter [63:0] EXPECT = 64'h44c8fc20b9dfa07a
);
    reg clk = 0;
    reg rst_n = 0;
    reg abort = 0;
    reg cmd_valid = 0;
    wire cmd_ready;
    reg s_valid = 0;
    wire s_ready;
    reg s_bit = 0;
    reg seal_valid = 0;
    wire seal_ready;
    wire m_valid;
    reg m_ready = 0;
    wire m_bit;
    wire m_last;
    integer bit_index;
    reg [63:0] observed;
    reg [1023:0] round_key_file;
    reg [63:0] expected_round_keys [0:43];
    integer abort_depth;
    integer abort_phase;
    integer wait_cycles;
    reg [63:0] held_data;

    szymon_fixed #(.KEY(TEST_KEY)) dut (
        .clk(clk), .rst_n(rst_n), .abort(abort),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .s_valid(s_valid), .s_ready(s_ready),
        .s_bit(s_bit), .seal_valid(seal_valid), .seal_ready(seal_ready),
        .m_valid(m_valid), .m_ready(m_ready), .m_bit(m_bit), .m_last(m_last)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rst_n && !abort && dut.state == 3'd3 && !dut.key_ready) begin
            held_data = {dut.a, dut.b};
            #1;
            if ({dut.a, dut.b} !== held_data)
                $fatal(1, "data changed during key-only cycle");
        end
    end

    // Check actually consumed bits against the independent model schedule.
    always @(negedge clk) begin
        if (rst_n && !abort && dut.state == 3'd3 && dut.key_ready) begin
            if (dut.round_key_bit !== expected_round_keys[dut.round_count]
                    [63 - dut.bit_count])
                $fatal(1, "consumed key mismatch round=%0d bit=%0d",
                    dut.round_count, dut.bit_count);
        end
    end

    task automatic run_block(
        input [63:0] plaintext,
        input [63:0] expected
    );
        time seal_time;
        begin
            while (!cmd_ready) @(posedge clk);
            @(negedge clk);
            cmd_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            cmd_valid = 1'b0;

            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                @(negedge clk);
                s_valid = 1'b1;
                s_bit = plaintext[bit_index];
                @(posedge clk);
            end
            @(negedge clk);
            s_valid = 1'b0;
            if (!seal_ready) $fatal(1, "fixed core did not accept 64 bits");
            seal_valid = 1'b1;
            @(posedge clk);
            seal_time = $time;
            @(negedge clk);
            seal_valid = 1'b0;

            @(posedge m_valid);
            if (($time - seal_time) != 93440)
                $fatal(1, "fixed core latency was not 9344 cycles");

            observed = 64'b0;
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                @(negedge clk);
                if (!m_valid || (m_last !== (bit_index == 0)))
                    $fatal(1, "fixed core output framing bit %0d", bit_index);
                observed[bit_index] = m_bit;
                m_ready = 1'b1;
                @(posedge clk);
            end
            @(negedge clk);
            m_ready = 1'b0;
            if (observed !== expected)
                $fatal(1, "fixed core mismatch got=%h expected=%h", observed, expected);
            if (!cmd_ready || {dut.a, dut.b} !== 64'b0)
                $fatal(1, "fixed core did not erase/rearm");
        end
    endtask

    task await_wipe;
        integer w;
        begin
            if (m_valid || m_bit !== 1'b0 || s_ready || seal_ready || cmd_ready)
                $fatal(1, "interface not blocked on serial wipe entry");
            for (w=1; w<64; w=w+1) begin
                @(negedge clk);
                if (m_valid || m_bit !== 1'b0 || s_ready || seal_ready || cmd_ready)
                    $fatal(1, "serial wipe finished early");
            end
            @(negedge clk);
            if (!cmd_ready || {dut.a,dut.b} !== 64'b0)
                $fatal(1, "serial wipe did not erase after 64 cycles");
        end
    endtask

    initial begin
        if (!$value$plusargs("ROUND_KEYS=%s", round_key_file))
            $fatal(1, "+ROUND_KEYS path is required");
        $readmemh(round_key_file, expected_round_keys);
        for (bit_index = 0; bit_index < 44; bit_index = bit_index + 1) begin
            if (dut.ROUND_KEYS[(bit_index * 32) +: 32]
                    !== expected_round_keys[bit_index][63:32])
                $fatal(1, "GOOD round key mismatch at %0d", bit_index);
        end
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        run_block(64'h656b696c20646e75, EXPECT);

        // Reset during a nonzero load: reject a pending command throughout wipe.
        @(negedge clk); cmd_valid = 1'b1;
        @(negedge clk); cmd_valid = 1'b0; s_valid = 1'b1; s_bit = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk); s_valid = 1'b0; rst_n = 1'b0;
        @(negedge clk); rst_n = 1'b1; cmd_valid = 1'b1;
        await_wipe();
        cmd_valid = 1'b0;

        // Abort clears data serially during an active load.
        @(negedge clk);
        cmd_valid = 1'b1;
       
        @(posedge clk);
        @(negedge clk);
        cmd_valid = 1'b0;
        s_valid = 1'b1;
        s_bit = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        s_valid = 1'b0;
        abort = 1'b1;
        @(posedge clk);
        @(negedge clk);
        abort = 1'b0;
        await_wipe();
        if (!cmd_ready || {dut.a, dut.b} !== 64'b0)
            $fatal(1, "fixed core abort did not erase/rearm");

        // Exercise cancellation at every reconstruction phase and depth.
        for (abort_depth = 0; abort_depth < 7; abort_depth = abort_depth + 1)
            for (abort_phase = 0; abort_phase < 4; abort_phase = abort_phase + 1) begin
                @(negedge clk); cmd_valid = 1'b1;
                @(negedge clk); cmd_valid = 1'b0; s_valid = 1'b1; s_bit = 1'b1;
                repeat (64) @(posedge clk);
                @(negedge clk); s_valid = 1'b0; seal_valid = 1'b1;
                @(negedge clk); seal_valid = 1'b0;
                wait_cycles = 0;
                while (!(dut.round_count == 6'd28 && dut.key_depth == abort_depth
                        && dut.key_phase == abort_phase) && wait_cycles < 10000) begin
                    @(negedge clk); wait_cycles = wait_cycles + 1;
                end
                if (wait_cycles == 10000) $fatal(1, "abort phase unreachable");
                abort = 1'b1;
                @(negedge clk); abort = 1'b0;
                await_wipe();
                if (!cmd_ready || m_valid || {dut.a,dut.b} !== 64'b0
                        || dut.key_accumulator !== 1'b0 || dut.key_depth !== 3'b0
                        || dut.key_phase !== 2'b0)
                    $fatal(1, "key reconstruction abort failed");
            end
        run_block(64'h656b696c20646e75, EXPECT);
        $display("PASS tb_szymon_fixed: single-key KAT + 64-cycle wipe, 9344 cycles, key bits, data hold, 28 abort phases, rearm");
        $finish(0);
    end
endmodule

`default_nettype wire
