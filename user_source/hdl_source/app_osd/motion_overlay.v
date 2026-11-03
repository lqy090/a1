// Pale-cyan variable-size rectangles after the existing application OSD.
module motion_overlay #(
    parameter integer MAX_BOXES = 16
) (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable, I_overflow,
    input wire [4:0] I_box_count,
    input wire [MAX_BOXES*26-1:0] I_boxes,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    integer k;
    reg outline;
    reg [25:0] box_data;
    reg [6:0] bx0, bx1;
    reg [5:0] by0, by1;
    wire panel = x >= 11'd820 && x < 11'd946 && y >= 11'd16 && y < 11'd48;
    wire border = panel && (x < 11'd822 || x >= 11'd944 ||
                            y < 11'd18 || y >= 11'd46);
    wire font_area = x >= 11'd832 && x < 11'd932 &&
                     y >= 11'd24 && y < 11'd38;
    wire [10:0] fx = x - 11'd832;
    wire [10:0] fy = y - 11'd24;
    wire [3:0] char_index = fx / 10;
    wire [2:0] gx = (fx % 10) >> 1;
    wire [2:0] gy = fy[3:1];
    reg [4:0] glyph;
    reg [4:0] row_bits;
    wire font_pixel = font_area && gx < 5 && row_bits[4-gx];
    // MOTION ON; a terminal ! flags component/output overflow.
    always @* begin
        case (char_index)
            0: glyph=1; 1:glyph=2; 2:glyph=3; 3:glyph=4;
            4:glyph=2; 5:glyph=5; 6:glyph=0; 7:glyph=2;
            8:glyph=5; 9:glyph=I_overflow ? 6 : 0;
            default:glyph=0;
        endcase
        row_bits=0;
        case (glyph)
            1: case(gy) // M
                0:row_bits=5'b10001; 1:row_bits=5'b11011;
                2:row_bits=5'b10101; 3:row_bits=5'b10101;
                4:row_bits=5'b10001; 5:row_bits=5'b10001;
                6:row_bits=5'b10001; default:row_bits=0;
            endcase
            2: case(gy) // O
                0:row_bits=5'b01110; 1:row_bits=5'b10001;
                2:row_bits=5'b10001; 3:row_bits=5'b10001;
                4:row_bits=5'b10001; 5:row_bits=5'b10001;
                6:row_bits=5'b01110; default:row_bits=0;
            endcase
            3: case(gy) // T
                0:row_bits=5'b11111; 1:row_bits=5'b00100;
                2:row_bits=5'b00100; 3:row_bits=5'b00100;
                4:row_bits=5'b00100; 5:row_bits=5'b00100;
                6:row_bits=5'b00100; default:row_bits=0;
            endcase
            4: case(gy) // I
                0:row_bits=5'b11111; 1:row_bits=5'b00100;
                2:row_bits=5'b00100; 3:row_bits=5'b00100;
                4:row_bits=5'b00100; 5:row_bits=5'b00100;
                6:row_bits=5'b11111; default:row_bits=0;
            endcase
            5: case(gy) // N
                0:row_bits=5'b10001; 1:row_bits=5'b11001;
                2:row_bits=5'b10101; 3:row_bits=5'b10011;
                4:row_bits=5'b10001; 5:row_bits=5'b10001;
                6:row_bits=5'b10001; default:row_bits=0;
            endcase
            6: case(gy) // !
                0:row_bits=5'b00100; 1:row_bits=5'b00100;
                2:row_bits=5'b00100; 3:row_bits=5'b00100;
                4:row_bits=0; 5:row_bits=0;
                6:row_bits=5'b00100; default:row_bits=0;
            endcase
        endcase
        outline=0;
        for (k=0;k<MAX_BOXES;k=k+1) begin
            box_data=I_boxes[k*26 +: 26];
            bx0=box_data[6:0]; by0=box_data[12:7];
            bx1=box_data[19:13]; by1=box_data[25:20];
            if (k<I_box_count && x[10:4]>=bx0 && x[10:4]<=bx1 &&
                y[10:4]>=by0 && y[10:4]<=by1 &&
                ((x[10:4]==bx0 && x[3:0]<2) ||
                 (x[10:4]==bx1 && x[3:0]>13) ||
                 (y[10:4]==by0 && y[3:0]<2) ||
                 (y[10:4]==by1 && y[3:0]>13)))
                outline=1;
        end
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x<=0; y<=0; de_d<=0; vs_d<=0;
            O_vsync<=0; O_hsync<=0; O_de<=0; O_rgb<=0;
        end else begin
            de_d<=I_de; vs_d<=I_vsync;
            if (I_vsync && !vs_d) begin x<=0; y<=0; end
            else if (de_d && !I_de) begin x<=0; y<=y+11'd1; end
            else if (I_de) x<=x+11'd1;
            O_vsync<=I_vsync; O_hsync<=I_hsync; O_de<=I_de;
            O_rgb<=I_rgb;
            if (I_enable && I_de) begin
                if (panel) O_rgb<=24'h101820;
                if (border || font_pixel || outline)
                    O_rgb<=24'h80d8ff;
            end
        end
    end
endmodule
