`timescale 1ns/1ps
module tb_auth_ctrl;
    reg clk=0,rst_n=0,ms_tick=0,txn_valid=0;
    wire txn_ready,session_end,cmd_valid,seal_valid,cipher_abort,rx_arm,tx_arm,link_cancel,req,rsp_ready;
    reg cmd_ready=0,seal_ready=0,cipher_m_valid=0,rx_active=0,tx_active=0;
    reg rx_done=0,tx_done=0,protocol_error=0,frame_start=0;
    integer ends=0,cmds=0,seals=0;
    auth_ctrl #(.AUTH_TIMEOUT_MS(3)) dut(clk,rst_n,ms_tick,
        txn_valid,txn_ready,session_end,
        cmd_valid,cmd_ready,seal_valid,seal_ready,cipher_m_valid,cipher_abort,
        rx_arm,tx_arm,link_cancel,rx_active,tx_active,rx_done,tx_done,
        protocol_error,frame_start,req,rsp_ready);
    always #5 clk=~clk;
    always @(posedge clk) begin
        if(session_end) ends=ends+1;
        if(cmd_valid&&cmd_ready) cmds=cmds+1;
        if(seal_valid&&seal_ready) seals=seals+1;
    end
    task pulse_submit;
        begin
            @(negedge clk);txn_valid=1;
            @(posedge clk);@(negedge clk);txn_valid=0;
        end
    endtask
    task pulse(input integer which);
        begin
            @(negedge clk);
            case(which)
                0:rx_done=1;1:tx_done=1;2:protocol_error=1;3:frame_start=1;4:ms_tick=1;
            endcase
            @(posedge clk);@(negedge clk);
            rx_done=0;tx_done=0;protocol_error=0;frame_start=0;ms_tick=0;
        end
    endtask
    initial begin
        repeat(2)@(posedge clk);@(negedge clk);rst_n=1;
        // External traffic without token does nothing.
        pulse(3);if(cmds||req)$fatal(1,"idle frame created session");
        pulse_submit();
        if(!cmd_valid||req)$fatal(1,"GOOD cmd context wrong");
        repeat(3)@(posedge clk);if(!cmd_valid||cmds)$fatal(1,"cmd did not wait");
        @(negedge clk);cmd_ready=1;@(posedge clk);@(negedge clk);cmd_ready=0;
        if(!rx_arm)$fatal(1,"rx arm missing");
        @(posedge clk);@(negedge clk);if(!req||rsp_ready)$fatal(1,"REQ phase wrong");
        rx_active=1;@(posedge clk);@(negedge clk);rx_active=0;
        pulse(0);if(!seal_valid)$fatal(1,"seal phase missing");
        repeat(2)@(posedge clk);if(seals)$fatal(1,"seal did not wait ready");
        @(negedge clk);seal_ready=1;@(posedge clk);@(negedge clk);seal_ready=0;
        if(req||rsp_ready)$fatal(1,"crypt outputs wrong");
        cipher_m_valid=1;@(posedge clk);@(negedge clk);
        if(!tx_arm||!rsp_ready||req)$fatal(1,"TX arm/readiness wrong");
        cipher_m_valid=0;@(posedge clk);@(negedge clk);
        tx_active=1;@(posedge clk);@(negedge clk);
        pulse(1);tx_active=0;
        if(!session_end||!cipher_abort||!link_cancel)$fatal(1,"cleanup controls missing");
        @(posedge clk);@(negedge clk);if(req||rsp_ready||session_end)$fatal(1,"cleanup did not end");
        if(cmds!=1||seals!=1||ends!=1)$fatal(1,"event counts wrong cmd=%0d seal=%0d end=%0d",cmds,seals,ends);

        // Only authorized tokens arrive here; timeout is absolute from admission.
        pulse_submit();
        cmd_ready=1;@(posedge clk);@(negedge clk);cmd_ready=0;@(posedge clk);@(negedge clk);
        pulse(4);pulse(4); // movement does not restart timeout
        rx_active=1;@(posedge clk);@(negedge clk);rx_active=0;
        pulse(4);
        if(!session_end||!cipher_abort)$fatal(1,"absolute timeout missing");
        @(posedge clk);@(negedge clk);
        if(ends!=2||cmds!=2)$fatal(1,"terminal/timeout duplicate or lost");

        // Unexpected frame during crypt aborts one token.
        pulse_submit();cmd_ready=1;@(posedge clk);@(negedge clk);cmd_ready=0;
        @(posedge clk);@(negedge clk);rx_active=1;@(posedge clk);@(negedge clk);rx_active=0;
        pulse(0);@(negedge clk);seal_ready=1;@(posedge clk);@(negedge clk);seal_ready=0;
        pulse(3);if(!session_end)$fatal(1,"unexpected frame not aborted");
        $display("PASS tb_auth_ctrl token, handshakes, absolute timeout, errors");$finish;
    end
endmodule
