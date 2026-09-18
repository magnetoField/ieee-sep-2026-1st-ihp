`timescale 1ns/1ps
module tb_buzzer_symmetry;
    reg clk=0,cold_rst_n=0,session_rst_n=0,key_valid=0,ms_tick=0,scan_tick=0;
    reg[3:0]good_id=15,bad_id=15;
    wire gr,br,gv,bv,greject,breject,glock,block,gbeep,bbeep,gsubmit,bsubmit;
    wire gout,bout,gbusy,bbusy;
    integer cycle,index;
    regs good_regs(clk,cold_rst_n,session_rst_n,1'b1,key_valid,gr,good_id,
        gv,1'b0,1'b0,glock,gbeep,gsubmit,greject);
    regs bad_regs(clk,cold_rst_n,session_rst_n,1'b1,key_valid,br,bad_id,
        bv,1'b0,1'b0,block,bbeep,bsubmit,breject);
    buzzer #(.BEEP_TICKS_MS(3),.TONE_HALF_TICKS(2)) good_buzzer(
        clk,session_rst_n,ms_tick,scan_tick,gbeep,gout,gbusy);
    buzzer #(.BEEP_TICKS_MS(3),.TONE_HALF_TICKS(2)) bad_buzzer(
        clk,session_rst_n,ms_tick,scan_tick,bbeep,bout,bbusy);
    always #5 clk=~clk;
    always @(posedge clk)if(session_rst_n)begin
        cycle=cycle+1;
        if(gbeep!==bbeep)$fatal(1,"beep events differ at sampling edge");
        #1;if(gout!==bout||gbusy!==bbusy)
            $fatal(1,"GOOD/BAD audible trace diverged cycle=%0d",cycle);
    end
    function[3:0]gid;input integer pos;begin case(pos)0:gid=0;1:gid=1;2:gid=2;default:gid=4;endcase end endfunction
    function[3:0]bid;input integer pos;begin case(pos)0:bid=0;1:bid=1;2:bid=2;default:bid=5;endcase end endfunction
    task key_pair(input integer pos);begin
        @(negedge clk);good_id=gid(pos);bad_id=bid(pos);key_valid=1;scan_tick=1;
        @(posedge clk);@(negedge clk);key_valid=0;scan_tick=0;
        repeat(2)begin ms_tick=1;scan_tick=1;@(posedge clk);@(negedge clk);ms_tick=0;scan_tick=0;end
        repeat(2)@(posedge clk);
    end endtask
    initial begin
        cycle=0;repeat(2)@(posedge clk);@(negedge clk);cold_rst_n=1;session_rst_n=1;
        for(index=0;index<4;index=index+1)key_pair(index);
        if(!gv||bv||good_regs.fail_count!=0||bad_regs.fail_count!=1)
            $fatal(1,"PIN outcomes not distinct as expected");
        repeat(5)begin ms_tick=1;scan_tick=1;@(posedge clk);@(negedge clk);ms_tick=0;scan_tick=0;end
        if(gout||bout||gbusy||bbusy)$fatal(1,"beeps did not end symmetrically");
        $display("PASS tb_buzzer_symmetry GOOD/BAD PINs have identical audible control trace");$finish;
    end
endmodule
