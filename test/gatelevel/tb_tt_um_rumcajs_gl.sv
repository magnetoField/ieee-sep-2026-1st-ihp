`timescale 1ns/1ps

// No-SDF functional smoke for a mapped or post-route netlist. This bench uses
// only public Tiny Tapeout pins so it also works after hierarchy is flattened.
module tb_tt_um_rumcajs_gl #(
    parameter CLOCK_HALF_NS = 1,
    parameter IO_SETTLE_NS = 1
);
`ifdef SDF_RUN
    reg [8191:0] sdf_file;
    initial begin
        if (!$value$plusargs("SDF_FILE=%s", sdf_file))
            $fatal(1, "SDF_FILE is required for timing simulation");
        $sdf_annotate(sdf_file, dut);
        $display("SDF annotation requested (check simulator diagnostics): %0s", sdf_file);
    end
`endif
    reg clk = 0;
    reg rst_n = 0;
    reg ena = 1;
    reg [7:0] uio_in = 0;
    reg [15:0] pressed = 0;
    reg sdi = 0;
    reg sclk = 0;
    reg cs_n = 1;
    reg unused_ui7 = 0;
    wire [7:0] ui_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    wire [3:0] columns;
`ifdef IHP_POWER_PINS
    supply1 vpwr;
    supply0 vgnd;
`endif

    assign ui_in = {unused_ui7, cs_n, sclk, sdi, columns};

    function [3:0] network_columns;
        input [15:0] keys;
        input [3:0] driven;
        reg [7:0] reached;
        integer pass;
        integer row;
        integer col;
        begin
            reached = {4'b0, driven};
            for (pass = 0; pass < 8; pass = pass + 1)
                for (row = 0; row < 4; row = row + 1)
                    for (col = 0; col < 4; col = col + 1)
                        if (keys[4*row+col] &&
                            (reached[row] || reached[4+col])) begin
                            reached[row] = 1'b1;
                            reached[4+col] = 1'b1;
                        end
            network_columns = reached[7:4];
        end
    endfunction

    assign columns = ~network_columns(pressed, uio_oe[3:0]);

    tt_um_rumcajs dut (
`ifdef IHP_POWER_PINS
        .VPWR(vpwr), .VGND(vgnd),
`endif
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe), .ena(ena),
        .clk(clk), .rst_n(rst_n)
    );

    always #(CLOCK_HALF_NS) clk = ~clk;

    always @(negedge clk)
        if (rst_n) begin
            unused_ui7 <= ~unused_ui7;
            uio_in <= uio_in + 8'h3d;
        end

    always @(posedge clk) begin
        if (uio_out !== 8'b0 || uio_oe[7:4] !== 4'b0 ||
            uo_out[7:4] !== 4'b0 || uo_out[1] !== 1'b0)
            $fatal(1, "reserved pin unsafe");
        if ((uio_oe[3:0] & (uio_oe[3:0] - 1'b1)) != 0)
            $fatal(1, "keypad rows not onehot0");
    end

    task cycles;
        input integer count;
        integer index;
        begin
            for (index = 0; index < count; index = index + 1)
                @(posedge clk);
        end
    endtask

    task press;
        input integer key_id;
        begin
            pressed = 16'b1 << key_id;
            cycles(22000);
            pressed = 0;
            cycles(45000);
        end
    endtask

    task good_pin;
        begin press(0); press(1); press(2); press(4); end
    endtask

    task bad_pin;
        begin press(0); press(1); press(2); press(5); end
    endtask

    task bus_wait;
        begin cycles(20); end
    endtask

    task exchange;
        input [63:0] challenge;
        input [63:0] expected;
        integer index;
        integer waited;
        reg [63:0] received;
        begin
            waited = 0;
            while (!uo_out[0] && waited < 5000) begin
                @(posedge clk);
                waited = waited + 1;
            end
            if (!uo_out[0])
                $fatal(1, "REQ timeout");

            cs_n = 0;
            bus_wait();
            for (index = 63; index >= 0; index = index - 1) begin
                sdi = challenge[index];
                bus_wait();
                sclk = 1;
                bus_wait();
                sclk = 0;
                bus_wait();
            end
            cs_n = 1;
            bus_wait();

            cycles(10000);
            if (uo_out[0] || uo_out[1]) $fatal(1, "READY/reserved pin wrong after RX");

            cs_n = 0;
            bus_wait();
            received = 0;
            for (index = 63; index >= 0; index = index - 1) begin
                bus_wait();
                sclk = 1;
                #1 received[index] = uo_out[2];
                bus_wait();
                sclk = 0;
                bus_wait();
            end
            cs_n = 1;
            bus_wait();
            if (received !== expected)
                $fatal(1, "response %h, expected %h", received, expected);
            cycles(25000);
        end
    endtask

    task malformed_63_bit_frame;
        integer index;
        integer waited;
        begin
            waited = 0;
            while (!uo_out[0] && waited < 5000) begin
                @(posedge clk);
                waited = waited + 1;
            end
            if (!uo_out[0])
                $fatal(1, "REQ timeout before malformed frame");
            cs_n = 0;
            bus_wait();
            for (index = 62; index >= 0; index = index - 1) begin
                sdi = index[0];
                bus_wait();
                sclk = 1;
                bus_wait();
                sclk = 0;
                bus_wait();
            end
            cs_n = 1;
            bus_wait();
            cycles(100);
            if (uo_out[0] || uo_out[1] || uo_out[2])
                $fatal(1, "malformed frame left protocol output active");
            cycles(25000);
        end
    endtask

    initial begin
        #(IO_SETTLE_NS);
        if (uo_out !== 8'b0 || uio_out !== 8'b0 || uio_oe !== 8'b0)
            $fatal(1, "asynchronous reset mask unsafe");
        cycles(4);
        @(negedge clk);
        rst_n = 1;
        cycles(25000);

        ena = 0;
        #(IO_SETTLE_NS);
        if (uo_out !== 8'b0 || uio_out !== 8'b0 || uio_oe !== 8'b0)
            $fatal(1, "ena mask unsafe");
        ena = 1;
        cycles(25000);

        good_pin();
        malformed_63_bit_frame();
        good_pin();
        exchange(64'hf15654a8d25ffa1c, 64'hba2a5234deadbeef);
        bad_pin();
        cycles(10000);
        if(uo_out[2:0]!==0)$fatal(1,"BAD PIN produced readiness or data");
        bad_pin();
        cycles(10000);
        if(uo_out[2:0]!==0)$fatal(1,"BAD PIN produced readiness or data");
        bad_pin();
        cycles(10000);
        if(uo_out[2:0]!==0)$fatal(1,"BAD PIN produced readiness or data");

        good_pin();
        cycles(5000);
        if (uo_out[0])
            $fatal(1, "lockout accepted a fourth post-failure transaction");

        $display("PASS gate-level mapped standard cells: reset/ena, malformed RX, single-key GOOD, BAD rejection, limit");
        $finish;
    end
endmodule
