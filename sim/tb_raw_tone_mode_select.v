`timescale 1ns/1ps
module tb_raw_tone_mode_select;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=0;
    reg [2:0] mode=0;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer errors=0;
    raw_tone_mode_select dut(.I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_rgb(rgb),.I_mode(mode),
        .I_brightness_level(3'd3),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));

    task pixel;
        input [2:0] selected_mode;
        input [23:0] value;
        input [23:0] expected;
        begin
            @(negedge clk); mode=selected_mode; rgb=value; de=1; vs=1; hs=1;
            repeat(6) @(posedge clk);
            #1;
            if (orgb !== expected || !ode || !ovs || !ohs) begin
                $display("FAIL mode=%d input=%h output=%h expected=%h sync=%b%b%b",
                    selected_mode,value,orgb,expected,ode,ovs,ohs);
                errors=errors+1;
            end
            @(negedge clk); de=0; vs=0; hs=0;
            repeat(6) @(posedge clk);
            #1;
            if (orgb !== 24'd0 || ode || ovs || ohs) begin
                $display("FAIL blanking mode=%d output=%h sync=%b%b%b",
                    selected_mode,orgb,ode,ovs,ohs);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        pixel(3'd0,24'h484848,24'h6c6c6c);
        pixel(3'd0,24'hff0000,24'hff0000);
        pixel(3'd1,24'h484848,24'h484848);
        pixel(3'd2,24'h123456,24'h123456);
        pixel(3'd3,24'h484848,24'h484848);
        pixel(3'd4,24'h123456,24'h123456);
        pixel(3'd0,24'h484848,24'h6c6c6c);
        if(errors==0) $display("PASS tb_raw_tone_mode_select");
        else $fatal(1,"tb_raw_tone_mode_select errors=%0d",errors);
        $finish;
    end
endmodule
