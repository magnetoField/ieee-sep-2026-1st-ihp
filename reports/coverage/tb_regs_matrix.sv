//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_regs_matrix;
 000330     reg clk=0,cold_rst_n=0,session_rst_n=0,entry_enable=1,key_valid=0,txn_ready=0,session_end=0;
 000030     reg[3:0]key_id=15;
~000082     wire key_ready,txn_valid,locked,beep_event,submit_event,pin_rejected;
            integer beeps,submits,id,pos,prefix,base_beeps,base_submits;
            regs dut(clk,cold_rst_n,session_rst_n,entry_enable,key_valid,key_ready,key_id,
                txn_valid,txn_ready,session_end,locked,beep_event,submit_event,pin_rejected);
 000330     always #5 clk=~clk;
 000165     always @(posedge clk)begin if(beep_event)beeps=beeps+1;if(submit_event)submits=submits+1;end
 000016     function integer is_digit;input integer value;begin
 000016         is_digit=(value==0||value==1||value==2||value==4||value==5||value==6||
 000016                   value==8||value==9||value==10||value==13);
            end endfunction
 000010     function[3:0]digit_of;input integer value;begin
 000010         case(value)0:digit_of=1;1:digit_of=2;2:digit_of=3;4:digit_of=4;5:digit_of=5;
 000001         6:digit_of=6;8:digit_of=7;9:digit_of=8;10:digit_of=9;13:digit_of=0;
%000000         default:digit_of=15;endcase
            end endfunction
 000022     function[3:0]good_id;input integer index;begin
 000022         case(index)0:good_id=0;1:good_id=1;2:good_id=2;default:good_id=4;endcase
            end endfunction
 000046     task fire(input[3:0]value);begin
~000046         while(!key_ready)@(posedge clk);@(negedge clk);key_id=value;key_valid=1;
 000046         @(posedge clk);@(negedge clk);key_valid=0;
            end endtask
 000020     task session_reset;begin
 000020         session_rst_n=0;#1;if(txn_valid||dut.digit_count||dut.pin_shift)$fatal(1,"session reset failed");
 000040         session_rst_n=1;repeat(2)@(posedge clk);
            end endtask
 000005     task cold_reset;begin
 000005         cold_rst_n=0;session_rst_n=0;#1;
 000005         if(dut.fail_count||locked||txn_valid)$fatal(1,"cold reset failed");
 000010         cold_rst_n=1;session_rst_n=1;repeat(2)@(posedge clk);
            end endtask
 000005     task finish_session;begin
 000005         @(negedge clk);txn_ready=1;@(posedge clk);@(negedge clk);txn_ready=0;
 000005         session_end=1;@(posedge clk);@(negedge clk);session_end=0;
            end endtask
 000001     initial begin
 000002         beeps=0;submits=0;repeat(2)@(posedge clk);@(negedge clk);cold_rst_n=1;session_rst_n=1;
                // Every key ID: digits map, star clears/beeps, all others are inert.
 000016         for(id=0;id<16;id=id+1)begin
 000016             session_reset();base_beeps=beeps;base_submits=submits;fire(id[3:0]);
 000010             if(is_digit(id))begin
 000010                 if(dut.digit_count!=1||dut.pin_shift[3:0]!=digit_of(id)||beeps!=base_beeps+1)
                            $fatal(1,"digit mapping id=%0d shift=%h count=%0d",id,dut.pin_shift,dut.digit_count);
 000001             end else if(id==12)begin
 000001                 if(dut.digit_count||dut.pin_shift||beeps!=base_beeps+1)$fatal(1,"star mapping wrong");
 000005             end else if(dut.digit_count||dut.pin_shift||beeps!=base_beeps)
                        $fatal(1,"ignored key id=%0d changed state",id);
 000016             if(submits!=base_submits||txn_valid||dut.fail_count)$fatal(1,"single key submitted id=%0d",id);
                end
        
                // Star at every partial length clears without consuming an attempt.
 000004         for(prefix=0;prefix<4;prefix=prefix+1)begin
 000004             session_reset();
 000006             for(pos=0;pos<prefix;pos=pos+1)fire(good_id(pos));
 000004             base_submits=submits;fire(12);
 000004             if(dut.digit_count||dut.pin_shift||txn_valid||dut.fail_count||submits!=base_submits)
                        $fatal(1,"star failed at prefix %0d",prefix);
                end
        
                // A mismatch in every position is rejected atomically at full length.
 000004         for(pos=0;pos<4;pos=pos+1)begin
 000004             cold_reset();base_submits=submits;
 000016             for(prefix=0;prefix<4;prefix=prefix+1)
 000012                 if(prefix==pos)fire(10);else fire(good_id(prefix));
 000004             if(txn_valid||dut.session_busy||dut.fail_count!=1||submits!=base_submits+1)
                        $fatal(1,"position mismatch %0d not atomic",pos);
 000004             if(dut.pin_shift||dut.digit_count)$fatal(1,"submitted BCD residue position %0d",pos);
 000020             repeat(5)begin @(posedge clk);#1;
 000020                 if(txn_valid||dut.session_busy||dut.fail_count!=1)
                            $fatal(1,"rejected PIN created a token or changed count");
                    end
 000004             finish_session();
                end
        
                // Once BUSY, a held input cannot add digits or alter the accepted context.
 000004         cold_reset();for(pos=0;pos<4;pos=pos+1)fire(good_id(pos));
 000001         if(!txn_valid||dut.pin_shift||dut.digit_count)$fatal(1,"GOOD setup failed");
 000008         base_beeps=beeps;@(negedge clk);key_id=10;key_valid=1;repeat(8)@(posedge clk);@(negedge clk);key_valid=0;
 000001         if(beeps!=base_beeps||!txn_valid||dut.fail_count)
                    $fatal(1,"BUSY input changed context");
 000001         finish_session();
 000001         entry_enable=0;base_beeps=beeps;@(negedge clk);key_id=0;key_valid=1;
 000005         repeat(5)@(posedge clk);@(negedge clk);key_valid=0;
 000001         if(key_ready||beeps!=base_beeps||dut.digit_count)$fatal(1,"entry_enable did not gate input");
 000001         $display("PASS tb_regs_matrix all key IDs/PIN positions/star/context/gating");$finish;
            end
        endmodule
        
