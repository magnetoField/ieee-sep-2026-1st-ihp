//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_timebase_params;
 002003     reg clk=0,rst_n=0;
 000124     wire s1,m1,s6,m6,sd,md;
 000001     integer cycles=0,c_s1=0,c_m1=0,c_s6=0,c_m6=0,c_sd=0,c_md=0;
 000124     reg ps1=0,pm1=0,ps6=0,pm6=0,psd=0,pmd=0;
            timebase #(.CLK_HZ(16000),.SCAN_HZ(1000)) div1(clk,rst_n,s1,m1);
            timebase #(.CLK_HZ(96000),.SCAN_HZ(6000)) div6(clk,rst_n,s6,m6);
            timebase defaults(clk,rst_n,sd,md);
 002003     always #5 clk=~clk;
 001002     always @(posedge clk) if(rst_n)begin
 001000         cycles=cycles+1;#1;
 001000         if((s1&&ps1)||(m1&&pm1)||(s6&&ps6)||(m6&&pm6)||(sd&&psd)||(md&&pmd))
                    $fatal(1,"tick wider than one clock");
 000938         if(s1)c_s1=c_s1+1;if(m1)c_m1=c_m1+1;
 000990         if(s6)c_s6=c_s6+1;if(m6)c_m6=c_m6+1;
 000999         if(sd)c_sd=c_sd+1;if(md)c_md=c_md+1;
 001000         if(m1&&!s1||m6&&!s6||md&&!sd)$fatal(1,"ms tick not aligned to scan tick");
 001000         ps1=s1;pm1=m1;ps6=s6;pm6=m6;psd=sd;pmd=md;
            end
 000001     initial begin
 000002         repeat(2)@(posedge clk);@(negedge clk);rst_n=1;
 001000         repeat(1000)@(posedge clk);#2;
 000001         if(c_s1!=62||c_m1!=62)$fatal(1,"DIV16/MS1 totals wrong %0d/%0d",c_s1,c_m1);
 000001         if(c_s6!=62||c_m6!=10)$fatal(1,"DIV16/MS6 totals wrong %0d/%0d",c_s6,c_m6);
 000001         if(c_sd!=4||c_md!=1)$fatal(1,"default totals wrong %0d/%0d",c_sd,c_md);
 000001         rst_n=0;#1;if(s1||m1||s6||m6||sd||md)$fatal(1,"reset outputs unsafe");
 000001         $display("PASS tb_timebase_params valid dividers and default 1MHz/4kHz");$finish;
            end
        endmodule
        
