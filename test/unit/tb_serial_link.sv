`timescale 1ns/1ps
module tb_serial_link;
    localparam [63:0] RX_EXPECTED = 64'h656b696c20646e75;
    reg clk=0,rst_n=0,cancel=0,rx_arm=0,tx_arm=0;
    wire rx_active,tx_active,rx_done,tx_done,protocol_error,frame_start;
    reg serial_sdi=0,serial_sclk=0,serial_cs_n=1;
    wire serial_sdo,s_valid,s_bit,m_ready;
    reg s_ready=1,m_valid=0,m_bit=0,m_last=0;
    reg [63:0] rx_word=0,tx_word=0,observed=0;
    integer rx_count=0,tx_source_index=63;
    integer rx_done_events=0,tx_done_events=0,error_events=0;

    serial_link dut(clk,rst_n,cancel,rx_arm,tx_arm,rx_active,tx_active,
        rx_done,tx_done,protocol_error,frame_start,serial_sdi,serial_sclk,
        serial_cs_n,serial_sdo,s_valid,s_ready,s_bit,m_valid,m_ready,m_bit,m_last);
    always #5 clk=~clk;
    always @(posedge clk) begin
        if(rx_done) begin
            rx_done_events=rx_done_events+1;
            if(dut.bit_count!=0)$fatal(1,"rx_done before framing counter cleanup");
        end
        if(tx_done) tx_done_events=tx_done_events+1;
        if(protocol_error) error_events=error_events+1;
        if(s_valid&&s_ready) begin rx_word={rx_word[62:0],s_bit};rx_count=rx_count+1;end
        if(m_valid&&m_ready) begin
            if(tx_source_index==0) m_valid<=0;
            else tx_source_index<=tx_source_index-1;
        end
        m_bit<=tx_word[tx_source_index];
        m_last<=(tx_source_index==0);
    end

    task settle; begin repeat(20) @(posedge clk); end endtask
    task arm_rx; begin @(negedge clk);rx_arm=1;@(posedge clk);@(negedge clk);rx_arm=0;settle();end endtask
    task arm_tx; begin @(negedge clk);tx_arm=1;@(posedge clk);@(negedge clk);tx_arm=0;settle();end endtask
    task bus_bit(input bit value, output bit sampled);
        begin
            serial_sdi=value; settle(); serial_sclk=1; settle(); sampled=serial_sdo;
            serial_sclk=0; settle();
        end
    endtask
    task close_cs; begin serial_cs_n=1;settle();end endtask
    task clear_events; begin cancel=1;@(posedge clk);@(negedge clk);cancel=0;settle();end endtask

    integer i;
    reg sampled;
    reg held;
    initial begin
        repeat(3) @(posedge clk);@(negedge clk);rst_n=1;settle();

        // CS low before arm cannot start a frame; a fresh high/fall is required.
        serial_cs_n=0;settle();arm_rx();
        serial_sdi=1;serial_sclk=1;settle();serial_sclk=0;settle();
        if(rx_active||rx_count!=0) $fatal(1,"pre-arm low CS accepted");
        serial_cs_n=1;settle();serial_cs_n=0;settle();
        if(!rx_active) $fatal(1,"fresh RX frame not started");
        for(i=63;i>=0;i=i-1) bus_bit(RX_EXPECTED[i],sampled);
        close_cs();
        if(rx_done_events!=1 || rx_count!=64 || rx_word!==64'h656b696c20646e75)
            $fatal(1,"RX64 order/completion wrong count=%0d word=%h",rx_count,rx_word);
        settle(); if(rx_done) $fatal(1,"rx_done not a pulse");

        // Pending RX is stable under backpressure, then drains once.
        clear_events(); rx_count=0;rx_word=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();
        s_ready=0; serial_sdi=1;settle();serial_sclk=1;settle();
        if(!s_valid||s_bit!=1) $fatal(1,"RX pending missing");
        held=s_bit;repeat(8)@(posedge clk);if(!s_valid||s_bit!==held)$fatal(1,"RX pending changed");
        s_ready=1;repeat(2)@(posedge clk);if(s_valid)$fatal(1,"RX pending did not drain");
        serial_sclk=0;settle();clear_events();

        // A second edge while pending and not-ready is an overrun.
        rx_count=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();s_ready=0;
        bus_bit(1'b0,sampled); // bus_bit includes next falling edge; pending remains
        serial_sclk=1;settle();
        if(error_events!=1) $fatal(1,"overrun not reported");
        s_ready=1;serial_sclk=0;serial_cs_n=1;clear_events();

        // TX: data changes after falling edges and is held across rising samples.
        tx_word=64'h44c8fc20b9dfa07a;tx_source_index=63;
        m_bit=tx_word[63];m_last=0;m_valid=1;serial_cs_n=1;arm_tx();
        repeat(4)@(posedge clk);
        serial_cs_n=0;settle();
        if(!tx_active||serial_sdo!==tx_word[63])$fatal(1,"first TX bit not preloaded");
        observed=0;
        for(i=63;i>=0;i=i-1) begin
            held=serial_sdo;serial_sclk=1;settle();
            if(serial_sdo!==held)$fatal(1,"SDO changed before falling edge bit=%0d",i);
            observed[i]=held;serial_sclk=0;settle();
        end
        if(observed!==tx_word)$fatal(1,"TX order wrong got=%h",observed);
        if(serial_sdo!==0)$fatal(1,"SDO nonzero after TX bits");
        close_cs();if(tx_done_events!=1)$fatal(1,"tx_done missing");
        settle();if(tx_done)$fatal(1,"tx_done not pulse");

        // Short frame is rejected and never reports done.
        clear_events();rx_count=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();
        for(i=0;i<63;i=i+1)bus_bit(i[0],sampled);
        close_cs();if(error_events!=2||rx_done_events!=1)$fatal(1,"63-bit RX accepted");
        if(serial_sdo!==0)$fatal(1,"SDO unsafe outside TX");
        $display("PASS tb_serial_link RX/TX64, fresh CS, holds, backpressure, overrun, framing");$finish;
    end
endmodule
