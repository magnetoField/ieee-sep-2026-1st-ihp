`timescale 1ns/1ps
module tb_rumcajs;
    reg clk=0,rst_n=0,ena=1,run_clk=1;
    reg [15:0] pressed=0;
    wire [3:0] kb_col_n,kb_row_oe;
    reg serial_sdi=0,serial_sclk=0,serial_cs_n=1;
    wire serial_sdo,req,rsp_ready,buzzer_out;
    integer sessions=0;

    function [3:0] network_columns;
        input [15:0] keys; input [3:0] driven;
        reg [7:0] reached; integer pass,row,col;
        begin
            reached={4'b0,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)
                    for(col=0;col<4;col=col+1)
                        if(keys[4*row+col] && (reached[row]||reached[4+col])) begin
                            reached[row]=1;reached[4+col]=1;
                        end
            network_columns=reached[7:4];
        end
    endfunction
    assign kb_col_n=~network_columns(pressed,kb_row_oe);

    rumcajs #(.CLK_HZ(64000),.SCAN_HZ(4000),.PRESS_FRAMES(1),.RELEASE_FRAMES(1),
        .AUTH_TIMEOUT_MS(500),.BEEP_TICKS_MS(2)) dut(
        clk,rst_n,ena,kb_col_n,kb_row_oe,serial_sdi,serial_sclk,serial_cs_n,
        serial_sdo,req,rsp_ready,buzzer_out);
    always begin #5;if(run_clk)clk=~clk;end
    always @(posedge clk) if((kb_row_oe&(kb_row_oe-1))!=0)$fatal(1,"rows not onehot0");

    task wait_cycles(input integer count);integer n;begin for(n=0;n<count;n=n+1)@(posedge clk);end endtask
    task press_key(input integer id);
        begin pressed=16'b1<<id;wait_cycles(100);pressed=0;wait_cycles(180);end
    endtask
    task enter_good;begin press_key(0);press_key(1);press_key(2);press_key(4);end endtask
    task enter_bad; begin press_key(0);press_key(1);press_key(2);press_key(5);end endtask
    task wait_req;integer n;begin
        n=0;while(!req&&n<3000)begin @(posedge clk);n=n+1;end
        if(!req)$fatal(1,"REQ timeout: digits=%0d pin=%h keyv=%b keyid=%0d auth=%0d armed=%b gesture=%b",
            dut.u_regs.digit_count,dut.u_regs.pin_shift,dut.key_valid,dut.key_id,
            dut.u_auth.state,dut.u_kb.armed,dut.u_kb.gesture_active);
    end endtask
    // Host uses one status pin; after RX it waits a fixed 10000 clk cycles.
    task wait_rsp;begin
        wait_cycles(10000);
        if (!rsp_ready) $fatal(1, "response missing after fixed wait");
        if (req) $fatal(1, "challenge READY stayed high after RX");
    end endtask
    task link_wait;begin wait_cycles(20);end endtask
    task exchange(input [63:0] challenge,input [63:0] expected);
        integer bit_index;reg[63:0]observed;
        begin
            wait_req();
            if(rsp_ready||serial_sdo)$fatal(1,"response exposed before RX");
            serial_cs_n=0;link_wait();
            for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
                serial_sdi=challenge[bit_index];link_wait();
                serial_sclk=1;link_wait();serial_sclk=0;link_wait();
            end
            serial_cs_n=1;link_wait();
            wait_rsp();
            serial_cs_n=0;link_wait();observed=0;
            for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
                link_wait();serial_sclk=1;#1;observed[bit_index]=serial_sdo;
                link_wait();serial_sclk=0;link_wait();
            end
            serial_cs_n=1;link_wait();
            if(observed!==expected)$fatal(1,"response mismatch got=%h expected=%h",observed,expected);
            if(serial_sdo)$fatal(1,"SDO not zero after frame");
            bit_index=0;while(req&&bit_index<100)begin@(posedge clk);bit_index=bit_index+1;end
            if(req||rsp_ready)$fatal(1,"session did not clean up");
            sessions=sessions+1;
        end
    endtask

    initial begin
        repeat(4)@(posedge clk);@(negedge clk);rst_n=1;wait_cycles(160);
        // Physical keypad -> KAT under GOOD.
        enter_good();exchange(64'h656b696c20646e75,64'h44c8fc20b9dfa07a);
        if(dut.u_regs.fail_count!=0)$fatal(1,"GOOD changed attempts");
        // BAD -> GOOD -> BAD -> terminal BAD. Success must not clear failures.
        enter_bad();wait_cycles(200);
        if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"BAD1 created a token");
        if(dut.u_regs.fail_count!=1)$fatal(1,"BAD1 count wrong");
        enter_good();exchange(64'hfedcba9876543210,64'h6879a5ff245ce192);
        if(dut.u_regs.fail_count!=1)$fatal(1,"GOOD cleared failure");
        enter_bad();wait_cycles(200);
        if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"BAD2 created a token");
        if(dut.u_regs.fail_count!=2)$fatal(1,"BAD2 count wrong");
        enter_bad();wait_cycles(200);
        if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"terminal BAD created a token");
        if(dut.u_regs.fail_count!=3||!dut.u_regs.locked)$fatal(1,"terminal BAD lock wrong");
        enter_good();wait_cycles(300);
        if(req)$fatal(1,"new session opened after lock");

        // Cold reset explicitly demonstrates volatile lockout.
        rst_n=0;#1;if(req||rsp_ready||serial_sdo||buzzer_out||(kb_row_oe!=0))$fatal(1,"cold reset pins unsafe");
        wait_cycles(3);@(negedge clk);rst_n=1;wait_cycles(160);
        if(dut.u_regs.fail_count!=0)$fatal(1,"cold demo reset did not clear attempts");

        // ena assertion with the clock stopped clears session but preserves attempts.
        enter_bad();wait_cycles(200);enter_good();wait_req();
        @(negedge clk);run_clk=0;ena=0;#2;
        if(req||rsp_ready||serial_sdo||buzzer_out||(kb_row_oe!=0))$fatal(1,"ena did not mask pins asynchronously");
        if(dut.u_regs.fail_count!=1)$fatal(1,"ena rollback of attempt");
        ena=1;#20;if(req||(kb_row_oe!=0))$fatal(1,"session released without clock");
        run_clk=1;wait_cycles(10);
        if(req||rsp_ready||dut.u_regs.fail_count!=1)$fatal(1,"stale session resumed after ena");
        $display("PASS tb_rumcajs %0d single-key E2E sessions: GOOD, BAD rejection, lock/reset/ena",sessions);
        $finish;
    end
endmodule
