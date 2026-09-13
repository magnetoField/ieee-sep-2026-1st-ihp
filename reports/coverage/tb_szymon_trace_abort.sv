//      // verilator_coverage annotation
        `timescale 1ns/1ps
        module tb_szymon_trace_abort;
            localparam [127:0] KAT_KEY=128'h1b1a1918131211100b0a090803020100;
            localparam [63:0] KAT_BLOCK=64'h656b696c20646e75;
~079693     reg clk=0,rst_n=0,abort=0,cmd_valid=0,s_valid=0,s_bit=0,seal_valid=0,m_ready=0;
 000096     reg[127:0]cmd_key=0;
~000097     wire cmd_ready,s_ready,seal_ready,m_valid,m_bit,m_last;
            reg[95:0]trace[0:43];reg[1023:0]trace_file;
            integer round_index,bit_index;
            szymon dut(clk,rst_n,abort,cmd_valid,cmd_ready,cmd_key,s_valid,s_ready,s_bit,
                seal_valid,seal_ready,m_valid,m_ready,m_bit,m_last);
 079693     always #5 clk=~clk;
 000048     task start;begin
~000048         while(!cmd_ready)@(posedge clk);@(negedge clk);cmd_key=KAT_KEY;cmd_valid=1;
 000048         @(posedge clk);@(negedge clk);cmd_valid=0;cmd_key=~KAT_KEY;
            end endtask
 000049     task load_n(input integer count);begin
 003072         for(bit_index=63;bit_index>=64-count;bit_index=bit_index-1)begin
 003072             @(negedge clk);s_bit=KAT_BLOCK[bit_index];s_valid=1;
 003072             @(posedge clk);@(negedge clk);s_valid=0;
                end
            end endtask
 000046     task seal;begin
 000046         @(negedge clk);seal_valid=1;@(posedge clk);@(negedge clk);seal_valid=0;
            end endtask
 000048     task clear_by(input integer use_reset);begin
 000048         @(negedge clk);
 000024         if(use_reset)begin
 000024             rst_n=0;#1;
 000024         end else begin
 000024             abort=1;@(posedge clk);#1;
                end
 000048         if(m_valid||s_ready||seal_ready||{dut.a,dut.b,dut.k3,dut.k2,dut.k1,dut.k0}!==192'b0)
                    $fatal(1,"cancel did not clear state round=%0d reset=%0d",round_index,use_reset);
 000024         if(use_reset)begin
 000024             @(posedge clk);@(negedge clk);rst_n=1;
 000024         end else begin
 000024             @(negedge clk);abort=0;
                end
 000096         repeat(2)@(posedge clk);
 000048         if(!cmd_ready)$fatal(1,"core did not rearm after cancel");
            end endtask
 000001     initial begin
 000001         if(!$value$plusargs("TRACE=%s",trace_file))$fatal(1,"+TRACE required");
 000001         $readmemh(trace_file,trace);
 000003         repeat(3)@(posedge clk);@(negedge clk);rst_n=1;repeat(2)@(posedge clk);
        
                // 63 bits cannot seal; the 64th is accepted and a 65th is refused.
 000001         start();load_n(63);
 000001         if(seal_ready||!s_ready)$fatal(1,"63-bit boundary wrong");
 000004         seal_valid=1;repeat(4)@(posedge clk);@(negedge clk);seal_valid=0;
 000001         if(m_valid||dut.state!=1)$fatal(1,"premature seal changed state");
 000001         load_n(1);if(!seal_ready||s_ready)$fatal(1,"64-bit boundary wrong");
 000004         s_valid=1;s_bit=~KAT_BLOCK[0];repeat(4)@(posedge clk);@(negedge clk);s_valid=0;
 000001         if(!seal_ready||dut.bit_count!=0)$fatal(1,"65th source bit was accepted");
 000001         clear_by(0);
        
                // Check every complete round against the independent word model.
 000001         start();load_n(64);
                // A second command held while busy is never accepted and cannot change key state.
 000001         cmd_key=128'hdeadbeefdeadbeefdeadbeefdeadbeef;cmd_valid=1;
 000005         repeat(5)begin @(posedge clk);#1;if(cmd_ready)$fatal(1,"second command accepted while busy");end
 000001         @(negedge clk);cmd_valid=0;
 000001         seal();
 000044         for(round_index=0;round_index<44;round_index=round_index+1)begin
 001408             repeat(32)@(posedge clk);#1;
 000022             if(round_index[0]==0)begin
 000022                 if({dut.b,dut.a}!==trace[round_index][95:32])
                            $fatal(1,"round %0d state mismatch got=%h",round_index,{dut.b,dut.a});
 000022             end else if({dut.a,dut.b}!==trace[round_index][95:32])
                        $fatal(1,"round %0d state mismatch got=%h",round_index,{dut.a,dut.b});
 000044             if(dut.k0!==trace[round_index][31:0])
                        $fatal(1,"round %0d next key mismatch got=%h expected=%h",
                            round_index,dut.k0,trace[round_index][31:0]);
                end
 000001         if(!m_valid||{dut.a,dut.b}!==64'h44c8fc20b9dfa07a)
                    $fatal(1,"trace did not end at KAT output");
 000001         if({dut.k3,dut.k2,dut.k1,dut.k0}!==0)$fatal(1,"keys not erased after round 43");
 000001         clear_by(1);
        
                // Abort or session-reset in every round; each cancellation must rearm.
 000044         for(round_index=0;round_index<44;round_index=round_index+1)begin
 000044             start();load_n(64);seal();
 030580             repeat(round_index*32+7)@(posedge clk);
 000044             if(!m_valid&&dut.state!=3)$fatal(1,"round abort setup escaped CRYPT %0d",round_index);
 000044             clear_by(round_index[0]);
                end
        
                // WAIT_SEAL and OUTPUT cancellation are also explicitly covered.
 000001         start();load_n(64);clear_by(0);
 001408         start();load_n(64);seal();repeat(1408)@(posedge clk);#1;
 000001         if(!m_valid)$fatal(1,"OUTPUT setup missing");
 000003         m_ready=0;repeat(3)@(posedge clk);clear_by(1);
 000001         $display("PASS tb_szymon_trace_abort all 44 round states and cancel in every phase/round");$finish;
            end
        endmodule
        
