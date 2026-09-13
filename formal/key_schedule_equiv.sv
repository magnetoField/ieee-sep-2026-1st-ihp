module key_schedule_equiv;
    (* anyconst *) reg [31:0] k0_input;
    (* anyconst *) reg [31:0] k1_input;
    (* anyconst *) reg [31:0] k2_input;
    (* anyconst *) reg [31:0] k3_input;
    (* anyconst *) reg z_bit;
    reg [31:0] s0,s1,s2,s3;
    reg [31:0] tmp,expected;
    reg feedback;
    integer index;
    function [31:0] ror1;input[31:0]v;begin ror1={v[0],v[31:1]};end endfunction
    function [31:0] ror3;input[31:0]v;begin ror3={v[2:0],v[31:3]};end endfunction

    always @* begin
        s0=k0_input;s1=k1_input;s2=k2_input;s3=k3_input;
        for(index=0;index<32;index=index+1)begin
            feedback=s0[0]^s3[3]^s3[4]^s1[0]^s1[1]^(index>=2)^((index==0)&z_bit);
            s0={feedback,s0[31:1]};
            s1=ror1(s1);s2=ror1(s2);s3=ror1(s3);
        end
        tmp=ror3(k3_input)^k1_input;
        expected=32'hfffffffc^k0_input^tmp^ror1(tmp)^z_bit;
        assert(s0==expected);
        assert(s1==k1_input);
        assert(s2==k2_input);
        assert(s3==k3_input);
    end
endmodule
