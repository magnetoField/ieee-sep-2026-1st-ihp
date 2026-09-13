`timescale 1ns/1ps
module tb_kb;
    reg clk=0, rst_n=0, enable=0, flush=0, scan_tick=0, key_ready=0;
    reg [15:0] pressed=0;
    wire [3:0] col_n, row_oe;
    wire key_valid;
    wire [3:0] key_id;
    integer events=0;
    reg [3:0] event_id=0;

    function [3:0] network_columns;
        input [15:0] mask;
        input [3:0] driven;
        reg [7:0] reached;
        integer pass,row,col;
        begin
            reached={4'b0000,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)
                    for(col=0;col<4;col=col+1)
                        if(mask[4*row+col] && (reached[row] || reached[4+col])) begin
                            reached[row]=1; reached[4+col]=1;
                        end
            network_columns=reached[7:4];
        end
    endfunction
    assign col_n=~network_columns(pressed,row_oe);
    kb #(.PRESS_FRAMES(2),.RELEASE_FRAMES(2)) dut(
        clk,rst_n,enable,flush,scan_tick,col_n,row_oe,key_valid,key_ready,key_id);
    always #5 clk=~clk;
    always @(posedge clk) begin
        if ((row_oe & (row_oe-1)) != 0) $fatal(1,"row_oe not onehot0");
        if(key_valid && key_ready) begin events=events+1; event_id=key_id; end
    end
    task slot;
        begin
            while(row_oe==0) @(posedge clk);
            repeat(3) @(posedge clk);
            @(negedge clk); scan_tick=1;
            @(posedge clk); @(negedge clk); scan_tick=0;
            if(row_oe!=0) $fatal(1,"missing break-before-make");
        end
    endtask
    task frames(input integer count);
        integer i,j;
        begin for(i=0;i<count;i=i+1) for(j=0;j<4;j=j+1) slot(); end
    endtask
    task consume;
        begin
            @(negedge clk); key_ready=1;
            @(posedge clk); @(negedge clk); key_ready=0;
        end
    endtask
    initial begin
        repeat(2) @(posedge clk); rst_n=1; enable=1;
        frames(2); // arm on stable release
        pressed=1<<6; frames(2); // qualify key 6
        frames(4); // held: no autorepeat and no event before release
        if(key_valid || events) $fatal(1,"event before release/autorepeat");
        pressed=0; frames(2);
        if(!key_valid || key_id!=6) $fatal(1,"single key event wrong");
        frames(2); if(!key_valid || key_id!=6) $fatal(1,"pending not stable");
        consume(); if(events!=1 || event_id!=6) $fatal(1,"handshake count wrong");
        frames(2);
        // Poison a gesture: ONE -> ghosting rectangle -> ONE -> release.
        pressed=1<<0; frames(2);
        pressed=(1<<0)|(1<<1)|(1<<4); frames(1);
        pressed=1<<0; frames(1);
        pressed=0; frames(2);
        if(key_valid || events!=1) $fatal(1,"poisoned gesture accepted");
        // Disable does not withdraw an already pending event.
        pressed=0; frames(2); pressed=1<<13; frames(2); pressed=0; frames(2);
        if(!key_valid || key_id!=13) $fatal(1,"second event missing");
        enable=0; repeat(3) @(posedge clk);
        if(!key_valid || row_oe!=0) $fatal(1,"disable pending/row policy wrong");
        consume(); if(events!=2) $fatal(1,"pending not consumable while disabled, events=%0d",events);
        $display("PASS tb_kb release emission, poison, no autorepeat, ready-valid, row safety"); $finish;
    end
endmodule
