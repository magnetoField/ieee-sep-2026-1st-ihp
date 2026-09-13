`timescale 1ns/1ps
module tb_auth_states;
    reg clk=0,rst_n=0,ms_tick=0,submit_event=0,txn_valid=0;
    wire txn_ready,session_end,cmd_valid,seal_valid,cipher_abort,rx_arm,tx_arm,link_cancel,req,rsp_ready;
    reg cmd_ready=0,seal_ready=0,cipher_m_valid=0,rx_active=0,tx_active=0;
    reg rx_done=0,tx_done=0,protocol_error=0,frame_start=0;
    integer target,ends,base;
    auth_ctrl #(.AUTH_TIMEOUT_MS(3)) dut(clk,rst_n,ms_tick,
        txn_valid,txn_ready,session_end,
        cmd_valid,cmd_ready,seal_valid,seal_ready,cipher_m_valid,cipher_abort,
        rx_arm,tx_arm,link_cancel,rx_active,tx_active,rx_done,tx_done,
        protocol_error,frame_start,req,rsp_ready);
    always #5 clk=~clk;
    always @(posedge clk)if(session_end)ends=ends+1;
    task clear_inputs;begin
        ms_tick=0;submit_event=0;txn_valid=0;cmd_ready=0;seal_ready=0;
        cipher_m_valid=0;rx_active=0;tx_active=0;rx_done=0;tx_done=0;
        protocol_error=0;frame_start=0;
    end endtask
    task reset_dut;begin
        @(negedge clk);rst_n=0;clear_inputs();#1;
        if(req||rsp_ready||cmd_valid||seal_valid||session_end||dut.state!=0)
            $fatal(1,"reset outputs/state unsafe");
        @(negedge clk);rst_n=1;repeat(2)@(posedge clk);
    end endtask
    task pulse_txn;begin
        @(negedge clk);submit_event=1;txn_valid=1;
        @(posedge clk);@(negedge clk);submit_event=0;txn_valid=0;
        if(dut.state!=1)$fatal(1,"transaction did not enter CMD state=%0d",dut.state);
    end endtask
    task reach_state(input integer wanted);begin
        pulse_txn();
        if(wanted>1)begin
            cmd_ready=1;@(posedge clk);@(negedge clk);cmd_ready=0;
            if(dut.state!=2)$fatal(1,"ARM_RX not reached");
        end
        if(wanted>2)begin @(posedge clk);@(negedge clk);if(dut.state!=3)$fatal(1,"WAIT_RX not reached");end
        if(wanted>3)begin
            rx_active=1;@(posedge clk);@(negedge clk);rx_active=0;
            if(dut.state!=4)$fatal(1,"RX not reached");
        end
        if(wanted>4)begin
            rx_done=1;@(posedge clk);@(negedge clk);rx_done=0;
            if(dut.state!=5)$fatal(1,"SEAL not reached");
        end
        if(wanted>5)begin
            seal_ready=1;@(posedge clk);@(negedge clk);seal_ready=0;
            if(dut.state!=6)$fatal(1,"CRYPT not reached");
        end
        if(wanted>6)begin
            cipher_m_valid=1;@(posedge clk);@(negedge clk);cipher_m_valid=0;
            if(dut.state!=7)$fatal(1,"ARM_TX not reached");
        end
        if(wanted>7)begin @(posedge clk);@(negedge clk);if(dut.state!=8)$fatal(1,"WAIT_TX not reached");end
        if(wanted>8)begin
            tx_active=1;@(posedge clk);@(negedge clk);tx_active=0;
            if(dut.state!=9)$fatal(1,"TX not reached");
        end
        if(dut.state!=wanted)$fatal(1,"wanted state %0d got %0d",wanted,dut.state);
    end endtask
    initial begin
        ends=0;repeat(3)@(posedge clk);@(negedge clk);rst_n=1;repeat(2)@(posedge clk);

        // Regression for an error coincident with a legal IDLE transaction.
        @(negedge clk);protocol_error=1;submit_event=1;txn_valid=1;
        @(posedge clk);@(negedge clk);protocol_error=0;submit_event=0;txn_valid=0;
        if(dut.state!=1||!cmd_valid)$fatal(1,"IDLE error swallowed acknowledged transaction");
        protocol_error=1;@(posedge clk);@(negedge clk);protocol_error=0;
        if(!session_end)$fatal(1,"CMD error did not clean up");
        @(posedge clk);@(negedge clk);

        // Protocol errors abort exactly once from every active state.
        for(target=1;target<=9;target=target+1)begin
            reset_dut();reach_state(target);base=ends;
            protocol_error=1;@(posedge clk);@(negedge clk);protocol_error=0;
            if(!session_end||!cipher_abort||!link_cancel)$fatal(1,"error did not abort state %0d",target);
            @(posedge clk);@(negedge clk);
            if(session_end||dut.state!=0||ends!=base+1)$fatal(1,"error cleanup count state %0d",target);
        end

        // Session reset is asynchronously safe from every active state.
        for(target=1;target<=9;target=target+1)begin
            reset_dut();reach_state(target);rst_n=0;#1;
            if(dut.state!=0||req||rsp_ready||cmd_valid||seal_valid||session_end)
                $fatal(1,"reset failed in state %0d",target);
            @(negedge clk);rst_n=1;repeat(2)@(posedge clk);
        end

        // Timeout wins over a simultaneous otherwise-valid TX completion.
        reset_dut();reach_state(9);
        repeat(2)begin ms_tick=1;@(posedge clk);@(negedge clk);ms_tick=0;end
        base=ends;ms_tick=1;tx_done=1;@(posedge clk);#1;
        if(!session_end||!cipher_abort||dut.state!=10)$fatal(1,"timeout/completion priority wrong");
        @(negedge clk);ms_tick=0;tx_done=0;@(posedge clk);@(negedge clk);
        if(ends!=base+1||session_end)$fatal(1,"timeout generated duplicate cleanup");
        $display("PASS tb_auth_states errors/reset in states 1..9 and timeout completion priority");$finish;
    end
endmodule
