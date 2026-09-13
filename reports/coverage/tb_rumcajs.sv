//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_rumcajs;
 091833     reg clk=0,rst_n=0,ena=1,run_clk=1;
~000016     reg [15:0] pressed=0;
 001439     wire [3:0] kb_col_n,kb_row_oe;
 000512     reg serial_sdi=0,serial_sclk=0,serial_cs_n=1;
 000128     wire serial_sdo,req,rsp_ready,buzzer_out;
 000001     integer sessions=0;
        
 275772     function [3:0] network_columns;
                input [15:0] keys; input [3:0] driven;
                reg [7:0] reached; integer pass,row,col;
 275772         begin
 275772             reached={4'b0,driven};
 2206176             for(pass=0;pass<8;pass=pass+1)
 8824704                 for(row=0;row<4;row=row+1)
 35298816                     for(col=0;col<4;col=col+1)
 35264544                         if(keys[4*row+col] && (reached[row]||reached[4+col])) begin
 034272                             reached[row]=1;reached[4+col]=1;
                                end
 275772             network_columns=reached[7:4];
                end
            endfunction
            assign kb_col_n=~network_columns(pressed,kb_row_oe);
        
            rumcajs #(.CLK_HZ(64000),.SCAN_HZ(4000),.PRESS_FRAMES(1),.RELEASE_FRAMES(1),
                .AUTH_TIMEOUT_MS(500),.BEEP_TICKS_MS(2)) dut(
                clk,rst_n,ena,kb_col_n,kb_row_oe,serial_sdi,serial_sclk,serial_cs_n,
                serial_sdo,req,rsp_ready,buzzer_out);
 091837     always begin #5;if(run_clk)clk=~clk;end
 045917     always @(posedge clk) if((kb_row_oe&(kb_row_oe-1))!=0)$fatal(1,"rows not onehot0");
        
 045913     task wait_cycles(input integer count);integer n;begin for(n=0;n<count;n=n+1)@(posedge clk);end endtask
 000032     task press_key(input integer id);
 000032         begin pressed=16'b1<<id;wait_cycles(100);pressed=0;wait_cycles(180);end
            endtask
 000004     task enter_good;begin press_key(0);press_key(1);press_key(2);press_key(4);end endtask
 000004     task enter_bad; begin press_key(0);press_key(1);press_key(2);press_key(5);end endtask
 000003     task wait_req;integer n;begin
~000003         n=0;while(!req&&n<3000)begin @(posedge clk);n=n+1;end
 000003         if(!req)$fatal(1,"REQ timeout: digits=%0d pin=%h keyv=%b keyid=%0d auth=%0d armed=%b gesture=%b",
                    dut.u_regs.digit_count,dut.u_regs.pin_shift,dut.key_valid,dut.key_id,
                    dut.u_auth.state,dut.u_kb.armed,dut.u_kb.gesture_active);
            end endtask
            // Host uses one status pin; after RX it waits a fixed 10000 clk cycles.
 000002     task wait_rsp;begin
 000002         wait_cycles(10000);
 000002         if (!rsp_ready) $fatal(1, "response missing after fixed wait");
 000002         if (req) $fatal(1, "challenge READY stayed high after RX");
            end endtask
 000776     task link_wait;begin wait_cycles(20);end endtask
 000002     task exchange(input [63:0] challenge,input [63:0] expected);
                integer bit_index;reg[63:0]observed;
 000002         begin
 000002             wait_req();
 000002             if(rsp_ready||serial_sdo)$fatal(1,"response exposed before RX");
 000002             serial_cs_n=0;link_wait();
 000128             for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
 000128                 serial_sdi=challenge[bit_index];link_wait();
 000128                 serial_sclk=1;link_wait();serial_sclk=0;link_wait();
                    end
 000002             serial_cs_n=1;link_wait();
 000002             wait_rsp();
 000002             serial_cs_n=0;link_wait();observed=0;
 000128             for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
 000128                 link_wait();serial_sclk=1;#1;observed[bit_index]=serial_sdo;
 000128                 link_wait();serial_sclk=0;link_wait();
                    end
 000002             serial_cs_n=1;link_wait();
 000002             if(observed!==expected)$fatal(1,"response mismatch got=%h expected=%h",observed,expected);
 000002             if(serial_sdo)$fatal(1,"SDO not zero after frame");
~000002             bit_index=0;while(req&&bit_index<100)begin@(posedge clk);bit_index=bit_index+1;end
 000002             if(req||rsp_ready)$fatal(1,"session did not clean up");
 000002             sessions=sessions+1;
                end
            endtask
        
 000001     initial begin
 000004         repeat(4)@(posedge clk);@(negedge clk);rst_n=1;wait_cycles(160);
                // Physical keypad -> KAT under GOOD.
 000001         enter_good();exchange(64'h656b696c20646e75,64'h44c8fc20b9dfa07a);
 000001         if(dut.u_regs.fail_count!=0)$fatal(1,"GOOD changed attempts");
                // BAD -> GOOD -> BAD -> terminal BAD. Success must not clear failures.
 000001         enter_bad();wait_cycles(200);
 000001         if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"BAD1 created a token");
 000001         if(dut.u_regs.fail_count!=1)$fatal(1,"BAD1 count wrong");
 000001         enter_good();exchange(64'hfedcba9876543210,64'h6879a5ff245ce192);
 000001         if(dut.u_regs.fail_count!=1)$fatal(1,"GOOD cleared failure");
 000001         enter_bad();wait_cycles(200);
 000001         if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"BAD2 created a token");
 000001         if(dut.u_regs.fail_count!=2)$fatal(1,"BAD2 count wrong");
 000001         enter_bad();wait_cycles(200);
 000001         if(req||rsp_ready||dut.cmd_valid||dut.txn_valid)$fatal(1,"terminal BAD created a token");
 000001         if(dut.u_regs.fail_count!=3||!dut.u_regs.locked)$fatal(1,"terminal BAD lock wrong");
 000001         enter_good();wait_cycles(300);
 000001         if(req)$fatal(1,"new session opened after lock");
        
                // Cold reset explicitly demonstrates volatile lockout.
 000001         rst_n=0;#1;if(req||rsp_ready||serial_sdo||buzzer_out||(kb_row_oe!=0))$fatal(1,"cold reset pins unsafe");
 000001         wait_cycles(3);@(negedge clk);rst_n=1;wait_cycles(160);
 000001         if(dut.u_regs.fail_count!=0)$fatal(1,"cold demo reset did not clear attempts");
        
                // ena assertion with the clock stopped clears session but preserves attempts.
 000001         enter_bad();wait_cycles(200);enter_good();wait_req();
 000001         @(negedge clk);run_clk=0;ena=0;#2;
 000001         if(req||rsp_ready||serial_sdo||buzzer_out||(kb_row_oe!=0))$fatal(1,"ena did not mask pins asynchronously");
 000001         if(dut.u_regs.fail_count!=1)$fatal(1,"ena rollback of attempt");
 000001         ena=1;#20;if(req||(kb_row_oe!=0))$fatal(1,"session released without clock");
 000001         run_clk=1;wait_cycles(10);
 000001         if(req||rsp_ready||dut.u_regs.fail_count!=1)$fatal(1,"stale session resumed after ena");
 000001         $display("PASS tb_rumcajs %0d single-key E2E sessions: GOOD, BAD rejection, lock/reset/ena",sessions);
 000001         $finish;
            end
        endmodule
        
