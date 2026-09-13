`timescale 1ns/1ps
module tb_tt_um_rumcajs;
    reg clk=0,rst_n=0,ena=1;
    reg [3:0] upper_ui=0;
    reg [7:0] uio_in=0;
    reg [15:0] pressed=0;
    reg sdi=0,sclk=0,cs_n=1,unused_ui7=0;
    wire [7:0] ui_in,uo_out,uio_out,uio_oe;
    wire [3:0] columns;
    assign ui_in={unused_ui7,cs_n,sclk,sdi,columns};

    function [3:0] network_columns;
        input [15:0] keys;input[3:0]driven;
        reg[7:0]reached;integer pass,row,col;
        begin
            reached={4'b0,driven};
            for(pass=0;pass<8;pass=pass+1)
                for(row=0;row<4;row=row+1)
                    for(col=0;col<4;col=col+1)
                        if(keys[4*row+col]&&(reached[row]||reached[4+col]))begin
                            reached[row]=1;reached[4+col]=1;
                        end
            network_columns=reached[7:4];
        end
    endfunction
    assign columns=~network_columns(pressed,uio_oe[3:0]);
    tt_um_rumcajs dut(ui_in,uo_out,uio_in,uio_out,uio_oe,ena,clk,rst_n);
    always #1 clk=~clk;
    // Exercise every unused wrapper input continuously through all protocol phases.
    always @(negedge clk) if(rst_n)begin
        unused_ui7<=~unused_ui7;
        uio_in<=uio_in+8'h3d;
    end
    always @(posedge clk) begin
        if(uio_out!==0||uio_oe[7:4]!==0||uo_out[7:4]!==0||uo_out[1]!==0)$fatal(1,"reserved pin unsafe");
        if((uio_oe[3:0]&(uio_oe[3:0]-1))!=0)$fatal(1,"wrapper rows not onehot0");
    end
    task cycles(input integer n);integer i;begin for(i=0;i<n;i=i+1)@(posedge clk);end endtask
    task press(input integer id);begin pressed=16'b1<<id;cycles(22000);pressed=0;cycles(45000);end endtask
    task good_pin;begin press(0);press(1);press(2);press(4);end endtask
    task bad_pin;begin press(0);press(1);press(2);press(5);end endtask
    task bus_wait;begin cycles(20);end endtask
    task exchange(input[63:0]challenge,input[63:0]expected);
        integer i,n;reg[63:0]got;
        begin
            n=0;while(!uo_out[0]&&n<5000)begin@(posedge clk);n=n+1;end
            if(!uo_out[0])$fatal(1,"wrapper REQ missing digits=%0d pin=%h keyid=%0d armed=%b gesture=%b",
                dut.u_rumcajs.u_regs.digit_count,dut.u_rumcajs.u_regs.pin_shift,
                dut.u_rumcajs.key_id,dut.u_rumcajs.u_kb.armed,dut.u_rumcajs.u_kb.gesture_active);
            cs_n=0;bus_wait();
            for(i=63;i>=0;i=i-1)begin sdi=challenge[i];bus_wait();sclk=1;bus_wait();sclk=0;bus_wait();end
            cs_n=1;bus_wait();
            cycles(10000); // one READY pin: response uses a fixed wait
            if(uo_out[0])$fatal(1,"READY high after challenge");
            cs_n=0;bus_wait();got=0;
            for(i=63;i>=0;i=i-1)begin bus_wait();sclk=1;#1;got[i]=uo_out[2];bus_wait();sclk=0;bus_wait();end
            cs_n=1;bus_wait();
            if(got!==expected)$fatal(1,"wrapper response wrong got=%h expected=%h",got,expected);
            n=0;while(uo_out[0]&&n<100)begin@(posedge clk);n=n+1;end
            if(uo_out[0]||uo_out[1]||uo_out[2])$fatal(1,"wrapper did not idle");
            cycles(25000); // stable release required after integration flush
        end
    endtask
    initial begin
        cycles(4);@(negedge clk);rst_n=1;cycles(25000);
        cycles(20);
        if(uo_out[2:0]!=0)$fatal(1,"unused inputs affected idle protocol");
        good_pin();exchange(64'h656b696c20646e75,64'h44c8fc20b9dfa07a);
        bad_pin();cycles(10000);
        if(uo_out[2:0]!==0)$fatal(1,"BAD PIN exposed READY or data");
        if(dut.u_rumcajs.u_regs.fail_count!=1)$fatal(1,"wrapper BAD not accounted");
        ena=0;#1;
        if(uo_out!==0||uio_oe!==0||uio_out!==0)$fatal(1,"ena wrapper mask unsafe");
        $display("PASS tb_tt_um_rumcajs single READY pin, fixed-wait response, BAD rejection, reserved pin mapping");$finish;
    end
endmodule
