`timescale 1ns/1ps
module tb_luma_tone_clear;
    reg [7:0] linear;
    wire [7:0] encoded;
    integer i;
    integer errors=0;
    reg [7:0] prior;
    luma_tone_clear dut(.I_luma(linear), .O_luma(encoded));
    task check;
        input [7:0] value;
        input [7:0] want;
        begin
            linear=value; #1;
            if (encoded !== want) begin
                $display("FAIL gamma(%0d)=%0d expected %0d",value,encoded,want);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        check(8'd0,8'd0);
        check(8'd16,8'd0);
        check(8'd24,8'd0);
        check(8'd32,8'd10);
        check(8'd48,8'd55);
        check(8'd64,8'd130);
        check(8'd80,8'd185);
        check(8'd128,8'd216);
        check(8'd192,8'd240);
        check(8'd255,8'd255);
        prior=0;
        for (i=0;i<256;i=i+1) begin
            linear=i; #1;
            if (encoded < prior) begin
                $display("FAIL non-monotonic input=%0d output=%0d",i,encoded);
                errors=errors+1;
            end
            prior=encoded;
        end
        if (errors==0) $display("PASS tb_luma_tone_clear");
        else $fatal(1,"tb_luma_tone_clear errors=%0d",errors);
        $finish;
    end
endmodule
