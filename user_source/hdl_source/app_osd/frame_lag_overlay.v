// Upper-right panel: frame age, DDR-buffer time and CSI-to-HDMI time.
module frame_lag_overlay (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire [3:0] I_lag_frames,
    input wire [6:0] I_latency_ms,
    input wire I_lag_valid,
    input wire [6:0] I_capture_latency_ms,
    input wire I_capture_valid,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    reg [11:0] x, y;
    reg de_d, vs_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin x <= 0; y <= 0; end
            else if (de_d && !I_de) begin x <= 0; y <= y + 12'd1; end
            else if (I_de) x <= x + 12'd1;
        end
    end

    // 5x7 glyphs: 0 space, 1 L, 2 A, 3 G, 4 F, 5..14 digits 0..9,
    // 15 dash, 16 M, 17 S, 18 C, 19 H, 20 B, 21 U.
    function [4:0] glyph_row;
        input [4:0] ch;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (ch)
                4'd1: case (row) // L
                    0,1,2,3,4,5:glyph_row=5'b10000;
                    6:glyph_row=5'b11111;
                endcase
                4'd2: case (row) // A
                    0:glyph_row=5'b01110; 1,2:glyph_row=5'b10001;
                    3:glyph_row=5'b11111; 4,5,6:glyph_row=5'b10001;
                endcase
                4'd3: case (row) // G
                    0:glyph_row=5'b01111; 1,2:glyph_row=5'b10000;
                    3:glyph_row=5'b10111; 4,5:glyph_row=5'b10001;
                    6:glyph_row=5'b01111;
                endcase
                4'd4: case (row) // F
                    0:glyph_row=5'b11111; 1,2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4,5,6:glyph_row=5'b10000;
                endcase
                4'd5: case (row) // 0
                    0,6:glyph_row=5'b01110; 1,2,3,4,5:glyph_row=5'b10001;
                endcase
                4'd6: case (row) // 1
                    0:glyph_row=5'b00100; 1:glyph_row=5'b01100;
                    2,3,4,5:glyph_row=5'b00100; 6:glyph_row=5'b01110;
                endcase
                4'd7: case (row) // 2
                    0:glyph_row=5'b01110; 1,2:glyph_row=5'b10001;
                    3:glyph_row=5'b00010; 4:glyph_row=5'b00100;
                    5:glyph_row=5'b01000; 6:glyph_row=5'b11111;
                endcase
                4'd8: case (row) // 3
                    0:glyph_row=5'b11110; 1,2:glyph_row=5'b00001;
                    3:glyph_row=5'b01110; 4,5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110;
                endcase
                4'd9: case (row) // 4
                    0,1,2:glyph_row=5'b10010; 3:glyph_row=5'b11111;
                    4,5,6:glyph_row=5'b00010;
                endcase
                4'd10: case (row) // 5
                    0:glyph_row=5'b11111; 1,2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4,5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110;
                endcase
                4'd11: case (row) // 6
                    0:glyph_row=5'b01111; 1,2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4,5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110;
                endcase
                4'd12: case (row) // 7
                    0:glyph_row=5'b11111; 1,2:glyph_row=5'b00001;
                    3:glyph_row=5'b00010; 4:glyph_row=5'b00100;
                    5,6:glyph_row=5'b01000;
                endcase
                4'd13: case (row) // 8
                    0,3,6:glyph_row=5'b01110;
                    1,2,4,5:glyph_row=5'b10001;
                endcase
                4'd14: case (row) // 9
                    0:glyph_row=5'b01110; 1,2:glyph_row=5'b10001;
                    3:glyph_row=5'b01111; 4,5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110;
                endcase
                4'd15: if (row == 3) glyph_row=5'b11111; // -
                5'd16: case (row) // M
                    0:glyph_row=5'b10001; 1:glyph_row=5'b11011;
                    2,3,4,5,6:glyph_row=5'b10101;
                endcase
                5'd17: case (row) // S
                    0:glyph_row=5'b01111; 1,2:glyph_row=5'b10000;
                    3:glyph_row=5'b01110; 4,5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110;
                endcase
                5'd18: case (row) // C
                    0,6:glyph_row=5'b01111;
                    1,2,3,4,5:glyph_row=5'b10000;
                endcase
                5'd19: case (row) // H
                    0,1,2,4,5,6:glyph_row=5'b10001;
                    3:glyph_row=5'b11111;
                endcase
                5'd20: case (row) // B
                    0,3,6:glyph_row=5'b11110;
                    1,2,4,5:glyph_row=5'b10001;
                endcase
                5'd21: case (row) // U
                    0,1,2,3,4,5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110;
                endcase
                default:glyph_row=5'b00000;
            endcase
        end
    endfunction

    wire panel = x >= 12'd1084 && x < 12'd1236 &&
                 y >= 12'd28 && y < 12'd118;
    wire border = panel && (x == 12'd1084 || x == 12'd1235 ||
                            y == 12'd28 || y == 12'd117);
    wire top_text = x >= 12'd1096 && x < 12'd1208 &&
                    y >= 12'd46 && y < 12'd60;
    wire middle_text = x >= 12'd1096 && x < 12'd1224 &&
                       y >= 12'd68 && y < 12'd82;
    wire bottom_text = x >= 12'd1096 && x < 12'd1224 &&
                       y >= 12'd90 && y < 12'd104;
    wire [6:0] text_x = x - 12'd1096;
    wire [2:0] char_index = text_x[6:4];
    wire [2:0] col = text_x[3:1];
    wire [2:0] row = top_text ? ((y - 12'd46) >> 1) :
                     middle_text ? ((y - 12'd68) >> 1) :
                                   ((y - 12'd90) >> 1);
    reg [3:0] tens, capture_tens;
    always @* begin
        if (I_latency_ms >= 7'd90) tens=9;
        else if (I_latency_ms >= 7'd80) tens=8;
        else if (I_latency_ms >= 7'd70) tens=7;
        else if (I_latency_ms >= 7'd60) tens=6;
        else if (I_latency_ms >= 7'd50) tens=5;
        else if (I_latency_ms >= 7'd40) tens=4;
        else if (I_latency_ms >= 7'd30) tens=3;
        else if (I_latency_ms >= 7'd20) tens=2;
        else if (I_latency_ms >= 7'd10) tens=1;
        else tens=0;
        if (I_capture_latency_ms >= 7'd90) capture_tens=9;
        else if (I_capture_latency_ms >= 7'd80) capture_tens=8;
        else if (I_capture_latency_ms >= 7'd70) capture_tens=7;
        else if (I_capture_latency_ms >= 7'd60) capture_tens=6;
        else if (I_capture_latency_ms >= 7'd50) capture_tens=5;
        else if (I_capture_latency_ms >= 7'd40) capture_tens=4;
        else if (I_capture_latency_ms >= 7'd30) capture_tens=3;
        else if (I_capture_latency_ms >= 7'd20) capture_tens=2;
        else if (I_capture_latency_ms >= 7'd10) capture_tens=1;
        else capture_tens=0;
    end
    wire [6:0] ones = I_latency_ms - (({3'd0,tens} << 3) + ({3'd0,tens} << 1));
    wire [6:0] capture_ones = I_capture_latency_ms -
                             (({3'd0,capture_tens} << 3) + ({3'd0,capture_tens} << 1));
    reg [4:0] ch;
    always @* begin
        ch = 5'd0;
        if (top_text) begin
            case (char_index)
                0:ch=5'd1; // L
                1:ch=5'd2; // A
                2:ch=5'd3; // G
                4:ch=I_lag_valid ? (5'd5 + I_lag_frames) : 5'd15;
                5:ch=I_lag_valid ? 5'd4 : 5'd15; // F / -
                default:ch=5'd0;
            endcase
        end else if (middle_text) begin
            case (char_index)
                0:ch=5'd20; // B
                1:ch=5'd21; // U
                2:ch=5'd4;  // F
                4:ch=I_lag_valid ? (5'd5 + tens) : 5'd15;
                5:ch=I_lag_valid ? (5'd5 + ones[3:0]) : 5'd15;
                6:ch=I_lag_valid ? 5'd16 : 5'd0; // M
                7:ch=I_lag_valid ? 5'd17 : 5'd0; // S
                default:ch=5'd0;
            endcase
        end else if (bottom_text) begin
            case (char_index)
                0:ch=5'd18; // C
                1:ch=5'd7;  // 2
                2:ch=5'd19; // H
                4:ch=I_capture_valid ? (5'd5 + capture_tens) : 5'd15;
                5:ch=I_capture_valid ? (5'd5 + capture_ones[3:0]) : 5'd15;
                6:ch=I_capture_valid ? 5'd16 : 5'd0; // M
                7:ch=I_capture_valid ? 5'd17 : 5'd0; // S
                default:ch=5'd0;
            endcase
        end
    end
    wire [4:0] bits = glyph_row(ch,row);
    wire letter = (top_text || middle_text || bottom_text) && col < 5 && bits[4-col];
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 24'd0;
            else if (letter) O_rgb <= 24'hffffff;
            else if (border) O_rgb <= 24'h4eb5ff;
            else if (panel) O_rgb <= 24'h102430;
            else O_rgb <= I_rgb;
        end
    end
endmodule
