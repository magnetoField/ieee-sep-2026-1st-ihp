`timescale 1ns/1ps
module tb_regs_params #(
    parameter PIN_LEN=1,
    parameter MAX_FAILS=1
);
    reg clk=0,cold_rst_n=0,session_rst_n=0,entry_enable=1,key_valid=0,txn_ready=0,session_end=0;
    reg[3:0]key_id=0;
    wire key_ready,txn_valid,pin_rejected,locked,beep_event,submit_event;
    integer index,attempt;
    regs #(.PIN_LEN(PIN_LEN),.PIN_VALUE(0),.MAX_FAILS(MAX_FAILS)) dut(
        clk,cold_rst_n,session_rst_n,entry_enable,key_valid,key_ready,key_id,
        txn_valid,txn_ready,session_end,
        locked,beep_event,submit_event,pin_rejected);
    always #5 clk=~clk;
    task key(input[3:0]id);begin
        while(!key_ready)@(posedge clk);@(negedge clk);key_id=id;key_valid=1;
        @(posedge clk);@(negedge clk);key_valid=0;
    end endtask
    task finish_session;begin
        txn_ready=1;@(posedge clk);@(negedge clk);txn_ready=0;session_end=1;
        @(posedge clk);@(negedge clk);session_end=0;
    end endtask
    initial begin
        repeat(2)@(posedge clk);@(negedge clk);cold_rst_n=1;session_rst_n=1;
        for(index=0;index<PIN_LEN;index=index+1)key(13); // leading/all zeros
        if(!txn_valid)$fatal(1,"zero PIN failed len=%0d",PIN_LEN);
        finish_session();
        for(attempt=1;attempt<=MAX_FAILS;attempt=attempt+1)begin
            for(index=0;index<PIN_LEN;index=index+1)key(0); // all ones: BAD
            if(txn_valid||dut.fail_count!=attempt)
                $fatal(1,"BAD count failed len=%0d max=%0d attempt=%0d",PIN_LEN,MAX_FAILS,attempt);
            if(locked!=(attempt==MAX_FAILS))$fatal(1,"lock threshold wrong");
            finish_session();
        end
        if(!locked||key_ready)$fatal(1,"lock failed len=%0d max=%0d",PIN_LEN,MAX_FAILS);
        $display("PASS tb_regs_params PIN_LEN=%0d MAX_FAILS=%0d",PIN_LEN,MAX_FAILS);$finish;
    end
endmodule
