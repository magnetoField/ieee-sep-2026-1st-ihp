`timescale 1ns/1ps
`default_nettype none

module tb_szymon;
    reg clk = 0;
    reg rst_n = 0;
    reg abort = 0;
    reg cmd_valid = 0;
    wire cmd_ready;
    reg [127:0] cmd_key = 0;
    reg s_valid = 0;
    wire s_ready;
    reg s_bit = 0;
    reg seal_valid = 0;
    wire seal_ready;
    wire m_valid;
    reg m_ready = 0;
    wire m_bit;
    wire m_last;

    integer cycle = 0;
    integer failures = 0;
    integer vector_count = 0;
    integer index;
    reg [1023:0] vector_file;
    reg [255:0] vectors [0:1023];

    szymon dut (
        .clk(clk), .rst_n(rst_n), .abort(abort),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_key(cmd_key),
        .s_valid(s_valid), .s_ready(s_ready), .s_bit(s_bit),
        .seal_valid(seal_valid), .seal_ready(seal_ready),
        .m_valid(m_valid), .m_ready(m_ready), .m_bit(m_bit), .m_last(m_last)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cycle <= cycle + 1;

    task automatic fail(input [1023:0] message);
        begin
            $display("FAIL cycle=%0d: %0s", cycle, message);
            failures = failures + 1;
        end
    endtask

    task automatic start_cmd(input [127:0] key);
        begin
            while (!cmd_ready) @(posedge clk);
            @(negedge clk);
            cmd_key = key;
            cmd_valid = 1;
            @(posedge clk);
            @(negedge clk);
            cmd_valid = 0;
            cmd_key = ~key; // must not affect the accepted command
        end
    endtask

    task automatic load_block(input [63:0] block, input integer gap_mode);
        integer bit_index;
        begin
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                if (gap_mode) repeat ((bit_index % 3) + 1) @(posedge clk);
                @(negedge clk);
                s_bit = block[bit_index];
                s_valid = 1;
                while (!s_ready) @(posedge clk);
                @(posedge clk);
                @(negedge clk);
                s_valid = 0;
            end
            if (s_ready) fail("s_ready remained high after bit 64");
        end
    endtask

    task automatic seal_and_collect(
        input [63:0] expected,
        input integer backpressure,
        output [63:0] observed
    );
        time seal_time;
        integer bit_index;
        integer stalls;
        begin
            if (!seal_ready) fail("seal_ready missing after exactly 64 bits");
            @(negedge clk);
            seal_valid = 1;
            @(posedge clk);
            seal_time = $time;
            @(negedge clk);
            seal_valid = 0;
            @(posedge m_valid);
            if (($time - seal_time) != 14080)
                fail("first m_valid latency was not exactly 1408 cycles");
            observed = 0;
            stalls = 0;
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                @(negedge clk);
                m_ready = !backpressure;
                if (!m_ready) begin
                    reg held_bit;
                    reg held_last;
                    held_bit = m_bit;
                    held_last = m_last;
                    @(posedge clk);
                    @(negedge clk);
                    if (!m_valid || m_bit !== held_bit || m_last !== held_last)
                        fail("output changed under backpressure");
                    stalls = 1;
                    m_ready = 1;
                end else begin
                    stalls = 0;
                end
                if (!m_valid) fail("m_valid dropped before bit 64");
                if (m_last !== (bit_index == 0)) fail("m_last on wrong output bit");
                observed[bit_index] = m_bit;
                @(posedge clk);
            end
            @(negedge clk);
            m_ready = 0;
            if (observed !== expected) begin
                $display("expected=%016x observed=%016x", expected, observed);
                fail("ciphertext mismatch");
            end
            if (m_valid || !cmd_ready) fail("core did not return to IDLE after output");
            if ({dut.k3, dut.k2, dut.k1, dut.k0} !== 128'b0)
                fail("working key state not cleared after output");
            if ({dut.a, dut.b} !== 64'b0)
                fail("shared data state not cleared after output");
        end
    endtask

    task automatic run_block(
        input [127:0] key,
        input [63:0] plaintext,
        input [63:0] expected,
        input integer stress
    );
        reg [63:0] observed;
        begin
            start_cmd(key);
            if (cmd_ready) fail("cmd_ready high while loading");
            load_block(plaintext, stress);
            repeat (stress ? 3 : 0) @(posedge clk);
            if (m_valid) fail("encryption started without seal");
            seal_and_collect(expected, stress, observed);
        end
    endtask

    initial begin
        if (!$value$plusargs("VECTORS=%s", vector_file)) begin
            $display("FAIL: +VECTORS path is required");
            $finish(2);
        end
        if (!$value$plusargs("COUNT=%d", vector_count)) vector_count = 1024;
        $readmemh(vector_file, vectors);

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        run_block(
            128'h1b1a1918131211100b0a090803020100,
            64'h656b696c20646e75,
            64'h44c8fc20b9dfa07a,
            1
        );

        // Abort each externally visible phase and prove rearm/clearing.
        start_cmd(128'h0123456789abcdef0011223344556677);
        repeat (7) begin
            @(negedge clk); s_valid = 1; s_bit = 1;
            @(posedge clk); @(negedge clk); s_valid = 0;
        end
        abort = 1;
        @(posedge clk); @(negedge clk); abort = 0;
        if (!cmd_ready || {dut.a, dut.b, dut.k3, dut.k2, dut.k1, dut.k0} !== 192'b0)
            fail("abort did not clear LOAD state");

        for (index = 0; index < vector_count; index = index + 1) begin
            run_block(vectors[index][255:128], vectors[index][127:64], vectors[index][63:0], index < 4);
        end

        if (failures == 0) begin
            $display("PASS tb_szymon: KAT + %0d seeded vectors, exact latency, backpressure, abort", vector_count);
            $finish(0);
        end else begin
            $display("FAIL tb_szymon: %0d failures", failures);
            $fatal(1, "tb_szymon regression failed");
        end
    end
endmodule

`default_nettype wire
