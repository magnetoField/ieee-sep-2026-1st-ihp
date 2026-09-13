`timescale 1ns/1ps
module tb_random_sessions;
    localparam integer VECTOR_COUNT = 256;
    reg clk=0,rst_n=0,ena=1;
    reg [15:0] pressed=0;
    wire [3:0] kb_col_n,kb_row_oe;
    reg serial_sdi=0,serial_sclk=0,serial_cs_n=1;
    wire serial_sdo,req,rsp_ready,buzzer_out;
    reg [129:0] vectors [0:VECTOR_COUNT-1];
    reg [1023:0] vector_file;
    integer count,index,expected_fails,cold_resets,expected_sessions;
    reg watch_rejected = 0;
    integer txn_fires,cmd_fires,seal_fires,session_ends;

    function [3:0] network_columns;
        input [15:0] keys; input [3:0] driven;
        reg [7:0] reached; integer pass,row,col;
        begin
            reached={4'b0,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)
                    for(col=0;col<4;col=col+1)
                        if(keys[4*row+col] && (reached[row]||reached[4+col])) begin
                            reached[row]=1; reached[4+col]=1;
                        end
            network_columns=reached[7:4];
        end
    endfunction
    assign kb_col_n=~network_columns(pressed,kb_row_oe);

    rumcajs #(.CLK_HZ(64000),.SCAN_HZ(4000),.PRESS_FRAMES(1),.RELEASE_FRAMES(1),
        .AUTH_TIMEOUT_MS(500),.BEEP_TICKS_MS(1)) dut(
        clk,rst_n,ena,kb_col_n,kb_row_oe,serial_sdi,serial_sclk,serial_cs_n,
        serial_sdo,req,rsp_ready,buzzer_out);
    always #5 clk=~clk;
    always @(posedge clk) begin
        if (watch_rejected && (req || rsp_ready || serial_sdo || dut.cmd_valid || dut.seal_valid))
            $fatal(1,"rejected PIN authorized traffic");
        if ((kb_row_oe&(kb_row_oe-1))!=0) $fatal(1,"rows not onehot0");
        if (dut.txn_valid && dut.txn_ready) txn_fires=txn_fires+1;
        if (dut.cmd_valid && dut.cmd_ready) cmd_fires=cmd_fires+1;
        if (dut.seal_valid && dut.seal_ready) seal_fires=seal_fires+1;
        if (dut.session_end) session_ends=session_ends+1;
    end

    task wait_cycles(input integer n);integer i;begin for(i=0;i<n;i=i+1)@(posedge clk);end endtask
    task cold_reset;
        begin
            rst_n=0; #1;
            if(req||rsp_ready||serial_sdo||buzzer_out||kb_row_oe)
                $fatal(1,"unsafe pins during cold reset at session %0d",index);
            wait_cycles(3); @(negedge clk); rst_n=1; wait_cycles(160);
            expected_fails=0; cold_resets=cold_resets+1;
            if(dut.u_regs.fail_count!=0)$fatal(1,"cold reset retained attempts");
        end
    endtask
    task press_key(input integer id);
        begin pressed=16'b1<<id;wait_cycles(100);pressed=0;wait_cycles(180);end
    endtask
    task enter_good;begin press_key(0);press_key(1);press_key(2);press_key(4);end endtask
    task enter_bad; begin press_key(0);press_key(1);press_key(2);press_key(5);end endtask
    task link_wait;begin wait_cycles(20);end endtask
    task exchange(input [63:0] challenge,input [63:0] expected);
        integer bit_index,n; reg[63:0]observed;
        begin
            n=0;while(!req&&n<3000)begin@(posedge clk);n=n+1;end
            if(!req)$fatal(1,"REQ timeout session=%0d",index);
            if(dut.u_regs.fail_count!=expected_fails)
                $fatal(1,"attempt scoreboard before REQ got=%0d expected=%0d session=%0d",
                    dut.u_regs.fail_count,expected_fails,index);
            if(rsp_ready||serial_sdo)$fatal(1,"early response session=%0d",index);
            serial_cs_n=0;link_wait();
            for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
                serial_sdi=challenge[bit_index];link_wait();
                serial_sclk=1;link_wait();serial_sclk=0;link_wait();
            end
            serial_cs_n=1;link_wait();
            wait_cycles(10000);
            if(!rsp_ready)$fatal(1,"RSP timeout session=%0d",index);
            serial_cs_n=0;link_wait();observed=0;
            for(bit_index=63;bit_index>=0;bit_index=bit_index-1)begin
                link_wait();serial_sclk=1;#1;observed[bit_index]=serial_sdo;
                link_wait();serial_sclk=0;link_wait();
            end
            serial_cs_n=1;link_wait();
            if(observed!==expected)$fatal(1,"response mismatch session=%0d got=%h expected=%h",index,observed,expected);
            n=0;while(req&&n<100)begin@(posedge clk);n=n+1;end
            if(req||rsp_ready||serial_sdo)$fatal(1,"session did not clean up index=%0d",index);
            if(txn_fires!=expected_sessions||cmd_fires!=expected_sessions||seal_fires!=expected_sessions||session_ends!=expected_sessions)
                $fatal(1,"token/handshake cardinality index=%0d txn=%0d cmd=%0d seal=%0d end=%0d",
                    index,txn_fires,cmd_fires,seal_fires,session_ends);
        end
    endtask

    task unauthorized_frame(input [63:0] challenge);
        integer j;
        begin
            serial_cs_n=0;link_wait();
            for(j=63;j>=0;j=j-1)begin
                serial_sdi=challenge[j];link_wait();
                serial_sclk=1;link_wait();serial_sclk=0;link_wait();
            end
            serial_cs_n=1;link_wait();wait_cycles(10000);
        end
    endtask
    initial begin
        txn_fires=0;cmd_fires=0;seal_fires=0;session_ends=0;
        expected_fails=0;cold_resets=0;count=VECTOR_COUNT;expected_sessions=0;
        if(!$value$plusargs("VECTORS=%s",vector_file))vector_file=".build/session_vectors.mem";
        if(!$value$plusargs("COUNT=%d",count))count=VECTOR_COUNT;
        if(count<1||count>VECTOR_COUNT)$fatal(1,"invalid vector count %0d",count);
        $readmemh(vector_file,vectors);
        cold_reset();
        for(index=0;index<count;index=index+1)begin
            if(vectors[index][129])cold_reset();
            if(vectors[index][128])begin
                enter_good();expected_sessions=expected_sessions+1;
                exchange(vectors[index][127:64],vectors[index][63:0]);
            end else begin
                watch_rejected=1;
                enter_bad();expected_fails=expected_fails+1;
                unauthorized_frame(vectors[index][127:64]);
                watch_rejected=0;
                if(dut.u_regs.fail_count!=expected_fails)$fatal(1,"bad attempt accounting wrong");
            end
            if(expected_fails==3&&!dut.u_regs.locked)$fatal(1,"terminal lock missing session=%0d",index);
            if(expected_fails<3&&dut.u_regs.locked)$fatal(1,"early lock session=%0d",index);
        end
        if(txn_fires!=expected_sessions||cmd_fires!=expected_sessions||seal_fires!=expected_sessions||session_ends!=expected_sessions)
            $fatal(1,"aggregate handshake totals wrong");
        $display("PASS tb_random_sessions count=%0d cold_resets=%0d handshakes=%0d",count,cold_resets,txn_fires);
        $finish;
    end
endmodule
