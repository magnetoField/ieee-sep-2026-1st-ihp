`timescale 1ns/1ps
module tb_serial_lengths;
    reg clk=0,rst_n=0,cancel=0,rx_arm=0,tx_arm=0;
    wire rx_active,tx_active,rx_done,tx_done,protocol_error,frame_start;
    reg serial_sdi=0,serial_sclk=0,serial_cs_n=1,s_ready=1,m_valid=0;
    wire serial_sdo,s_valid,s_bit,m_ready;
    reg [63:0] tx_word;
    integer tx_index,rx_fires,done_count,error_count,delay_cycles;
    wire m_bit=tx_word[tx_index];
    wire m_last=(tx_index==0);
    serial_link dut(clk,rst_n,cancel,rx_arm,tx_arm,rx_active,tx_active,
        rx_done,tx_done,protocol_error,frame_start,serial_sdi,serial_sclk,
        serial_cs_n,serial_sdo,s_valid,s_ready,s_bit,m_valid,m_ready,m_bit,m_last);
    always #5 clk=~clk;
    always @(posedge clk)begin
        if(s_valid&&s_ready)rx_fires=rx_fires+1;
        if(rx_done||tx_done)done_count=done_count+1;
        if(protocol_error)error_count=error_count+1;
        if(m_valid&&m_ready)begin
            if(tx_index==0)m_valid<=0;else tx_index<=tx_index-1;
        end
        if(serial_sdo && !tx_active)$fatal(1,"SDO outside TX");
    end
    task wait_bus;integer n;begin for(n=0;n<delay_cycles;n=n+1)@(posedge clk);end endtask
    task clean;
        begin
            serial_cs_n=1;serial_sclk=0;m_valid=0;s_ready=1;
            @(negedge clk);cancel=1;@(posedge clk);@(negedge clk);cancel=0;wait_bus();
        end
    endtask
    task pulse_arm_rx;begin @(negedge clk);rx_arm=1;@(posedge clk);@(negedge clk);rx_arm=0;wait_bus();end endtask
    task pulse_arm_tx;begin @(negedge clk);tx_arm=1;@(posedge clk);@(negedge clk);tx_arm=0;wait_bus();end endtask
    task clock_bit(input bit value,output bit sampled);
        begin serial_sdi=value;wait_bus();serial_sclk=1;wait_bus();sampled=serial_sdo;serial_sclk=0;wait_bus();end
    endtask
    task rx_length(input integer length,input integer should_pass);
        integer i,e0,d0,r0;reg sampled;
        begin
            clean();e0=error_count;d0=done_count;r0=rx_fires;
            pulse_arm_rx();serial_cs_n=0;wait_bus();
            for(i=0;i<length;i=i+1)clock_bit(i[0],sampled);
            serial_cs_n=1;wait_bus();
            if(should_pass)begin
                if(error_count!=e0||done_count!=d0+1||rx_fires-r0!=64)
                    $fatal(1,"RX length %0d not accepted exactly err=%0d done=%0d fires=%0d",
                        length,error_count-e0,done_count-d0,rx_fires-r0);
            end else if(error_count!=e0+1||done_count!=d0)
                $fatal(1,"RX length %0d not rejected once err=%0d done=%0d",
                    length,error_count-e0,done_count-d0);
        end
    endtask
    task tx_length(input integer length,input integer should_pass);
        integer i,e0,d0;reg sampled;reg[63:0]got;
        begin
            clean();e0=error_count;d0=done_count;tx_word=64'h8000000000000001;tx_index=63;m_valid=1;
            pulse_arm_tx();wait_bus();serial_cs_n=0;wait_bus();got=0;
            for(i=0;i<length;i=i+1)begin
                clock_bit(1'b0,sampled);
                if(i<64)got[63-i]=sampled;
            end
            serial_cs_n=1;wait_bus();
            if(should_pass)begin
                if(error_count!=e0||done_count!=d0+1||got!==tx_word)
                    $fatal(1,"TX64 failed err=%0d done=%0d got=%h",error_count-e0,done_count-d0,got);
            end else if(error_count!=e0+1||done_count!=d0)
                $fatal(1,"TX length %0d not rejected once err=%0d done=%0d",
                    length,error_count-e0,done_count-d0);
            if(serial_sdo)$fatal(1,"SDO remained active after TX length %0d",length);
        end
    endtask
    integer i;
    reg sampled;
    initial begin
        delay_cycles=16;rx_fires=0;done_count=0;error_count=0;
        repeat(3)@(posedge clk);@(negedge clk);rst_n=1;#3;
        // Idle SCLK and an unarmed frame are ignored.
        for(i=0;i<4;i=i+1)clock_bit(i[0],sampled);
        serial_cs_n=0;wait_bus();clock_bit(1'b1,sampled);serial_cs_n=1;wait_bus();
        if(error_count||done_count||rx_fires)$fatal(1,"idle traffic caused activity");
        delay_cycles=16;rx_length(0,0);
        delay_cycles=17;rx_length(1,0);
        delay_cycles=18;rx_length(63,0);
        delay_cycles=19;rx_length(64,1);
        delay_cycles=20;rx_length(65,0);
        delay_cycles=21;rx_length(127,0);
        delay_cycles=22;rx_length(128,0);
        delay_cycles=16;tx_length(0,0);
        delay_cycles=17;tx_length(63,0);
        delay_cycles=18;tx_length(64,1);
        delay_cycles=19;tx_length(65,0);
        // A source asserting last before output bit 63 is a framing error.
        clean();i=error_count;tx_word=64'h1;tx_index=0;m_valid=1;
        pulse_arm_tx();serial_cs_n=0;wait_bus();clock_bit(1'b0,sampled);
        if(error_count!=i+1)$fatal(1,"early m_last was not rejected");
        // No source data at frame start is an underrun.
        clean();i=error_count;pulse_arm_tx();serial_cs_n=0;wait_bus();
        if(error_count!=i+1)$fatal(1,"TX underrun not rejected");
        clean();rst_n=0;#1;if(serial_sdo||s_valid||rx_active||tx_active)$fatal(1,"reset unsafe");
        $display("PASS tb_serial_lengths RX 0/1/63/64/65/127/128, TX framing, min timing/phases");$finish;
    end
endmodule
