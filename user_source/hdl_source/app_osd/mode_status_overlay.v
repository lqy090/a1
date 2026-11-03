// Six-mode status text, drawn on the active HDMI image.
module mode_status_overlay (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_hsync,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    input  wire [2:0]  I_mode,
    input  wire        I_gamma_enable,
    input  wire        I_mask_enable,
    input  wire        I_box_enable,
    input  wire [2:0]  I_brightness_level,
    input  wire        I_brightness_up,
    input  wire        I_auto_enable,
    output reg         O_vsync,
    output reg         O_hsync,
    output reg         O_de,
    output reg  [23:0] O_rgb
);
    reg [11:0] x, y;
    reg de_d, vs_d;
    reg [2:0] brightness_meta, brightness_sync, brightness_visible;
    reg direction_meta, direction_sync, direction_visible;
    reg auto_visible;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 12'd0; y <= 12'd0; de_d <= 1'b0; vs_d <= 1'b0;
            brightness_meta <= 3'd3; brightness_sync <= 3'd3;
            brightness_visible <= 3'd3;
            direction_meta <= 1'b1; direction_sync <= 1'b1;
            direction_visible <= 1'b1;
            auto_visible <= 1'b0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            brightness_meta <= I_brightness_level;
            brightness_sync <= brightness_meta;
            direction_meta <= I_brightness_up;
            direction_sync <= direction_meta;
            if (I_vsync && !vs_d) begin
                x <= 12'd0; y <= 12'd0;
                brightness_visible <= brightness_sync;
                direction_visible <= direction_sync;
                auto_visible <= I_auto_enable;
            end else if (de_d && !I_de) begin
                x <= 12'd0; y <= y + 12'd1;
            end else if (I_de) begin
                x <= x + 12'd1;
            end
        end
    end

    // 5x7 uppercase font. Codes: 0=space, 1=R, 2=A, 3=W, 4=G, 5=Y,
    // 6=B, 7=I, 8=N, 9=E, 10=D, 11=+, 12=M, 13=S, 14=K,
    // 15=C, 16=T, 17=O, 18=0, 19=1, 20=-, 21=2, 22=3, 23=V,
    // 24=X, 25=F.
    function [4:0] glyph_row;
        input [4:0] ch;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (ch)
                4'd1: case (row) // R
                    0:glyph_row=5'b11110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10100; 5:glyph_row=5'b10010;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                4'd2: case (row) // A
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b11111;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                4'd3: case (row) // W
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b10101;
                    4:glyph_row=5'b10101; 5:glyph_row=5'b10101;
                    6:glyph_row=5'b01010; default:glyph_row=5'b00000;
                endcase
                4'd4: case (row) // G
                    0:glyph_row=5'b01111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b10111;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01111; default:glyph_row=5'b00000;
                endcase
                4'd5: case (row) // Y
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b01010; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00100; default:glyph_row=5'b00000;
                endcase
                4'd6: case (row) // B
                    0:glyph_row=5'b11110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                4'd7: case (row) // I
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00100;
                    2:glyph_row=5'b00100; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b11111; default:glyph_row=5'b00000;
                endcase
                4'd8: case (row) // N
                    0:glyph_row=5'b10001; 1:glyph_row=5'b11001;
                    2:glyph_row=5'b10101; 3:glyph_row=5'b10011;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                4'd9: case (row) // E
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b11110;
                    4:glyph_row=5'b10000; 5:glyph_row=5'b10000;
                    6:glyph_row=5'b11111; default:glyph_row=5'b00000;
                endcase
                4'd10: case (row) // D
                    0:glyph_row=5'b11110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b10001;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                4'd11: case (row) // +
                    0:glyph_row=5'b00000; 1:glyph_row=5'b00100;
                    2:glyph_row=5'b00100; 3:glyph_row=5'b11111;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00000; default:glyph_row=5'b00000;
                endcase
                4'd12: case (row) // M
                    0:glyph_row=5'b10001; 1:glyph_row=5'b11011;
                    2:glyph_row=5'b10101; 3:glyph_row=5'b10101;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                4'd13: case (row) // S
                    0:glyph_row=5'b01111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b01110;
                    4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                4'd14: case (row) // K
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10010;
                    2:glyph_row=5'b10100; 3:glyph_row=5'b11000;
                    4:glyph_row=5'b10100; 5:glyph_row=5'b10010;
                    6:glyph_row=5'b10001; default:glyph_row=5'b00000;
                endcase
                5'd15: case (row) // C
                    0:glyph_row=5'b01111; 1:glyph_row=5'b10000;
                    2:glyph_row=5'b10000; 3:glyph_row=5'b10000;
                    4:glyph_row=5'b10000; 5:glyph_row=5'b10000;
                    6:glyph_row=5'b01111; default:glyph_row=5'b00000;
                endcase
                5'd16: case (row) // T
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00100;
                    2:glyph_row=5'b00100; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00100; default:glyph_row=5'b00000;
                endcase
                5'd17: case (row) // O
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b10001;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'd18: case (row) // 0
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10011; 3:glyph_row=5'b10101;
                    4:glyph_row=5'b11001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'd19: case (row) // 1
                    0:glyph_row=5'b00100; 1:glyph_row=5'b01100;
                    2:glyph_row=5'b00100; 3:glyph_row=5'b00100;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b01110; default:glyph_row=5'b00000;
                endcase
                5'd20: case (row) // -
                    0:glyph_row=5'b00000; 1:glyph_row=5'b00000;
                    2:glyph_row=5'b00000; 3:glyph_row=5'b11111;
                    4:glyph_row=5'b00000; 5:glyph_row=5'b00000;
                    6:glyph_row=5'b00000; default:glyph_row=5'b00000;
                endcase
                5'd21: case (row) // 2
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b00001; 3:glyph_row=5'b00010;
                    4:glyph_row=5'b00100; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b11111; default:glyph_row=5'b00000;
                endcase
                5'd22: case (row) // 3
                    0:glyph_row=5'b11110; 1:glyph_row=5'b00001;
                    2:glyph_row=5'b00001; 3:glyph_row=5'b01110;
                    4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=5'b00000;
                endcase
                5'd23: case (row) // V
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001;
                    2:glyph_row=5'b10001; 3:glyph_row=5'b10001;
                    4:glyph_row=5'b10001; 5:glyph_row=5'b01010;
                    6:glyph_row=5'b00100; default:glyph_row=5'b00000;
                endcase
                5'd24: case (row) // X
                    0,1,5,6:glyph_row=5'b10001;
                    2,4:glyph_row=5'b01010;
                    3:glyph_row=5'b00100;
                endcase
                5'd25: case (row) // F
                    0:glyph_row=5'b11111;
                    1,2,4,5,6:glyph_row=5'b10000;
                    3:glyph_row=5'b11110;
                endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    reg [4:0] char_code;
    wire in_text = (x >= 12'd192 && x < 12'd304 &&
                    y >= 12'd46 && y < 12'd60);
    wire [6:0] text_x = x - 12'd192;
    wire [2:0] char_index = text_x[6:4];
    wire [2:0] font_col = text_x[3:1];
    wire [2:0] font_row = (y - 12'd46) >> 1;
    always @* begin
        char_code = 4'd0;
        case (I_mode)
            3'd0: case (char_index) // Distinguish the diagnostic mask.
                0:char_code=I_mask_enable ? 4'd12 : 4'd1;
                1:char_code=4'd2;
                2:char_code=I_mask_enable ? 4'd13 : 4'd3;
                3:char_code=I_mask_enable ? 4'd14 : (I_gamma_enable ? 4'd11 : 4'd0);
                default:char_code=0;
            endcase
            3'd1: case (char_index) // GRAY
                0:char_code=4; 1:char_code=1; 2:char_code=2; 3:char_code=5;
                default:char_code=0;
            endcase
            3'd2: case (char_index) // BIN
                0:char_code=6; 1:char_code=7; 2:char_code=8;
                default:char_code=0;
            endcase
            3'd3: case (char_index) // EDGE
                0:char_code=9; 1:char_code=10; 2:char_code=4; 3:char_code=9;
                default:char_code=0;
            endcase
            3'd4: case (char_index) // CARTOON
                0:char_code=15; 1:char_code=2; 2:char_code=1;
                3:char_code=16; 4:char_code=17; 5:char_code=17;
                6:char_code=8;
                default:char_code=0;
            endcase
            3'd5: case (char_index) // INVERT
                0:char_code=7; 1:char_code=8; 2:char_code=23;
                3:char_code=9; 4:char_code=1; 5:char_code=16;
                default:char_code=0;
            endcase
        endcase
    end
    wire [4:0] row_bits = glyph_row(char_code, font_row);
    wire font_pixel = in_text && font_col < 5 && row_bits[4-font_col];
    // The final character is the direction for the next single click:
    // B+1- means level +1, currently counting downward.
    wire brightness_panel = (x >= 12'd328 && x < 12'd408 &&
                             y >= 12'd28 && y < 12'd77);
    wire brightness_border = brightness_panel &&
                             (x == 12'd328 || x == 12'd407 ||
                              y == 12'd28 || y == 12'd76);
    wire brightness_text = (x >= 12'd336 && x < 12'd400 &&
                            y >= 12'd46 && y < 12'd60);
    wire [5:0] brightness_text_x = x - 12'd336;
    wire [1:0] brightness_char = brightness_text_x[5:4];
    wire [2:0] brightness_col = brightness_text_x[3:1];
    reg [4:0] brightness_code;
    always @* begin
        case (brightness_char)
            2'd0: brightness_code = 5'd6; // B
            2'd1: brightness_code = (brightness_visible < 3'd3) ? 5'd20 :
                                    (brightness_visible == 3'd3) ? 5'd18 : 5'd11;
            2'd2: begin
                case (brightness_visible)
                    3'd0,3'd6: brightness_code = 5'd22;
                    3'd1,3'd5: brightness_code = 5'd21;
                    3'd2,3'd4: brightness_code = 5'd19;
                    default: brightness_code = 5'd0;
                endcase
            end
            default: brightness_code = direction_visible ? 5'd11 : 5'd20;
        endcase
    end
    wire [4:0] brightness_row_bits = glyph_row(brightness_code, font_row);
    wire brightness_font_pixel = brightness_text && brightness_col < 5 &&
                                 brightness_row_bits[4-brightness_col];
    wire box_panel = x >= 12'd416 && x < 12'd592 &&
                     y >= 12'd28 && y < 12'd77;
    wire box_border = box_panel &&
                      (x == 12'd416 || x == 12'd591 ||
                       y == 12'd28 || y == 12'd76);
    wire box_text = x >= 12'd424 && x < 12'd584 &&
                    y >= 12'd46 && y < 12'd60;
    wire [7:0] box_text_x = x - 12'd424;
    wire [3:0] box_char = box_text_x[7:4];
    wire [2:0] box_col = box_text_x[3:1];
    reg [4:0] box_code;
    always @* begin
        case (box_char)
            4'd0: box_code = 5'd10; // D
            4'd1: box_code = 5'd9;  // E
            4'd2: box_code = 5'd16; // T
            4'd3: box_code = 5'd9;  // E
            4'd4: box_code = 5'd15; // C
            4'd5: box_code = 5'd16; // T
            4'd6: box_code = 5'd0;  // space
            4'd7: box_code = 5'd17; // O
            4'd8: box_code = I_box_enable ? 5'd8 : 5'd25; // N/F
            4'd9: box_code = I_box_enable ? 5'd0 : 5'd25; // space/F
            default: box_code = 5'd0;
        endcase
    end
    wire [4:0] box_row_bits = glyph_row(box_code,font_row);
    wire box_font_pixel = box_text && box_col < 5 &&
                          box_row_bits[4-box_col];
    wire auto_panel = x >= 12'd600 && x < 12'd712 &&
                      y >= 12'd28 && y < 12'd77;
    wire auto_border = auto_panel &&
                       (x == 12'd600 || x == 12'd711 ||
                        y == 12'd28 || y == 12'd76);
    wire auto_text = x >= 12'd608 && x < 12'd704 &&
                     y >= 12'd46 && y < 12'd60;
    wire [6:0] auto_text_x = x - 12'd608;
    wire [2:0] auto_char = auto_text_x[6:4];
    wire [2:0] auto_col = auto_text_x[3:1];
    reg [4:0] auto_code;
    always @* begin
        case (auto_char)
            3'd0: auto_code=5'd2;  // A
            3'd1: auto_code=5'd9;  // E
            3'd2: auto_code=5'd0;
            3'd3: auto_code=5'd17; // O
            3'd4: auto_code=auto_visible ? 5'd8 : 5'd25; // N/F
            3'd5: auto_code=auto_visible ? 5'd0 : 5'd25; // space/F
            default: auto_code=5'd0;
        endcase
    end
    wire [4:0] auto_row_bits = glyph_row(auto_code,font_row);
    wire auto_font_pixel = auto_text && auto_col < 5 &&
                           auto_row_bits[4-auto_col];
    wire panel = (x >= 12'd176 && x < 12'd320 && y >= 12'd28 && y < 12'd77);
    wire border = panel && (x == 12'd176 || x == 12'd319 || y == 12'd28 || y == 12'd76);
    wire [23:0] accent = (I_mode == 3'd0) ? 24'h4eb5ff :
                         (I_mode == 3'd1) ? 24'hb8c2cc :
                         (I_mode == 3'd2) ? 24'hf0d252 :
                         (I_mode == 3'd3) ? 24'hff834e :
                         (I_mode == 3'd4) ? 24'h9bdc80 : 24'hd59cff;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_vsync <= 1'b0; O_hsync <= 1'b0; O_de <= 1'b0; O_rgb <= 24'd0;
        end else begin
            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 24'd0;
            else if (font_pixel || brightness_font_pixel || box_font_pixel || auto_font_pixel)
                O_rgb <= 24'hffffff;
            else if (border) O_rgb <= accent;
            else if (brightness_border) O_rgb <= 24'hf0d252;
            else if (box_border) O_rgb <= I_box_enable ? 24'h40d070 : 24'hb8c2cc;
            else if (auto_border) O_rgb <= auto_visible ? 24'h40d070 : 24'hb8c2cc;
            else if (panel) O_rgb <= 24'h102430;
            else if (brightness_panel) O_rgb <= 24'h102430;
            else if (box_panel) O_rgb <= 24'h102430;
            else if (auto_panel) O_rgb <= 24'h102430;
            else O_rgb <= I_rgb;
        end
    end
endmodule
