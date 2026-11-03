// Eight compact, single-line colour/shape totals and one fixed conveyor gate.
// The gate appears only while KEY2's counter is enabled. Its coordinates are
// calibrated to stationary marks on the conveyor frame, not to the moving belt.
module conveyor_count_overlay #(
    parameter [10:0] LINE_X = 11'd800,
    parameter [10:0] BELT_Y0 = 11'd140,
    parameter [10:0] BELT_Y1 = 11'd620
) (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable,
    input wire [127:0] I_counts,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    reg [10:0] x, y;
    reg de_d, vs_d, enable_q;
    wire frame_start = I_vsync && !vs_d;
    wire panel = enable_q && x >= 11'd16 && x < 11'd400 &&
                 y >= 11'd110 && y < 11'd548;
    wire gate = enable_q && x >= LINE_X && x < LINE_X + 11'd2 &&
                y >= BELT_Y0 && y <= BELT_Y1;
    reg [3:0] row_sel;
    reg row_valid;
    reg [10:0] row_y;
    integer r;
    always @* begin
        row_sel = 0; row_valid = 0; row_y = 0;
        for (r=0; r<8; r=r+1) begin
            if (y >= (11'd150 + r*50) && y < (11'd174 + r*50)) begin
                row_sel = r;
                row_valid = 1;
                row_y = 11'd150 + r*50;
            end
        end
    end
    wire header_text = enable_q && x >= 11'd24 && x < 11'd216 &&
                       y >= 11'd120 && y < 11'd134;
    wire item_text = enable_q && row_valid && x >= 11'd24 && x < 11'd392 &&
                     y >= row_y && y < row_y + 11'd14;
    wire [8:0] item_tx = x - 11'd24;
    wire [4:0] char_index = item_tx[8:4];
    wire [2:0] font_col = item_tx[3:1];
    wire [2:0] font_row = (header_text ? y - 11'd120 : y - row_y) >> 1;
    wire [15:0] count_bcd = I_counts[row_sel*16 +: 16];
    reg [7:0] letter;
    reg [7:0] color_letter, shape_letter;
    reg [3:0] color_id, shape_id;
    reg [4:0] shape_pos;
    always @* begin
        // RED, BLUE, YELLOW, GREEN; RECTANGLE then TRIANGLE for each colour.
        color_id = {1'b0,row_sel[3:1]};
        shape_id = {3'b0,row_sel[0]};
        color_letter = " ";
        case (color_id)
            0: case (char_index)
                0:color_letter="R"; 1:color_letter="E"; 2:color_letter="D";
            endcase
            1: case (char_index)
                0:color_letter="B"; 1:color_letter="L";
                2:color_letter="U"; 3:color_letter="E";
            endcase
            2: case (char_index)
                0:color_letter="Y"; 1:color_letter="E";
                2,3:color_letter="L"; 4:color_letter="O"; 5:color_letter="W";
            endcase
            3: case (char_index)
                0:color_letter="G"; 1:color_letter="R";
                2,3:color_letter="E"; 4:color_letter="N";
            endcase
        endcase
        shape_pos = char_index - (color_id == 0 ? 5'd4 : color_id == 1 ? 5'd5 :
                                  color_id == 2 ? 5'd7 : 5'd6);
        shape_letter = " ";
        case (shape_id)
            0: case (shape_pos) // RECTANGLE
                0:shape_letter="R"; 1:shape_letter="E"; 2:shape_letter="C";
                3:shape_letter="T"; 4:shape_letter="A"; 5:shape_letter="N";
                6:shape_letter="G"; 7:shape_letter="L"; 8:shape_letter="E";
            endcase
            1: case (shape_pos) // TRIANGLE
                0:shape_letter="T"; 1:shape_letter="R"; 2:shape_letter="I";
                3:shape_letter="A"; 4:shape_letter="N"; 5:shape_letter="G";
                6:shape_letter="L"; 7:shape_letter="E";
            endcase
        endcase
        letter = " ";
        if (header_text) begin
            case (char_index) // COUNT ON
                0:letter="C"; 1:letter="O"; 2:letter="U";
                3:letter="N"; 4:letter="T"; 6:letter="O"; 7:letter="N";
            endcase
        end else if (item_text) begin
            if (char_index < 5'd16) begin
                if (color_letter != " ") letter = color_letter;
                else letter = shape_letter;
            end else if (char_index == 5'd18) letter = "0" + {4'd0,count_bcd[11:8]};
            else if (char_index == 5'd19) letter = "0" + {4'd0,count_bcd[7:4]};
            else if (char_index == 5'd20) letter = "0" + {4'd0,count_bcd[3:0]};
        end
    end
    function [4:0] glyph;
        input [7:0] c;
        input [2:0] row;
        begin
            glyph = 0;
            case (c)
                "0": case(row) 0,6:glyph=5'b01110;1,5:glyph=5'b10001;2:glyph=5'b10011;3:glyph=5'b10101;4:glyph=5'b11001;endcase
                "1": case(row) 0:glyph=5'b00100;1:glyph=5'b01100;2,3,4,5:glyph=5'b00100;6:glyph=5'b01110;endcase
                "2": case(row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b00001;3:glyph=5'b00010;4:glyph=5'b00100;5:glyph=5'b01000;6:glyph=5'b11111;endcase
                "3": case(row) 0:glyph=5'b11110;1,2:glyph=5'b00001;3:glyph=5'b01110;4,5:glyph=5'b00001;6:glyph=5'b11110;endcase
                "4": case(row) 0:glyph=5'b00010;1:glyph=5'b00110;2:glyph=5'b01010;3:glyph=5'b10010;4:glyph=5'b11111;5,6:glyph=5'b00010;endcase
                "5": case(row) 0:glyph=5'b11111;1,2:glyph=5'b10000;3:glyph=5'b11110;4,5:glyph=5'b00001;6:glyph=5'b11110;endcase
                "6": case(row) 0:glyph=5'b01110;1,2:glyph=5'b10000;3:glyph=5'b11110;4,5:glyph=5'b10001;6:glyph=5'b01110;endcase
                "7": case(row) 0:glyph=5'b11111;1:glyph=5'b00001;2:glyph=5'b00010;3:glyph=5'b00100;4,5,6:glyph=5'b01000;endcase
                "8": case(row) 0,3,6:glyph=5'b01110;1,2,4,5:glyph=5'b10001;endcase
                "9": case(row) 0:glyph=5'b01110;1,2:glyph=5'b10001;3:glyph=5'b01111;4,5:glyph=5'b00001;6:glyph=5'b01110;endcase
                "A": case(row) 0:glyph=5'b01110;1,2:glyph=5'b10001;3:glyph=5'b11111;4,5,6:glyph=5'b10001;endcase
                "B": case(row) 0,3,6:glyph=5'b11110;1,2,4,5:glyph=5'b10001;endcase
                "C": case(row) 0,6:glyph=5'b01111;1,2,3,4,5:glyph=5'b10000;endcase
                "D": case(row) 0,6:glyph=5'b11110;1,2,3,4,5:glyph=5'b10001;endcase
                "E": case(row) 0,3,6:glyph=5'b11111;1,2,4,5:glyph=5'b10000;endcase
                "G": case(row) 0:glyph=5'b01111;1,2:glyph=5'b10000;3:glyph=5'b10111;4,5:glyph=5'b10001;6:glyph=5'b01111;endcase
                "I": case(row) 0,6:glyph=5'b01110;1,2,3,4,5:glyph=5'b00100;endcase
                "L": case(row) 0,1,2,3,4,5:glyph=5'b10000;6:glyph=5'b11111;endcase
                "N": case(row) 0,6:glyph=5'b10001;1:glyph=5'b11001;2,3:glyph=5'b10101;4,5:glyph=5'b10011;endcase
                "O": case(row) 0,6:glyph=5'b01110;1,2,3,4,5:glyph=5'b10001;endcase
                "Q": case(row) 0:glyph=5'b01110;1,2,3:glyph=5'b10001;4:glyph=5'b10101;5:glyph=5'b10010;6:glyph=5'b01101;endcase
                "R": case(row) 0,3:glyph=5'b11110;1,2:glyph=5'b10001;4:glyph=5'b10100;5:glyph=5'b10010;6:glyph=5'b10001;endcase
                "S": case(row) 0,6:glyph=5'b01111;1,2:glyph=5'b10000;3:glyph=5'b01110;4,5:glyph=5'b00001;endcase
                "T": case(row) 0:glyph=5'b11111;1,2,3,4,5,6:glyph=5'b00100;endcase
                "U": case(row) 0,1,2,3,4,5:glyph=5'b10001;6:glyph=5'b01110;endcase
                "W": case(row) 0,1,2:glyph=5'b10001;3,4,5:glyph=5'b10101;6:glyph=5'b01010;endcase
                "Y": case(row) 0,1:glyph=5'b10001;2:glyph=5'b01010;3,4,5,6:glyph=5'b00100;endcase
            endcase
        end
    endfunction
    wire [4:0] bits = glyph(letter,font_row);
    wire text_pixel = (header_text || item_text) && font_col < 5 && bits[4-font_col];
    wire [23:0] accent = row_sel < 2 ? 24'hff6060 :
                         row_sel < 4 ? 24'h60aaff :
                         row_sel < 6 ? 24'hffe050 : 24'h70e090;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0; enable_q <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (frame_start) begin
                x <= 0; y <= 0; enable_q <= I_enable;
            end else if (de_d && !I_de) begin
                x <= 0; y <= y + 1'b1;
            end else if (I_de) x <= x + 1'b1;
            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 0;
            else if (text_pixel) O_rgb <= item_text ? accent : 24'hffffff;
            else if (gate) O_rgb <= 24'hffffff;
            else if (panel) O_rgb <= 24'h101a27;
            else O_rgb <= I_rgb;
        end
    end
endmodule
