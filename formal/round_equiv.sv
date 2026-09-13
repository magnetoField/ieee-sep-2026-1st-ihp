module round_equiv;
    (* anyconst *) reg [31:0] x_input;
    (* anyconst *) reg [31:0] y_input;
    (* anyconst *) reg [31:0] round_key;
    reg [31:0] x_serial;
    reg [31:0] y_serial;
    reg [31:0] key_shift;
    reg [31:0] expected;
    reg feedback;
    reg [31:0] x_msb;
    reg [31:0] y_msb;
    reg [31:0] key_msb;
    reg feedback_msb;
    integer index;

    function [31:0] rol1;input[31:0]v;begin rol1={v[30:0],v[31]};end endfunction
    function [31:0] rol2;input[31:0]v;begin rol2={v[29:0],v[31:30]};end endfunction
    function [31:0] rol8;input[31:0]v;begin rol8={v[23:0],v[31:24]};end endfunction

    always @* begin
        x_serial=x_input;y_serial=y_input;key_shift=round_key;
        x_msb=x_input;y_msb=y_input;key_msb=round_key;
        for(index=0;index<32;index=index+1)begin
            feedback=(x_serial[31]&x_serial[24])^x_serial[30]^y_serial[0]^key_shift[0];
            x_serial={x_serial[0],x_serial[31:1]};
            y_serial={feedback,y_serial[31:1]};
            key_shift={1'b0,key_shift[31:1]};
            // MSB-first organization used by the fixed-key ASIC core.
            feedback_msb=(x_msb[30]&x_msb[23])^x_msb[29]^y_msb[31]^key_msb[31];
            x_msb={x_msb[30:0],x_msb[31]};
            y_msb={y_msb[30:0],feedback_msb};
            key_msb={key_msb[30:0],1'b0};
        end
        expected=(rol1(x_input)&rol8(x_input))^rol2(x_input)^y_input^round_key;
        assert(x_serial==x_input);
        assert(y_serial==expected);
        assert(x_msb==x_input);
        assert(y_msb==expected);
    end
endmodule
