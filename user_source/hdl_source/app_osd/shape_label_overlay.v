// Adds a shape name above the existing colour-labelled box. The previous
// complete frame's classifier output is sampled at the display frame boundary.
module shape_label_overlay (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable, I_target_valid,
    input wire [2:0] I_target_color, I_shape_color, I_shape,
    input wire I_shape_valid,
    input wire [10:0] I_x0, I_y0,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    reg [2:0] last_shape, last_color, shape_q, color_q;
    reg last_valid;
    reg [10:0] label_x, label_y;
    wire frame_start = I_vsync && !vs_d;
    wire supported_shape = I_shape == 3'd2 || I_shape == 3'd4;
    wire same_target = I_enable && I_target_valid && I_shape_valid &&
                       supported_shape && I_target_color == I_shape_color;
    wire [10:0] next_x = I_x0 > 11'd1120 ? 11'd1120 : I_x0;
    wire [10:0] next_y = I_y0 >= 11'd44 ? I_y0 - 11'd44 : I_y0 + 11'd24;
    wire panel = shape_q != 0 && x >= label_x && x < label_x + 11'd160 &&
                 y >= label_y && y < label_y + 11'd20;
    wire text_area = panel && x >= label_x + 11'd4 &&
                     x < label_x + 11'd156 &&
                     y >= label_y + 11'd3 && y < label_y + 11'd17;
    wire [7:0] tx = x - label_x - 11'd4;
    wire [3:0] index = tx[7:4];
    wire [2:0] col = tx[3:1];
    wire [2:0] row = (y - label_y - 11'd3) >> 1;
    reg [7:0] letter;
    always @* begin
        letter = 8'h20;
        case (shape_q)
            3'd2: case (index) // RECTANGLE
                0:letter="R"; 1:letter="E"; 2:letter="C";
                3:letter="T"; 4:letter="A"; 5:letter="N";
                6:letter="G"; 7:letter="L"; 8:letter="E";
            endcase
            3'd4: case (index) // TRIANGLE
                0:letter="T"; 1:letter="R"; 2:letter="I";
                3:letter="A"; 4:letter="N"; 5:letter="G";
                6:letter="L"; 7:letter="E";
            endcase
        endcase
    end
    function [4:0] glyph;
        input [7:0] c;
        input [2:0] r;
        begin
            glyph = 0;
            case (c)
                "A": case(r)
                    0:glyph=5'b01110; 1,2:glyph=5'b10001;
                    3:glyph=5'b11111; 4,5,6:glyph=5'b10001;
                endcase
                "C": case(r)
                    0,6:glyph=5'b01111; 1,2,3,4,5:glyph=5'b10000;
                endcase
                "E": case(r)
                    0,3,6:glyph=5'b11111; 1,2,4,5:glyph=5'b10000;
                endcase
                "G": case(r)
                    0:glyph=5'b01111; 1,2:glyph=5'b10000;
                    3:glyph=5'b10111; 4,5:glyph=5'b10001; 6:glyph=5'b01111;
                endcase
                "I": case(r)
                    0,6:glyph=5'b01110; 1,2,3,4,5:glyph=5'b00100;
                endcase
                "L": case(r)
                    0,1,2,3,4,5:glyph=5'b10000; 6:glyph=5'b11111;
                endcase
                "N": case(r)
                    0,6:glyph=5'b10001; 1:glyph=5'b11001;
                    2,3:glyph=5'b10101; 4,5:glyph=5'b10011;
                endcase
                "Q": case(r)
                    0:glyph=5'b01110; 1,2,3:glyph=5'b10001;
                    4:glyph=5'b10101; 5:glyph=5'b10010; 6:glyph=5'b01101;
                endcase
                "R": case(r)
                    0,3:glyph=5'b11110; 1,2:glyph=5'b10001;
                    4:glyph=5'b10100; 5:glyph=5'b10010; 6:glyph=5'b10001;
                endcase
                "S": case(r)
                    0,6:glyph=5'b01111; 1,2:glyph=5'b10000;
                    3:glyph=5'b01110; 4,5:glyph=5'b00001;
                endcase
                "T": case(r)
                    0:glyph=5'b11111; 1,2,3,4,5,6:glyph=5'b00100;
                endcase
                "U": case(r)
                    0,1,2,3,4,5:glyph=5'b10001; 6:glyph=5'b01110;
                endcase
            endcase
        end
    endfunction
    wire [4:0] bits = glyph(letter,row);
    wire text_pixel = text_area && col < 5 && bits[4-col];
    wire [23:0] accent = color_q == 1 ? 24'hff4040 :
                         color_q == 2 ? 24'h40a0ff :
                         color_q == 3 ? 24'hffd23f : 24'h40d070;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            last_shape <= 0; last_color <= 0; last_valid <= 0;
            shape_q <= 0; color_q <= 0; label_x <= 0; label_y <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (frame_start) begin
                x <= 0; y <= 0;
                last_valid <= same_target;
                last_shape <= I_shape;
                last_color <= I_target_color;
                shape_q <= same_target && last_valid &&
                           I_shape == last_shape && I_target_color == last_color ?
                           I_shape : 3'd0;
                color_q <= I_target_color;
                label_x <= next_x; label_y <= next_y;
            end else if (de_d && !I_de) begin
                x <= 0; y <= y + 1'b1;
            end else if (I_de) x <= x + 1'b1;
            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 0;
            else if (text_pixel) O_rgb <= 24'hffffff;
            else if (panel) O_rgb <= accent;
            else O_rgb <= I_rgb;
        end
    end
endmodule
