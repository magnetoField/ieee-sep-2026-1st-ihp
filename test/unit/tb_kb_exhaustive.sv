`timescale 1ns/1ps
module tb_kb_exhaustive;
    reg clk=0, rst_n=0, enable=1, flush=0, scan_tick=0, key_ready=0;
    reg [15:0] pressed=0;
    wire [3:0] col_n,row_oe;
    wire key_valid;
    wire [3:0] key_id;
    integer mask;

    function [3:0] network_columns;
        input [15:0] keys;
        input [3:0] driven;
        reg [7:0] reached;
        integer pass,row,col;
        begin
            reached={4'b0000,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)
                    for(col=0;col<4;col=col+1)
                        if(keys[4*row+col] && (reached[row] || reached[4+col])) begin
                            reached[row]=1; reached[4+col]=1;
                        end
            network_columns=reached[7:4];
        end
    endfunction
    assign col_n=~network_columns(pressed,row_oe);
    kb #(.PRESS_FRAMES(1),.RELEASE_FRAMES(1)) dut(
        clk,rst_n,enable,flush,scan_tick,col_n,row_oe,key_valid,key_ready,key_id);
    always #1 clk=~clk;
    always @(posedge clk) if ((row_oe & (row_oe-1)) != 0) $fatal(1,"row unsafe mask=%h",pressed);
    task slot;
        begin
            while(row_oe==0) @(posedge clk);
            repeat(2) @(posedge clk);
            @(negedge clk);scan_tick=1;@(posedge clk);@(negedge clk);scan_tick=0;
        end
    endtask
    task frame;
        integer j;
        begin for(j=0;j<4;j=j+1) slot(); end
    endtask
    task reset_gesture;
        begin
            flush=1; @(posedge clk); @(negedge clk); flush=0;
            pressed=0; frame(); // arm
        end
    endtask
    initial begin
        repeat(2) @(posedge clk);rst_n=1;
        for(mask=0;mask<65536;mask=mask+1) begin
            reset_gesture();
            pressed=mask[15:0]; frame();
            pressed=0; frame();
            if(mask!=0 && ((mask & (mask-1))==0)) begin
                if(!key_valid || key_id!=(mask==0 ? 0 : $clog2(mask)))
                    $fatal(1,"single mask failed %h id=%0d valid=%b",mask,key_id,key_valid);
                key_ready=1;@(posedge clk);@(negedge clk);key_ready=0;
            end else if(key_valid) begin
                $fatal(1,"non-single mask accepted %h id=%0d",mask,key_id);
            end
        end
        $display("PASS tb_kb_exhaustive all 65536 physical masks on RTL");$finish;
    end
endmodule
