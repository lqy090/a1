`timescale 1ns/1ps
module tb_raw_tone_display;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=0;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer errors=0;
    raw_tone_display dut(.I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_rgb(rgb),
        .I_brightness_level(3'd3),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));

    task pixel;
        input [23:0] value;
        input [23:0] expected;
        begin
            @(negedge clk); rgb=value; de=1; vs=1; hs=1;
            repeat(5) @(posedge clk);
            #1;
            if (orgb !== expected || !ode || !ovs || !ohs) begin
                $display("FAIL input=%h output=%h expected=%h de/vs/hs=%b%b%b",
                         value,orgb,expected,ode,ovs,ohs);
                errors=errors+1;
            end
            @(negedge clk); de=0; vs=0; hs=0;
            repeat(5) @(posedge clk);
            #1;
            if (ode || ovs || ohs || orgb !== 24'd0) begin
                $display("FAIL blanking sync/output %h %b%b%b",orgb,ode,ovs,ohs);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        pixel(24'h000000,24'h000000);
        pixel(24'h080808,24'h080808);
        pixel(24'h101010,24'h111111);
        pixel(24'h484848,24'h6c6c6c);
        pixel(24'h888888,24'haaaaaa);
        pixel(24'hffffff,24'hffffff);
        pixel(24'hff0000,24'hff0000); // no red clipping/desaturation
        if(errors==0) $display("PASS tb_raw_tone_display");
        else $fatal(1,"tb_raw_tone_display errors=%0d",errors);
        $finish;
    end
endmodule
