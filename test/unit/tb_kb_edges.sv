`timescale 1ns/1ps
module tb_kb_edges;
    reg clk=0,rst_n=0,enable=1,flush=0,scan_tick=0,key_ready=0;
    reg[15:0]pressed=0;
    wire[3:0]col_n,row_oe;wire key_valid;wire[3:0]key_id;
    integer events,last_id,a,b,r0,r1,c0,c1,omit,mask;
    function[3:0]network_columns;
        input[15:0]keys;input[3:0]driven;reg[7:0]reached;integer pass,row,col;
        begin
            reached={4'b0,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)for(col=0;col<4;col=col+1)
                    if(keys[4*row+col]&&(reached[row]||reached[4+col]))begin
                        reached[row]=1;reached[4+col]=1;
                    end
            network_columns=reached[7:4];
        end
    endfunction
    assign col_n=~network_columns(pressed,row_oe);
    kb #(.PRESS_FRAMES(3),.RELEASE_FRAMES(3)) dut(
        clk,rst_n,enable,flush,scan_tick,col_n,row_oe,key_valid,key_ready,key_id);
    always #5 clk=~clk;
    always @(posedge clk)begin
        if((row_oe&(row_oe-1))!=0)$fatal(1,"row_oe not onehot0");
        if(key_valid&&key_ready)begin events=events+1;last_id=key_id;end
    end
    task slot;begin
        while(row_oe==0)@(posedge clk);repeat(3)@(posedge clk);
        @(negedge clk);scan_tick=1;@(posedge clk);@(negedge clk);scan_tick=0;
        if(row_oe!=0)$fatal(1,"break-before-make absent");
    end endtask
    task frames(input integer count);integer i,j;begin
        for(i=0;i<count;i=i+1)for(j=0;j<4;j=j+1)slot();
    end endtask
    task fresh;begin
        pressed=0;@(negedge clk);flush=1;@(posedge clk);@(negedge clk);flush=0;frames(3);
        if(key_valid)$fatal(1,"fresh setup left pending event");
    end endtask
    task consume;begin
        @(negedge clk);key_ready=1;@(posedge clk);@(negedge clk);key_ready=0;
    end endtask
    task rejected_mask(input[15:0]value);begin
        fresh();pressed=value;frames(3);pressed=0;frames(3);
        if(key_valid)$fatal(1,"multi mask accepted %h",value);
    end endtask
    initial begin
        events=0;last_id=-1;repeat(3)@(posedge clk);@(negedge clk);rst_n=1;

        // Exact PRESS=N-1/N/N+1 and RELEASE=M-1/M boundaries.
        fresh();pressed=1<<6;frames(2);pressed=0;frames(3);
        if(key_valid)$fatal(1,"PRESS N-1 accepted");
        fresh();pressed=1<<6;frames(3);pressed=0;frames(2);
        if(key_valid)$fatal(1,"RELEASE M-1 emitted");
        frames(1);if(!key_valid||key_id!=6)$fatal(1,"PRESS N / RELEASE M missing");consume();
        fresh();pressed=1<<6;frames(4);pressed=0;frames(3);
        if(!key_valid||key_id!=6)$fatal(1,"PRESS N+1 failed");consume();

        // Every physical key produces exactly its own ID after release.
        for(a=0;a<16;a=a+1)begin
            fresh();pressed=16'b1<<a;frames(3);pressed=0;frames(3);
            if(!key_valid||key_id!=a)$fatal(1,"key id %0d failed got=%0d",a,key_id);
            consume();frames(3);if(key_valid)$fatal(1,"key %0d autorepeated",a);
        end

        // All unordered pairs are rejected for the entire gesture.
        for(a=0;a<16;a=a+1)for(b=a+1;b<16;b=b+1)
            rejected_mask((16'b1<<a)|(16'b1<<b));

        // Every rectangle: each three-corner ghost and the full rectangle.
        for(r0=0;r0<4;r0=r0+1)for(r1=r0+1;r1<4;r1=r1+1)
            for(c0=0;c0<4;c0=c0+1)for(c1=c0+1;c1<4;c1=c1+1)begin
                mask=(1<<(4*r0+c0))|(1<<(4*r0+c1))|(1<<(4*r1+c0))|(1<<(4*r1+c1));
                rejected_mask(mask[15:0]);
                for(omit=0;omit<4;omit=omit+1)
                    rejected_mask((mask^(1<<(omit[1]?4*r1:4*r0)+(omit[0]?c1:c0)))&16'hffff);
            end

        // Candidate changes, late chords and release interruption poison forever.
        fresh();pressed=1<<0;frames(3);pressed=1<<1;frames(1);pressed=0;frames(3);
        if(key_valid)$fatal(1,"ONE(A)->ONE(B) rescued");
        fresh();pressed=1<<0;frames(2);pressed=(1<<0)|(1<<1);frames(1);
        pressed=1<<0;frames(2);pressed=0;frames(3);
        if(key_valid)$fatal(1,"late debounce chord rescued");
        fresh();pressed=1<<0;frames(3);pressed=0;frames(2);
        pressed=(1<<0)|(1<<4);frames(1);pressed=0;frames(3);
        if(key_valid)$fatal(1,"release-time chord rescued");

        // Bounce can delay qualification/release but cannot duplicate it.
        fresh();pressed=1<<9;frames(1);pressed=0;frames(1);pressed=1<<9;frames(1);
        pressed=0;frames(1);pressed=1<<9;frames(3);pressed=0;frames(1);
        pressed=1<<9;frames(1);pressed=0;frames(3);
        if(!key_valid||key_id!=9)$fatal(1,"legal bounced gesture missing");
        a=events;consume();frames(6);if(events!=a+1||key_valid)$fatal(1,"bounce duplicated event");

        // Flush and disable while held require a fresh stable release afterward.
        fresh();pressed=1<<2;frames(3);flush=1;@(posedge clk);@(negedge clk);flush=0;
        frames(4);if(key_valid)$fatal(1,"held key survived flush");pressed=0;frames(3);
        if(key_valid)$fatal(1,"release after flush created event");
        pressed=1<<2;frames(3);enable=0;repeat(6)@(posedge clk);
        if(row_oe||key_valid)$fatal(1,"disable unsafe");enable=1;frames(4);
        if(key_valid)$fatal(1,"held key survived disable");pressed=0;frames(3);

        // Pending payload is immutable; activity while full cannot become next input.
        pressed=1<<3;frames(3);pressed=0;frames(3);
        if(!key_valid||key_id!=3)$fatal(1,"pending setup missing");
        pressed=1<<7;frames(6);if(!key_valid||key_id!=3)$fatal(1,"pending overwritten");
        consume();frames(4);if(key_valid)$fatal(1,"held-during-pending leaked");
        pressed=0;frames(3);key_ready=1;frames(2);key_ready=0;
        if(key_valid)$fatal(1,"ready without valid created event");

        $display("PASS tb_kb_edges debounce, 16 keys, 120 pairs, 180 rectangle masks, poison/reset/pending");$finish;
    end
endmodule
