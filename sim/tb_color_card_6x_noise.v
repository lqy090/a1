`timescale 1ns/1ps
module tb_color_card_6x_noise;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [23:0] rgb=0;
    wire valid;
    wire [2:0] color;
    wire [10:0] x0,y0,x1,y1;
    wire [19:0] red_pixels, blue_pixels;
    integer x,y,errors=0;
    color_card_detect #(.WIDTH(64),.HEIGHT(32),.MIN_PIXELS(16),.MIN_SPAN(4)) dut(
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
        input [3:0] kind;
        begin
            for (y=0;y<32;y=y+1) begin
                for (x=0;x<64;x=x+1) begin
                    de=1;
                    rgb=24'h505050;
                    case (kind)
                        1: begin // Red card over skin-coloured background.
                            rgb=24'hb48262;
                            if (x>=8 && x<=27 && y>=6 && y<=21) rgb=24'hd4523a;
                        end
                        2: begin // Blue card over bright bluish neutral background.
                            rgb=24'h9aa0b4;
                            // 6x can lift G close to B; B/G is only 1.15.
                            if (x>=20 && x<=39 && y>=8 && y<=23) rgb=24'h408296;
                        end
                        3: begin // Isolated, strongly blue noise pixels.
                            if ((x%8)==0 && (y%4)==0) rgb=24'h1030f0;
                        end
                        4: begin // Blue card moved close to the right line edge.
                            if (x>=52 && y>=8 && y<=23) rgb=24'h408296;
                        end
                        5: begin // A smaller blue-tinted light patch above the card.
                            if (x>=4 && x<=19 && y<=5) rgb=24'h408296;
                            if (x>=32 && x<=55 && y>=10 && y<=27)
                                rgb=24'h408296;
                        end
                        6,7,8: begin // Compare coherent red with V2 yellow/green bounds.
                            if ((x>=4 && x<=19 && y<=5) ||
                                (x>=32 && x<=55 && y>=10 && y<=27)) begin
                                if (kind==6) rgb=24'hd02020;
                                if (kind==7) rgb=24'hd6c032;
                                if (kind==8) rgb=24'h369c42;
                            end
                        end
                        9: begin // Yellow triangle: retain the short upper rows.
                            if (y>=4 && y<=22 &&
                                x>=40-(y-4) && x<=46+(y-4))
                                rgb=24'hd6c032;
                        end
                        default: rgb=24'h505050;
                    endcase
                    @(negedge clk);
                end
                de=0; rgb=0;
                repeat(4) @(negedge clk);
            end
        end
    endtask
    task expect_box;
        input [2:0] want_color;
        input [10:0] want_x0,want_y0,want_x1,want_y1;
        begin
            if (!valid || color!=want_color || x0!=want_x0 || y0!=want_y0 ||
                x1!=want_x1 || y1!=want_y1) begin
                $display("FAIL box valid=%b color=%0d (%0d,%0d)-(%0d,%0d) red=%0d blue=%0d",
                    valid,color,x0,y0,x1,y1,red_pixels,blue_pixels);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        frame_start(); send_frame(1); frame_start(); #1;
        expect_box(1,8,6,26,20);
        if (red_pixels!=80 || blue_pixels!=0) errors=errors+1;
        send_frame(2); frame_start(); #1;
        expect_box(2,20,8,38,22);
        if (red_pixels!=0 || blue_pixels!=80) errors=errors+1;
        send_frame(3); frame_start(); #1;
        if (valid || red_pixels!=0 || blue_pixels!=0) begin
            $display("FAIL isolated noise valid=%b red=%0d blue=%0d",valid,red_pixels,blue_pixels);
            errors=errors+1;
        end
        send_frame(4); frame_start(); #1;
        expect_box(2,52,8,62,22);
        if (blue_pixels!=48) errors=errors+1;
        send_frame(5); frame_start(); #1;
        expect_box(2,32,10,54,26);
        if (blue_pixels!=108) begin
            $display("FAIL coherent blue count=%0d",blue_pixels);
            errors=errors+1;
        end
        send_frame(6); frame_start(); #1;
        expect_box(1,32,10,54,26);
        if (red_pixels!=108) begin
            $display("FAIL coherent red count=%0d",red_pixels);
            errors=errors+1;
        end
        send_frame(7); frame_start(); #1;
        expect_box(3,4,0,54,26);
        send_frame(8); frame_start(); #1;
        expect_box(4,4,0,54,26);
        send_frame(9); frame_start(); #1;
        expect_box(3,22,4,62,22);
        if (errors==0) $display("PASS tb_color_card_6x_noise");
        else $fatal(1,"tb_color_card_6x_noise errors=%0d",errors);
        $finish;
    end
endmodule
