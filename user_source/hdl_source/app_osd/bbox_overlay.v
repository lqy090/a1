// One-clock RGB overlay: single-target association, coloured box, colour
// label, centre crosshair, and decimal X/Y coordinates. The detector describes the
// previous complete frame; all tracking state is committed at frame start.
module bbox_overlay #(
    parameter integer TRACK_MAX_STEP = 128
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_vsync,
    input wire I_hsync,
    input wire I_de,
    input wire [23:0] I_rgb,
    input wire I_enable,
    input wire I_valid,
    input wire [2:0] I_color,
    input wire [10:0] I_x0, I_y0, I_x1, I_y1,
    output wire O_track_valid,
    output wire [2:0] O_track_color,
    output wire [10:0] O_track_x0, O_track_y0,
    output wire [10:0] O_track_x1, O_track_y1,
    output reg O_vsync,
    output reg O_hsync,
    output reg O_de,
    output reg [23:0] O_rgb
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    reg valid_q, miss_q;
    reg [2:0] color_q;
    reg [10:0] x0_q, y0_q, x1_q, y1_q;
    reg [10:0] cx_q, cy_q;
    reg [10:0] label_x0_q, label_y0_q;
    assign O_track_valid = valid_q;
    assign O_track_color = color_q;
    assign O_track_x0 = x0_q;
    assign O_track_y0 = y0_q;
    assign O_track_x1 = x1_q;
    assign O_track_y1 = y1_q;

    wire [11:0] cand_cx = ({1'b0,I_x0} + {1'b0,I_x1}) >> 1;
    wire [11:0] cand_cy = ({1'b0,I_y0} + {1'b0,I_y1}) >> 1;
    wire [11:0] dx = cand_cx >= {1'b0,cx_q} ?
                     cand_cx - {1'b0,cx_q} : {1'b0,cx_q} - cand_cx;
    wire [11:0] dy = cand_cy >= {1'b0,cy_q} ?
                     cand_cy - {1'b0,cy_q} : {1'b0,cy_q} - cand_cy;
    wire [11:0] cand_w = {1'b0,I_x1} - {1'b0,I_x0};
    wire [11:0] cand_h = {1'b0,I_y1} - {1'b0,I_y0};
    wire [11:0] old_w = {1'b0,x1_q} - {1'b0,x0_q};
    wire [11:0] old_h = {1'b0,y1_q} - {1'b0,y0_q};
    wire size_match = cand_w <= (old_w << 1) && old_w <= (cand_w << 1) &&
                      cand_h <= (old_h << 1) && old_h <= (cand_h << 1);
    wire track_match = valid_q && I_valid && I_color == color_q &&
                       dx <= TRACK_MAX_STEP && dy <= TRACK_MAX_STEP &&
                       size_match;
    wire take_candidate = I_valid && (!valid_q || track_match || miss_q);

    wire in_box_x = x >= x0_q && x <= x1_q;
    wire in_box_y = y >= y0_q && y <= y1_q;
    wire border = valid_q && in_box_x && in_box_y &&
                  (x <= x0_q + 11'd1 || x + 11'd1 >= x1_q ||
                   y <= y0_q + 11'd1 || y + 11'd1 >= y1_q);
    wire crosshair = valid_q &&
                     ((y == cy_q && x <= cx_q + 11'd6 && x + 11'd6 >= cx_q) ||
                      (x == cx_q && y <= cy_q + 11'd6 && y + 11'd6 >= cy_q));
    wire [23:0] accent = color_q == 3'd1 ? 24'hff4040 :
                         color_q == 3'd2 ? 24'h40a0ff :
                         color_q == 3'd3 ? 24'hffd23f : 24'h40d070;

    // Full colour names are placed just above the box. If the box touches the image
    // top, put the label below it (or inside a nearly full-height box).
    // Store the clamped position with the frame's box to avoid a pixel-path
    // dependency on the detector's next-frame coordinates.
    wire [10:0] label_width = color_q == 3'd3 ? 11'd104 :
                              color_q == 3'd4 ? 11'd88 : 11'd72;
    wire [10:0] candidate_label_width = I_color == 3'd3 ? 11'd104 :
                                        I_color == 3'd4 ? 11'd88 : 11'd72;
    wire label_panel = valid_q &&
                       x >= label_x0_q && x < label_x0_q + label_width &&
                       y >= label_y0_q && y < label_y0_q + 11'd20;
    wire label_text = label_panel &&
                      x >= label_x0_q + 11'd4 &&
                      x < label_x0_q + label_width - 11'd4 &&
                      y >= label_y0_q + 11'd3 && y < label_y0_q + 11'd17;
    wire [6:0] label_tx = x - label_x0_q - 11'd4;
    wire [2:0] label_index = label_tx[6:4];
    wire [2:0] label_col = label_tx[3:1];
    wire [2:0] label_row = (y - label_y0_q - 11'd3) >> 1;
    reg [3:0] label_code;
    always @* begin
        if (color_q == 3'd1) begin
            case (label_index) // RED
                2'd0: label_code = 3'd0; // R
                2'd1: label_code = 3'd1; // E
                2'd2: label_code = 3'd2; // D
                default: label_code = 3'd6;
            endcase
        end else if (color_q == 3'd2) begin
            case (label_index) // BLUE
                2'd0: label_code = 3'd3; // B
                2'd1: label_code = 3'd4; // L
                2'd2: label_code = 3'd5; // U
                2'd3: label_code = 3'd1; // E
                default: label_code = 3'd6;
            endcase
        end else if (color_q == 3'd3) begin
            case (label_index) // YELLOW
                3'd0: label_code = 4'd7;  // Y
                3'd1: label_code = 4'd1;  // E
                3'd2,3'd3: label_code = 4'd4; // L
                3'd4: label_code = 4'd10; // O
                3'd5: label_code = 4'd11; // W
                default: label_code = 4'd6;
            endcase
        end else begin
            case (label_index) // GREEN
                3'd0: label_code = 4'd8; // G
                3'd1: label_code = 4'd0; // R
                3'd2,3'd3: label_code = 4'd1; // E
                3'd4: label_code = 4'd9; // N
                default: label_code = 4'd6;
            endcase
        end
    end
    function [4:0] label_glyph_row;
        input [3:0] ch;
        input [2:0] row;
        begin
            label_glyph_row = 5'b00000;
            case (ch)
                3'd0: case (row) // R
                    0:label_glyph_row=5'b11110; 1,2:label_glyph_row=5'b10001;
                    3:label_glyph_row=5'b11110; 4:label_glyph_row=5'b10100;
                    5:label_glyph_row=5'b10010; 6:label_glyph_row=5'b10001;
                endcase
                3'd1: case (row) // E
                    0,6:label_glyph_row=5'b11111; 1,2,4,5:label_glyph_row=5'b10000;
                    3:label_glyph_row=5'b11110;
                endcase
                3'd2: case (row) // D
                    0,6:label_glyph_row=5'b11110;
                    1,2,3,4,5:label_glyph_row=5'b10001;
                endcase
                3'd3: case (row) // B
                    0,3,6:label_glyph_row=5'b11110;
                    1,2,4,5:label_glyph_row=5'b10001;
                endcase
                3'd4: case (row) // L
                    0,1,2,3,4,5:label_glyph_row=5'b10000;
                    6:label_glyph_row=5'b11111;
                endcase
                3'd5: case (row) // U
                    0,1,2,3,4,5:label_glyph_row=5'b10001;
                    6:label_glyph_row=5'b01110;
                endcase
                4'd7: case (row) // Y
                    0,1:label_glyph_row=5'b10001;
                    2:label_glyph_row=5'b01010;
                    3,4,5,6:label_glyph_row=5'b00100;
                endcase
                4'd8: case (row) // G
                    0:label_glyph_row=5'b01111;
                    1,2:label_glyph_row=5'b10000;
                    3:label_glyph_row=5'b10111;
                    4,5:label_glyph_row=5'b10001;
                    6:label_glyph_row=5'b01111;
                endcase
                4'd9: case (row) // N
                    0,6:label_glyph_row=5'b10001;
                    1:label_glyph_row=5'b11001;
                    2,3:label_glyph_row=5'b10101;
                    4:label_glyph_row=5'b10011;
                    5:label_glyph_row=5'b10001;
                endcase
                4'd10: case (row) // O
                    0,6:label_glyph_row=5'b01110;
                    1,2,3,4,5:label_glyph_row=5'b10001;
                endcase
                4'd11: case (row) // W
                    0,1,2:label_glyph_row=5'b10001;
                    3,4,5:label_glyph_row=5'b10101;
                    6:label_glyph_row=5'b01010;
                endcase
                default: label_glyph_row=5'b00000;
            endcase
        end
    endfunction
    wire [4:0] label_bits = label_glyph_row(label_code,label_row);
    wire label_pixel = label_text && label_col < 3'd5 && label_bits[4-label_col];

    // Double-dabble runs for 11 pixel clocks in vertical blanking, once per
    // video frame. This avoids combinational division on the pixel path.
    reg bcd_start;
    reg [3:0] bcd_left;
    reg [10:0] x_shift, y_shift;
    reg [15:0] x_bcd, y_bcd;
    wire [15:0] x_adj = {
        (x_bcd[15:12] >= 5 ? x_bcd[15:12] + 4'd3 : x_bcd[15:12]),
        (x_bcd[11:8]  >= 5 ? x_bcd[11:8]  + 4'd3 : x_bcd[11:8]),
        (x_bcd[7:4]   >= 5 ? x_bcd[7:4]   + 4'd3 : x_bcd[7:4]),
        (x_bcd[3:0]   >= 5 ? x_bcd[3:0]   + 4'd3 : x_bcd[3:0])
    };
    wire [15:0] y_adj = {
        (y_bcd[15:12] >= 5 ? y_bcd[15:12] + 4'd3 : y_bcd[15:12]),
        (y_bcd[11:8]  >= 5 ? y_bcd[11:8]  + 4'd3 : y_bcd[11:8]),
        (y_bcd[7:4]   >= 5 ? y_bcd[7:4]   + 4'd3 : y_bcd[7:4]),
        (y_bcd[3:0]   >= 5 ? y_bcd[3:0]   + 4'd3 : y_bcd[3:0])
    };

    // Bottom-right panel leaves the original bottom-left diagnostics, Logo
    // and mode status unobstructed. 5x7 glyphs are drawn at 2x scale.
    wire panel = valid_q && x >= 11'd1028 && x < 11'd1260 &&
                 y >= 11'd672 && y < 11'd710;
    wire panel_edge = panel && (x == 11'd1028 || x == 11'd1259 ||
                                y == 11'd672 || y == 11'd709);
    wire text_area = panel && x >= 11'd1040 && x < 11'd1248 &&
                     y >= 11'd683 && y < 11'd697;
    wire [7:0] text_x = x - 11'd1040;
    wire [3:0] char_index = text_x[7:4];
    wire [2:0] font_col = text_x[3:1];
    wire [2:0] font_row = (y - 11'd683) >> 1;
    reg [3:0] char_code;
    always @* begin
        char_code = 4'd15;
        case (char_index) // X:1234 Y:0567
            0: char_code = 4'd10; // X
            1: char_code = 4'd12; // :
            2: char_code = x_bcd[15:12];
            3: char_code = x_bcd[11:8];
            4: char_code = x_bcd[7:4];
            5: char_code = x_bcd[3:0];
            7: char_code = 4'd11; // Y
            8: char_code = 4'd12; // :
            9: char_code = y_bcd[15:12];
            10: char_code = y_bcd[11:8];
            11: char_code = y_bcd[7:4];
            12: char_code = y_bcd[3:0];
            default: char_code = 4'd15;
        endcase
    end
    function [4:0] glyph_row;
        input [3:0] ch;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (ch)
                0: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10011;
                    3:glyph_row=5'b10101; 4:glyph_row=5'b11001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0;
                endcase
                1: case(row)
                    0:glyph_row=5'b00100; 1:glyph_row=5'b01100; 2:glyph_row=5'b00100;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b01110; default:glyph_row=0;
                endcase
                2: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b00001;
                    3:glyph_row=5'b00010; 4:glyph_row=5'b00100; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b11111; default:glyph_row=0;
                endcase
                3: case(row)
                    0:glyph_row=5'b11110; 1:glyph_row=5'b00001; 2:glyph_row=5'b00001;
                    3:glyph_row=5'b01110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=0;
                endcase
                4: case(row)
                    0:glyph_row=5'b00010; 1:glyph_row=5'b00110; 2:glyph_row=5'b01010;
                    3:glyph_row=5'b10010; 4:glyph_row=5'b11111; 5:glyph_row=5'b00010;
                    6:glyph_row=5'b00010; default:glyph_row=0;
                endcase
                5: case(row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000; 2:glyph_row=5'b11110;
                    3:glyph_row=5'b00001; 4:glyph_row=5'b00001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0;
                endcase
                6: case(row)
                    0:glyph_row=5'b00110; 1:glyph_row=5'b01000; 2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0;
                endcase
                7: case(row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00001; 2:glyph_row=5'b00010;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b01000; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b01000; default:glyph_row=0;
                endcase
                8: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001;
                    3:glyph_row=5'b01110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0;
                endcase
                9: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001;
                    3:glyph_row=5'b01111; 4:glyph_row=5'b00001; 5:glyph_row=5'b00010;
                    6:glyph_row=5'b01100; default:glyph_row=0;
                endcase
                10: case(row) // X
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001; 2:glyph_row=5'b01010;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b01010; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=0;
                endcase
                11: case(row) // Y
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001; 2:glyph_row=5'b01010;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00100; default:glyph_row=0;
                endcase
                12: case(row) // :
                    0:glyph_row=5'b00000; 1:glyph_row=5'b00100; 2:glyph_row=5'b00100;
                    3:glyph_row=5'b00000; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00000; default:glyph_row=0;
                endcase
                default: glyph_row=0;
            endcase
        end
    endfunction
    wire [4:0] row_bits = glyph_row(char_code,font_row);
    wire font_pixel = text_area && font_col < 5 && row_bits[4-font_col];

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            valid_q <= 0; miss_q <= 0; color_q <= 0;
            x0_q <= 0; y0_q <= 0; x1_q <= 0; y1_q <= 0;
            cx_q <= 0; cy_q <= 0;
            label_x0_q <= 0; label_y0_q <= 0;
            bcd_start <= 0; bcd_left <= 0;
            x_shift <= 0; y_shift <= 0; x_bcd <= 0; y_bcd <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin
                x <= 0; y <= 0;
                bcd_start <= 1;
                if (!I_enable) begin
                    valid_q <= 0; miss_q <= 0; color_q <= 0;
                end else if (take_candidate) begin
                    valid_q <= 1; miss_q <= 0; color_q <= I_color;
                    x0_q <= I_x0; y0_q <= I_y0;
                    x1_q <= I_x1; y1_q <= I_y1;
                    cx_q <= cand_cx[10:0]; cy_q <= cand_cy[10:0];
                    label_x0_q <= I_x0 > 11'd1280 - candidate_label_width ?
                                   11'd1280 - candidate_label_width : I_x0;
                    label_y0_q <= I_y0 >= 11'd24 ? I_y0 - 11'd24 :
                                  I_y1 <= 11'd696 ? I_y1 + 11'd4 : I_y0 + 11'd4;
                end else if (valid_q && !miss_q) begin
                    miss_q <= 1; // hold one missed/implausible frame
                end else begin
                    valid_q <= 0; miss_q <= 0; color_q <= 0;
                end
            end else if (de_d && !I_de) begin
                x <= 0; y <= y + 1'b1;
            end else if (I_de) x <= x + 1'b1;

            if (bcd_start && !(I_vsync && !vs_d)) begin
                bcd_start <= 0; bcd_left <= 4'd11;
                x_shift <= cx_q; y_shift <= cy_q;
                x_bcd <= 0; y_bcd <= 0;
            end else if (bcd_left != 0) begin
                x_bcd <= {x_adj[14:0],x_shift[10]};
                y_bcd <= {y_adj[14:0],y_shift[10]};
                x_shift <= {x_shift[9:0],1'b0};
                y_shift <= {y_shift[9:0],1'b0};
                bcd_left <= bcd_left - 1'b1;
            end

            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 24'd0;
            else if (!I_enable) O_rgb <= I_rgb;
            else if (font_pixel) O_rgb <= 24'hffffff;
            else if (panel_edge) O_rgb <= accent;
            else if (panel) O_rgb <= 24'h101820;
            else if (label_pixel) O_rgb <= 24'hffffff;
            else if (label_panel) O_rgb <= accent;
            else if (crosshair) O_rgb <= 24'hffffff;
            else if (border) O_rgb <= accent;
            else O_rgb <= I_rgb;
        end
    end
endmodule
