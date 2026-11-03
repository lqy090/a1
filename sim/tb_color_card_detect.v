`timescale 1ns/1ps
module tb_color_card_detect;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [23:0] rgb=0;
    wire valid;
    wire [2:0] color;
    wire [10:0] x0,y0,x1,y1;
    wire [19:0] red_pixels, blue_pixels;
    integer x,y,errors=0;
    color_card_detect #(.WIDTH(32),.HEIGHT(16),.MIN_PIXELS(16),.MIN_SPAN(4)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_de(de),.I_rgb(rgb),
        .O_valid(valid),.O_color(color),.O_x0(x0),.O_y0(y0),.O_x1(x1),.O_y1(y1),
        .O_red_pixels(red_pixels),.O_blue_pixels(blue_pixels)
    );
    task frame_start;
        begin
            @(negedge clk); vs=1;
            @(negedge clk); vs=0;
        end
    endtask
    task send_frame;
        input [2:0] kind;
        begin
            for (y=0;y<16;y=y+1) begin
                for (x=0;x<32;x=x+1) begin
                    de=1;
                    rgb=24'h505050;
                    if (x>=4 && x<=19 && y>=2 && y<=13) begin
                        if (kind==1) rgb=24'hd02020;
                        if (kind==2) rgb=24'h2030c0;
                        if (kind==3) rgb=24'hd6c032;
                        if (kind==4) rgb=24'h369c42;
                        if (kind==7) rgb=(x<12) ? 24'hd02020 : 24'hd6c032;
                    end
                    if (kind==5) rgb=24'hb48262; // skin-like surface
                    if (kind==6) rgb=24'hf4f4f4; // neutral highlight
                    @(negedge clk);
                end
                de=0; rgb=0;
                repeat(4) @(negedge clk);
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        frame_start(); send_frame(1); frame_start();
        #1;
        if (!valid || color!=1 || red_pixels!=48 || blue_pixels!=0 || x0!=4 || x1!=18 || y0!=2 || y1!=12) begin
            $display("FAIL red valid=%b color=%d box=%d,%d..%d,%d",valid,color,x0,y0,x1,y1);
            errors=errors+1;
        end
        send_frame(2); frame_start(); #1;
        if (!valid || color!=2 || red_pixels!=0 || blue_pixels!=48 || x0!=4 || x1!=18 || y0!=2 || y1!=12) begin
            $display("FAIL blue valid=%b color=%d box=%d,%d..%d,%d",valid,color,x0,y0,x1,y1);
            errors=errors+1;
        end
        send_frame(3); frame_start(); #1;
        if (!valid || color!=3 || red_pixels!=0 || blue_pixels!=0 ||
            x0!=4 || x1!=18 || y0!=2 || y1!=12) begin
            $display("FAIL yellow valid=%b color=%d box=%d,%d..%d,%d",valid,color,x0,y0,x1,y1);
            errors=errors+1;
        end
        send_frame(4); frame_start(); #1;
        if (!valid || color!=4 || red_pixels!=0 || blue_pixels!=0 ||
            x0!=4 || x1!=18 || y0!=2 || y1!=12) begin
            $display("FAIL green valid=%b color=%d box=%d,%d..%d,%d",valid,color,x0,y0,x1,y1);
            errors=errors+1;
        end
        send_frame(5); frame_start(); #1;
        if (valid) begin $display("FAIL skin false positive color=%d",color);errors=errors+1;end
        send_frame(6); frame_start(); #1;
        if (valid) begin $display("FAIL white false positive color=%d",color);errors=errors+1;end
        send_frame(7); frame_start(); #1;
        if (!valid || color!=1) begin
            $display("FAIL equal-size red/yellow tie valid=%b color=%d",valid,color);
            errors=errors+1;
        end
        send_frame(0); frame_start(); #1;
        if (valid || color!=0 || red_pixels!=0 || blue_pixels!=0) begin $display("FAIL empty frame"); errors=errors+1; end
        if (errors==0) $display("PASS tb_color_card_detect");
        else $fatal(1,"tb_color_card_detect errors=%0d",errors);
        $finish;
    end
endmodule
