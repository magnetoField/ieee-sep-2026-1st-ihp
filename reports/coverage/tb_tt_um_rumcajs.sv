//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_tt_um_rumcajs;
 1227568     reg clk=0,rst_n=0,ena=1;
~000001     reg [3:0] upper_ui=0;
 613781     reg [7:0] uio_in=0;
~000004     reg [15:0] pressed=0;
 613781     reg sdi=0,sclk=0,cs_n=1,unused_ui7=0;
~613781     wire [7:0] ui_in,uo_out,uio_out,uio_oe;
 000137     wire [3:0] columns;
            assign ui_in={unused_ui7,cs_n,sclk,sdi,columns};
        
 3682706     function [3:0] network_columns;
                input [15:0] keys;input[3:0]driven;
                reg[7:0]reached;integer pass,row,col;
 3682706         begin
 3682706             reached={4'b0,driven};
 29461648             for(pass=0;pass<8;pass=pass+1)
 117846592                 for(row=0;row<4;row=row+1)
 471386368                     for(col=0;col<4;col=col+1)
 469282816                         if(keys[4*row+col]&&(reached[row]||reached[4+col]))begin
 2103552                             reached[row]=1;reached[4+col]=1;
                                end
 3682706             network_columns=reached[7:4];
                end
            endfunction
            assign columns=~network_columns(pressed,uio_oe[3:0]);
            tt_um_rumcajs dut(ui_in,uo_out,uio_in,uio_out,uio_oe,ena,clk,rst_n);
 1227568     always #1 clk=~clk;
            // Exercise every unused wrapper input continuously through all protocol phases.
 613784     always @(negedge clk) if(rst_n)begin
 613781         unused_ui7<=~unused_ui7;
 613781         uio_in<=uio_in+8'h3d;
            end
 613784     always @(posedge clk) begin
 613784         if(uio_out!==0||uio_oe[7:4]!==0||uo_out[7:4]!==0||uo_out[1]!==0)$fatal(1,"reserved pin unsafe");
 613784         if((uio_oe[3:0]&(uio_oe[3:0]-1))!=0)$fatal(1,"wrapper rows not onehot0");
            end
 613784     task cycles(input integer n);integer i;begin for(i=0;i<n;i=i+1)@(posedge clk);end endtask
 000008     task press(input integer id);begin pressed=16'b1<<id;cycles(22000);pressed=0;cycles(45000);end endtask
 000001     task good_pin;begin press(0);press(1);press(2);press(4);end endtask
 000001     task bad_pin;begin press(0);press(1);press(2);press(5);end endtask
 000388     task bus_wait;begin cycles(20);end endtask
 000001     task exchange(input[63:0]challenge,input[63:0]expected);
                integer i,n;reg[63:0]got;
 000001         begin
~000001             n=0;while(!uo_out[0]&&n<5000)begin@(posedge clk);n=n+1;end
 000001             if(!uo_out[0])$fatal(1,"wrapper REQ missing digits=%0d pin=%h keyid=%0d armed=%b gesture=%b",
                        dut.u_rumcajs.u_regs.digit_count,dut.u_rumcajs.u_regs.pin_shift,
                        dut.u_rumcajs.key_id,dut.u_rumcajs.u_kb.armed,dut.u_rumcajs.u_kb.gesture_active);
 000001             cs_n=0;bus_wait();
 000064             for(i=63;i>=0;i=i-1)begin sdi=challenge[i];bus_wait();sclk=1;bus_wait();sclk=0;bus_wait();end
 000001             cs_n=1;bus_wait();
 000001             cycles(10000); // one READY pin: response uses a fixed wait
 000001             if(uo_out[0])$fatal(1,"READY high after challenge");
 000001             cs_n=0;bus_wait();got=0;
 000064             for(i=63;i>=0;i=i-1)begin bus_wait();sclk=1;#1;got[i]=uo_out[2];bus_wait();sclk=0;bus_wait();end
 000001             cs_n=1;bus_wait();
 000001             if(got!==expected)$fatal(1,"wrapper response wrong got=%h expected=%h",got,expected);
~000001             n=0;while(uo_out[0]&&n<100)begin@(posedge clk);n=n+1;end
 000001             if(uo_out[0]||uo_out[1]||uo_out[2])$fatal(1,"wrapper did not idle");
 000001             cycles(25000); // stable release required after integration flush
                end
            endtask
 000001     initial begin
 000001         cycles(4);@(negedge clk);rst_n=1;cycles(25000);
 000001         cycles(20);
 000001         if(uo_out[2:0]!=0)$fatal(1,"unused inputs affected idle protocol");
 000001         good_pin();exchange(64'hf15654a8d25ffa1c,64'hba2a5234deadbeef);
 000001         bad_pin();cycles(10000);
 000001         if(uo_out[2:0]!==0)$fatal(1,"BAD PIN exposed READY or data");
 000001         if(dut.u_rumcajs.u_regs.fail_count!=1)$fatal(1,"wrapper BAD not accounted");
 000001         ena=0;#1;
 000001         if(uo_out!==0||uio_oe!==0||uio_out!==0)$fatal(1,"ena wrapper mask unsafe");
 000001         $display("PASS tb_tt_um_rumcajs single READY pin, fixed-wait response, BAD rejection, reserved pin mapping");$finish;
            end
        endmodule
        
