`timescale 1ns/1ps
module tb_fault_sessions;
    reg clk=0,rst_n=0,ena=1;reg[15:0]pressed=0;
    wire[3:0]kb_col_n,kb_row_oe;reg sdi=0,sclk=0,cs_n=1;
    wire sdo,req,rsp_ready,buzzer_out;
    integer cmd_fires,seal_fires,session_ends,i,base;
    function[3:0]network_columns;
        input[15:0]keys;input[3:0]driven;reg[7:0]reached;integer pass,row,col;
        begin reached={4'b0,driven};
            for(pass=0;pass<8;pass=pass+1)for(row=0;row<4;row=row+1)
                for(col=0;col<4;col=col+1)
                    if(keys[4*row+col]&&(reached[row]||reached[4+col]))begin
                        reached[row]=1;reached[4+col]=1;
                    end
            network_columns=reached[7:4];end
    endfunction
    assign kb_col_n=~network_columns(pressed,kb_row_oe);
    rumcajs #(.CLK_HZ(64000),.SCAN_HZ(4000),.PRESS_FRAMES(1),.RELEASE_FRAMES(1),
        // At scaled 64 kHz: 9344 cipher + 2*3072 bus cycles exceed 200 ms.
        // 300 ms permits the legal exchange; timeout fault remains exercised.
        .AUTH_TIMEOUT_MS(300),.BEEP_TICKS_MS(1)) dut(
        clk,rst_n,ena,kb_col_n,kb_row_oe,sdi,sclk,cs_n,sdo,req,rsp_ready,buzzer_out);
    always #5 clk=~clk;
    always @(posedge clk)begin
        if(dut.cmd_valid&&dut.cmd_ready)cmd_fires=cmd_fires+1;
        if(dut.seal_valid&&dut.seal_ready)seal_fires=seal_fires+1;
        if(dut.session_end)session_ends=session_ends+1;
        if((kb_row_oe&(kb_row_oe-1))!=0)$fatal(1,"unsafe rows");
        if(!rsp_ready&&sdo)$fatal(1,"SDO exposed outside response phase");
    end
    task cycles(input integer n);integer j;begin for(j=0;j<n;j=j+1)@(posedge clk);end endtask
    task press_mask(input[15:0]value,input integer hold);begin pressed=value;cycles(hold);pressed=0;cycles(180);end endtask
    task press(input integer id);begin press_mask(16'b1<<id,100);end endtask
    task good_pin;begin press(0);press(1);press(2);press(4);end endtask
    task bad_pin;begin press(0);press(1);press(2);press(5);end endtask
    task bus_wait;begin cycles(16);end endtask
    task frame_bits(input[63:0]word,input integer length);
        integer bit_index;begin
            cs_n=0;bus_wait();
            for(bit_index=63;bit_index>=64-length;bit_index=bit_index-1)begin
                sdi=word[bit_index];bus_wait();sclk=1;bus_wait();sclk=0;bus_wait();
            end
            cs_n=1;bus_wait();
        end
    endtask
    task wait_req;integer n;begin n=0;while(!req&&n<3000)begin@(posedge clk);n=n+1;end
        if(!req)$fatal(1,"REQ missing cmd=%0d fail=%0d digits=%0d auth=%0d armed=%b gesture=%b",
            cmd_fires,dut.u_regs.fail_count,dut.u_regs.digit_count,dut.u_auth.state,
            dut.u_kb.armed,dut.u_kb.gesture_active);end endtask
    task wait_idle;integer n;begin n=0;while(dut.u_auth.state!=0&&n<21000)begin@(posedge clk);n=n+1;end
        if(req||rsp_ready)$fatal(1,"session failed to end");
        cycles(100); // post-flush stable release before the next physical gesture
        end endtask
    task complete_exchange(input[63:0]challenge,input[63:0]expected);
        integer bit_index,n;reg[63:0]got;begin
            wait_req();frame_bits(challenge,64);n=0;
            cycles(10000);
            if(!rsp_ready)$fatal(1,"response missing");
            cs_n=0;bus_wait();got=0;
            for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
                bus_wait();sclk=1;#1;got[bit_index]=sdo;bus_wait();sclk=0;bus_wait();
            end
            cs_n=1;bus_wait();if(got!==expected)$fatal(1,"response wrong %h",got);wait_idle();
        end
    endtask
    initial begin
        cmd_fires=0;seal_fires=0;session_ends=0;
        repeat(4)@(posedge clk);@(negedge clk);rst_n=1;cycles(160);

        // Arbitrary idle traffic has no token and cannot start the core.
        base=cmd_fires;frame_bits(64'hdeadbeef01234567,64);cycles(100);
        if(req||rsp_ready||cmd_fires!=base)$fatal(1,"traffic without PIN created a session");

        // Chords in place of every digit do not assemble a PIN.
        press_mask((1<<0)|(1<<1),100);press_mask((1<<1)|(1<<2),100);
        press_mask((1<<2)|(1<<6),100);press_mask((1<<4)|(1<<5),100);cycles(300);
        if(req||dut.u_regs.digit_count)$fatal(1,"chords assembled a PIN");

        // A long digit is still one digit; long star clears the partial PIN once.
        press_mask(1<<0,500);if(dut.u_regs.digit_count!=1)$fatal(1,"long hold repeated digit");
        press_mask(1<<12,500);if(dut.u_regs.digit_count||req)$fatal(1,"long star did not clear once");

        // BAD1 creates no token; a subsequent GOOD timeout preserves its count.
        bad_pin();cycles(200);
        if(req||rsp_ready||cmd_fires)$fatal(1,"BAD1 admitted a session");
        good_pin();wait_req();
        if(dut.u_regs.fail_count!=1)$fatal(1,"BAD1 not counted before REQ");
        wait_idle();if(dut.u_regs.fail_count!=1||seal_fires)$fatal(1,"timeout rolled back/ran cipher");

        // A short GOOD RX aborts without consuming a PIN-failure attempt.
        good_pin();wait_req();frame_bits(64'h656b696c20646e75,63);wait_idle();
        if(dut.u_regs.fail_count!=1||rsp_ready)$fatal(1,"short GOOD RX changed attempts/responded");

        // A fresh frame during CRYPT aborts the one token and exposes no response.
        good_pin();wait_req();frame_bits(64'h656b696c20646e75,64);cycles(20);
        if(req||rsp_ready||dut.u_auth.state!=6)$fatal(1,"CRYPT phase setup wrong");
        cs_n=0;bus_wait();cs_n=1;bus_wait();wait_idle();
        if(dut.u_regs.fail_count!=1||rsp_ready||sdo)$fatal(1,"CRYPT frame error unsafe");

        // BAD2 completes normally. A second challenge without a new PIN is inert.
        bad_pin();cycles(200);
        if(req||rsp_ready)$fatal(1,"BAD2 admitted a session");
        good_pin();complete_exchange(64'h656b696c20646e75,64'h44c8fc20b9dfa07a);
        if(dut.u_regs.fail_count!=2)$fatal(1,"BAD2 accounting wrong");
        base=cmd_fires;frame_bits(64'h0123456789abcdef,64);cycles(300);
        if(req||rsp_ready||cmd_fires!=base)$fatal(1,"second challenge reused token");

        // The admitted third BAD is counted, then a torn RX leaves LOCKED.
        bad_pin();cycles(200);if(req||rsp_ready||dut.u_regs.fail_count!=3||!dut.u_regs.locked)
            $fatal(1,"terminal BAD not admitted/locked");
        frame_bits(64'h1122334455667788,1);wait_idle();
        if(dut.u_regs.fail_count!=3||!dut.u_regs.locked)$fatal(1,"terminal abort unlocked");
        base=cmd_fires;good_pin();cycles(500);
        if(req||cmd_fires!=base)$fatal(1,"new PIN admitted after terminal abort");

        if(cmd_fires!=4||seal_fires!=2||session_ends!=4)
            $fatal(1,"aggregate fault cardinality cmd=%0d seal=%0d end=%0d",cmd_fires,seal_fires,session_ends);
        $display("PASS tb_fault_sessions idle/chord/hold/timeout/RX/CRYPT/replay/terminal-lock faults");$finish;
    end
endmodule
