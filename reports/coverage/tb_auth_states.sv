//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_auth_states;
 000446     reg clk=0,rst_n=0,ms_tick=0,submit_event=0,txn_valid=0;
 000041     wire txn_ready,session_end,cmd_valid,seal_valid,cipher_abort,rx_arm,tx_arm,link_cancel,req,rsp_ready;
 000034     reg cmd_ready=0,seal_ready=0,cipher_m_valid=0,rx_active=0,tx_active=0;
~000022     reg rx_done=0,tx_done=0,protocol_error=0,frame_start=0;
            integer target,ends,base;
            auth_ctrl #(.AUTH_TIMEOUT_MS(3)) dut(clk,rst_n,ms_tick,
                txn_valid,txn_ready,session_end,
                cmd_valid,cmd_ready,seal_valid,seal_ready,cipher_m_valid,cipher_abort,
                rx_arm,tx_arm,link_cancel,rx_active,tx_active,rx_done,tx_done,
                protocol_error,frame_start,req,rsp_ready);
 000446     always #5 clk=~clk;
 000223     always @(posedge clk)if(session_end)ends=ends+1;
 000019     task clear_inputs;begin
 000019         ms_tick=0;submit_event=0;txn_valid=0;cmd_ready=0;seal_ready=0;
 000019         cipher_m_valid=0;rx_active=0;tx_active=0;rx_done=0;tx_done=0;
 000019         protocol_error=0;frame_start=0;
            end endtask
 000019     task reset_dut;begin
 000019         @(negedge clk);rst_n=0;clear_inputs();#1;
 000019         if(req||rsp_ready||cmd_valid||seal_valid||session_end||dut.state!=0)
                    $fatal(1,"reset outputs/state unsafe");
 000038         @(negedge clk);rst_n=1;repeat(2)@(posedge clk);
            end endtask
 000019     task pulse_txn;begin
 000019         @(negedge clk);submit_event=1;txn_valid=1;
 000019         @(posedge clk);@(negedge clk);submit_event=0;txn_valid=0;
 000019         if(dut.state!=1)$fatal(1,"transaction did not enter CMD state=%0d",dut.state);
            end endtask
 000019     task reach_state(input integer wanted);begin
 000019         pulse_txn();
 000017         if(wanted>1)begin
 000017             cmd_ready=1;@(posedge clk);@(negedge clk);cmd_ready=0;
 000017             if(dut.state!=2)$fatal(1,"ARM_RX not reached");
                end
 000015         if(wanted>2)begin @(posedge clk);@(negedge clk);if(dut.state!=3)$fatal(1,"WAIT_RX not reached");end
 000013         if(wanted>3)begin
 000013             rx_active=1;@(posedge clk);@(negedge clk);rx_active=0;
 000013             if(dut.state!=4)$fatal(1,"RX not reached");
                end
 000011         if(wanted>4)begin
 000011             rx_done=1;@(posedge clk);@(negedge clk);rx_done=0;
 000011             if(dut.state!=5)$fatal(1,"SEAL not reached");
                end
 000010         if(wanted>5)begin
 000009             seal_ready=1;@(posedge clk);@(negedge clk);seal_ready=0;
 000009             if(dut.state!=6)$fatal(1,"CRYPT not reached");
                end
 000012         if(wanted>6)begin
 000007             cipher_m_valid=1;@(posedge clk);@(negedge clk);cipher_m_valid=0;
 000007             if(dut.state!=7)$fatal(1,"ARM_TX not reached");
                end
 000014         if(wanted>7)begin @(posedge clk);@(negedge clk);if(dut.state!=8)$fatal(1,"WAIT_TX not reached");end
 000016         if(wanted>8)begin
 000003             tx_active=1;@(posedge clk);@(negedge clk);tx_active=0;
 000003             if(dut.state!=9)$fatal(1,"TX not reached");
                end
 000019         if(dut.state!=wanted)$fatal(1,"wanted state %0d got %0d",wanted,dut.state);
            end endtask
 000001     initial begin
 000003         ends=0;repeat(3)@(posedge clk);@(negedge clk);rst_n=1;repeat(2)@(posedge clk);
        
                // Regression for an error coincident with a legal IDLE transaction.
 000001         @(negedge clk);protocol_error=1;submit_event=1;txn_valid=1;
 000001         @(posedge clk);@(negedge clk);protocol_error=0;submit_event=0;txn_valid=0;
 000001         if(dut.state!=1||!cmd_valid)$fatal(1,"IDLE error swallowed acknowledged transaction");
 000001         protocol_error=1;@(posedge clk);@(negedge clk);protocol_error=0;
 000001         if(!session_end)$fatal(1,"CMD error did not clean up");
 000001         @(posedge clk);@(negedge clk);
        
                // Protocol errors abort exactly once from every active state.
 000009         for(target=1;target<=9;target=target+1)begin
 000009             reset_dut();reach_state(target);base=ends;
 000009             protocol_error=1;@(posedge clk);@(negedge clk);protocol_error=0;
 000009             if(!session_end||!cipher_abort||!link_cancel)$fatal(1,"error did not abort state %0d",target);
 000009             @(posedge clk);@(negedge clk);
 000009             if(session_end||dut.state!=0||ends!=base+1)$fatal(1,"error cleanup count state %0d",target);
                end
        
                // Session reset is asynchronously safe from every active state.
 000009         for(target=1;target<=9;target=target+1)begin
 000009             reset_dut();reach_state(target);rst_n=0;#1;
 000009             if(dut.state!=0||req||rsp_ready||cmd_valid||seal_valid||session_end)
                        $fatal(1,"reset failed in state %0d",target);
 000018             @(negedge clk);rst_n=1;repeat(2)@(posedge clk);
                end
        
                // Timeout wins over a simultaneous otherwise-valid TX completion.
 000001         reset_dut();reach_state(9);
 000002         repeat(2)begin ms_tick=1;@(posedge clk);@(negedge clk);ms_tick=0;end
 000001         base=ends;ms_tick=1;tx_done=1;@(posedge clk);#1;
 000001         if(!session_end||!cipher_abort||dut.state!=10)$fatal(1,"timeout/completion priority wrong");
 000001         @(negedge clk);ms_tick=0;tx_done=0;@(posedge clk);@(negedge clk);
 000001         if(ends!=base+1||session_end)$fatal(1,"timeout generated duplicate cleanup");
 000001         $display("PASS tb_auth_states errors/reset in states 1..9 and timeout completion priority");$finish;
            end
        endmodule
        
