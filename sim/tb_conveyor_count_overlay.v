`timescale 1ns/1ps
module tb_conveyor_count_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=1, enabled=0;
    reg [127:0] totals=0;
    wire ov,oh,od;
    wire [23:0] rgb;
    integer errors=0;
    conveyor_count_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(1'b0),
        .I_de(de),.I_rgb(24'h123456),.I_enable(enabled),.I_counts(totals),
        .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_rgb(rgb)
    );
    task frame;
        begin
            @(negedge clk); vs=1;
            @(negedge clk); vs=0;
            repeat(2) @(negedge clk);
        end
    endtask
    task probe;
        input [10:0] px,py;
        input [23:0] expect_rgb;
        begin
            @(negedge clk); dut.x=px; dut.y=py;
            @(negedge clk);
            if(rgb !== expect_rgb) begin
                $display("pixel %0d,%0d actual %h expected %h",px,py,rgb,expect_rgb);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        frame;
        probe(800,300,24'h123456); // KEY2 off: no line
        probe(16,110,24'h123456);  // no panel
        enabled=1; frame;
        probe(800,300,24'hffffff);
        probe(16,110,24'h101a27);
        // First and last labels are full English names, one line each.
        @(negedge clk); dut.x=24; dut.y=150; #1;
        if(dut.letter !== "R") errors=errors+1;
        @(negedge clk); dut.x=24+4*16; dut.y=150; #1;
        if(dut.letter !== "R") errors=errors+1; // RED RECTANGLE
        @(negedge clk); dut.x=24+6*16; dut.y=450; #1;
        if(dut.letter !== "R") errors=errors+1; // GREEN RECTANGLE
        @(negedge clk); dut.x=24+6*16; dut.y=500; #1;
        if(dut.letter !== "T") errors=errors+1; // GREEN TRIANGLE
        @(negedge clk); dut.x=24+18*16; dut.y=150; #1;
        if(dut.letter !== "0") errors=errors+1;
        totals[15:0]=16'h0001;
        @(negedge clk); dut.x=24+20*16; dut.y=150; #1;
        if(dut.letter !== "1") errors=errors+1;
        if(errors==0) $display("PASS tb_conveyor_count_overlay");
        else $fatal(1,"tb_conveyor_count_overlay errors=%0d",errors);
        $finish;
    end
endmodule
