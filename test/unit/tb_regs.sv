`timescale 1ns/1ps
module tb_regs;
    reg clk=0, cold_rst_n=0, session_rst_n=0, entry_enable=1;
    reg key_valid=0, txn_ready=0, session_end=0;
    reg [3:0] key_id=0;
    wire key_ready, txn_valid, pin_rejected, locked, beep_event, submit_event;
    integer beeps=0;
    regs dut(clk,cold_rst_n,session_rst_n,entry_enable,key_valid,key_ready,key_id,
        txn_valid,txn_ready,session_end,
        locked,beep_event,submit_event,pin_rejected);
    always #5 clk=~clk;
    always @(posedge clk) if (beep_event) beeps=beeps+1;

    task key(input [3:0] id);
        begin
            while(!key_ready) @(posedge clk);
            @(negedge clk); key_id=id; key_valid=1;
            @(posedge clk); @(negedge clk); key_valid=0;
        end
    endtask
    task finish_session;
        begin
            @(negedge clk); txn_ready=1; @(posedge clk); @(negedge clk); txn_ready=0;
            session_end=1; @(posedge clk); @(negedge clk); session_end=0;
        end
    endtask
    task pin1234;
        begin key(0); key(1); key(2); key(4); end
    endtask
    task pin1235;
        begin key(0); key(1); key(2); key(5); end
    endtask

    initial begin
        repeat(2) @(posedge clk); cold_rst_n=1; session_rst_n=1;
        key(12); // star
        key(3);  // A ignored
        if (beeps != 1 || txn_valid) $fatal(1,"special key behavior wrong");
        pin1234();
        if (!txn_valid || dut.fail_count != 0)
            $fatal(1,"GOOD transaction wrong");
        repeat(4) begin
            @(posedge clk); #1;
            if (!txn_valid) $fatal(1,"txn changed under backpressure");
        end
        finish_session();
        pin1235();
        if (txn_valid || dut.fail_count != 1 || dut.session_busy) $fatal(1,"BAD1 wrong");
        session_rst_n=0; #1;
        if (txn_valid || dut.fail_count != 1) $fatal(1,"session reset changed attempts/context wrong");
        session_rst_n=1; repeat(2) @(posedge clk);
        pin1234(); finish_session();
        if (dut.fail_count != 1) $fatal(1,"success cleared attempts");
        pin1235(); finish_session();
        pin1235();
        if (!locked || dut.fail_count != 3 || txn_valid || dut.session_busy)
            $fatal(1,"last BAD transaction/lock wrong");
        finish_session();
        if (key_ready) $fatal(1,"locked accepted another entry");
        cold_rst_n=0; session_rst_n=0; #1;
        if (locked || dut.fail_count != 0) $fatal(1,"cold demo reset failed");
        $display("PASS tb_regs mapping, atomic attempts, resets, BAD rejection, ready-valid"); $finish;
    end
endmodule
