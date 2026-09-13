//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_serial_link;
            localparam [63:0] RX_EXPECTED = 64'h656b696c20646e75;
 021651     reg clk=0,rst_n=0,cancel=0,rx_arm=0,tx_arm=0;
 000014     wire rx_active,tx_active,rx_done,tx_done,protocol_error,frame_start;
 000390     reg serial_sdi=0,serial_sclk=0,serial_cs_n=1;
 000258     wire serial_sdo,s_valid,s_bit,m_ready;
 000026     reg s_ready=1,m_valid=0,m_bit=0,m_last=0;
~000102     reg [63:0] rx_word=0,tx_word=0,observed=0;
 000001     integer rx_count=0,tx_source_index=63;
 000001     integer rx_done_events=0,tx_done_events=0,error_events=0;
        
            serial_link dut(clk,rst_n,cancel,rx_arm,tx_arm,rx_active,tx_active,
                rx_done,tx_done,protocol_error,frame_start,serial_sdi,serial_sclk,
                serial_cs_n,serial_sdo,s_valid,s_ready,s_bit,m_valid,m_ready,m_bit,m_last);
 021651     always #5 clk=~clk;
 010826     always @(posedge clk) begin
 010825         if(rx_done) begin
 000001             rx_done_events=rx_done_events+1;
 000001             if(dut.bit_count!=0)$fatal(1,"rx_done before framing counter cleanup");
                end
 010825         if(tx_done) tx_done_events=tx_done_events+1;
 010824         if(protocol_error) error_events=error_events+1;
 010698         if(s_valid&&s_ready) begin rx_word={rx_word[62:0],s_bit};rx_count=rx_count+1;end
 010762         if(m_valid&&m_ready) begin
 000063             if(tx_source_index==0) m_valid<=0;
 000063             else tx_source_index<=tx_source_index-1;
                end
 010826         m_bit<=tx_word[tx_source_index];
 010826         m_last<=(tx_source_index==0);
            end
        
 010800     task settle; begin repeat(20) @(posedge clk); end endtask
 000004     task arm_rx; begin @(negedge clk);rx_arm=1;@(posedge clk);@(negedge clk);rx_arm=0;settle();end endtask
 000001     task arm_tx; begin @(negedge clk);tx_arm=1;@(posedge clk);@(negedge clk);tx_arm=0;settle();end endtask
 000128     task bus_bit(input bit value, output bit sampled);
 000128         begin
 000128             serial_sdi=value; settle(); serial_sclk=1; settle(); sampled=serial_sdo;
 000128             serial_sclk=0; settle();
                end
            endtask
 000003     task close_cs; begin serial_cs_n=1;settle();end endtask
 000004     task clear_events; begin cancel=1;@(posedge clk);@(negedge clk);cancel=0;settle();end endtask
        
            integer i;
%000000     reg sampled;
 000028     reg held;
 000001     initial begin
 000003         repeat(3) @(posedge clk);@(negedge clk);rst_n=1;settle();
        
                // CS low before arm cannot start a frame; a fresh high/fall is required.
 000001         serial_cs_n=0;settle();arm_rx();
 000001         serial_sdi=1;serial_sclk=1;settle();serial_sclk=0;settle();
 000001         if(rx_active||rx_count!=0) $fatal(1,"pre-arm low CS accepted");
 000001         serial_cs_n=1;settle();serial_cs_n=0;settle();
 000001         if(!rx_active) $fatal(1,"fresh RX frame not started");
 000064         for(i=63;i>=0;i=i-1) bus_bit(RX_EXPECTED[i],sampled);
 000001         close_cs();
 000001         if(rx_done_events!=1 || rx_count!=64 || rx_word!==64'h656b696c20646e75)
                    $fatal(1,"RX64 order/completion wrong count=%0d word=%h",rx_count,rx_word);
 000001         settle(); if(rx_done) $fatal(1,"rx_done not a pulse");
        
                // Pending RX is stable under backpressure, then drains once.
 000001         clear_events(); rx_count=0;rx_word=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();
 000001         s_ready=0; serial_sdi=1;settle();serial_sclk=1;settle();
 000001         if(!s_valid||s_bit!=1) $fatal(1,"RX pending missing");
 000008         held=s_bit;repeat(8)@(posedge clk);if(!s_valid||s_bit!==held)$fatal(1,"RX pending changed");
 000002         s_ready=1;repeat(2)@(posedge clk);if(s_valid)$fatal(1,"RX pending did not drain");
 000001         serial_sclk=0;settle();clear_events();
        
                // A second edge while pending and not-ready is an overrun.
 000001         rx_count=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();s_ready=0;
 000001         bus_bit(1'b0,sampled); // bus_bit includes next falling edge; pending remains
 000001         serial_sclk=1;settle();
 000001         if(error_events!=1) $fatal(1,"overrun not reported");
 000001         s_ready=1;serial_sclk=0;serial_cs_n=1;clear_events();
        
                // TX: data changes after falling edges and is held across rising samples.
 000001         tx_word=64'h44c8fc20b9dfa07a;tx_source_index=63;
 000001         m_bit=tx_word[63];m_last=0;m_valid=1;serial_cs_n=1;arm_tx();
 000004         repeat(4)@(posedge clk);
 000001         serial_cs_n=0;settle();
 000001         if(!tx_active||serial_sdo!==tx_word[63])$fatal(1,"first TX bit not preloaded");
 000001         observed=0;
 000064         for(i=63;i>=0;i=i-1) begin
 000064             held=serial_sdo;serial_sclk=1;settle();
 000064             if(serial_sdo!==held)$fatal(1,"SDO changed before falling edge bit=%0d",i);
 000064             observed[i]=held;serial_sclk=0;settle();
                end
 000001         if(observed!==tx_word)$fatal(1,"TX order wrong got=%h",observed);
 000001         if(serial_sdo!==0)$fatal(1,"SDO nonzero after TX bits");
 000001         close_cs();if(tx_done_events!=1)$fatal(1,"tx_done missing");
 000001         settle();if(tx_done)$fatal(1,"tx_done not pulse");
        
                // Short frame is rejected and never reports done.
 000001         clear_events();rx_count=0;serial_cs_n=1;arm_rx();serial_cs_n=0;settle();
 000063         for(i=0;i<63;i=i+1)bus_bit(i[0],sampled);
 000001         close_cs();if(error_events!=2||rx_done_events!=1)$fatal(1,"63-bit RX accepted");
 000001         if(serial_sdo!==0)$fatal(1,"SDO unsafe outside TX");
 000001         $display("PASS tb_serial_link RX/TX64, fresh CS, holds, backpressure, overrun, framing");$finish;
            end
        endmodule
        
