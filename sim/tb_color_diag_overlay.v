`timescale 1ns/1ps
module tb_color_diag_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0, mask=0, hide=0;
    reg [23:0] raw=0;
    reg [23:0] processed [0:3];
    wire [23:0] out_rgb;
    wire out_vs,out_hs,out_de;
    integer errors=0;
    color_diag_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(1'b0),.I_de(de),
        .I_rgb(processed[3]),.I_raw_rgb(raw),
        .I_mask_enable(mask),
        .I_hide_panel(hide),
        .I_red_pixels(20'h12345),.I_blue_pixels(20'h0abcd),
        .O_vsync(out_vs),.O_hsync(out_hs),.O_de(out_de),.O_rgb(out_rgb)
    );
    always @(posedge clk) begin
        processed[0] <= raw;
        processed[1] <= processed[0];
        processed[2] <= processed[1];
        processed[3] <= processed[2];
    end
    task pixel;
        input [23:0] color;
        input [23:0] expected;
        begin
            @(negedge clk); raw=color; de=1;
            repeat(5) @(negedge clk);
            #1;
            if (!out_de || out_rgb!==expected) begin
                $display("FAIL color=%h expected=%h got=%h de=%b",color,expected,out_rgb,out_de);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst_n=1;
        @(negedge clk); vs=1;
        @(negedge clk); vs=0;
        mask=1;
        pixel(24'hd02020,24'hff2020);
        pixel(24'h2030c0,24'h2070ff);
        pixel(24'h686868,24'h080808);
        mask=0;
        pixel(24'hd02020,24'hd02020);
        // Exact font bit: first column of the top R row is on at x=24,y=670.
        @(negedge clk); dut.x=11'd26; dut.y=11'd670;
        @(negedge clk); #1;
        if (out_rgb!==24'hff7070) begin
            $display("FAIL R counter panel pixel got=%h",out_rgb); errors=errors+1;
        end
        @(negedge clk); dut.x=11'd26; dut.y=11'd686;
        @(negedge clk); #1;
        if (out_rgb!==24'he0e0e0) begin
            $display("FAIL RGB probe panel pixel got=%h",out_rgb); errors=errors+1;
        end
        hide=1;
        @(negedge clk); dut.x=11'd26; dut.y=11'd670;
        @(negedge clk); #1;
        if (out_rgb!==24'hd02020) begin
            $display("FAIL hidden RGB panel got=%h",out_rgb); errors=errors+1;
        end
        if (errors==0) $display("PASS tb_color_diag_overlay");
        else $fatal(1,"tb_color_diag_overlay errors=%0d",errors);
        $finish;
    end
endmodule
