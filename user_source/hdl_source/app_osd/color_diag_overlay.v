// Diagnostic view after the existing bbox stage and before Logo/mode OSD.
// The source RGB takes three clocks through video_fx_pipeline and one through
// bbox_overlay. At this module's sampling edge, raw_pipe[3] is aligned with
// I_rgb/I_de from those stages. Counts come from the previous complete frame.
module color_diag_overlay (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_vsync,
    input wire I_hsync,
    input wire I_de,
    input wire [23:0] I_rgb,
    input wire [23:0] I_raw_rgb,
    input wire I_mask_enable,
    input wire I_hide_panel,
    input wire [19:0] I_red_pixels,
    input wire [19:0] I_blue_pixels,
    output reg O_vsync,
    output reg O_hsync,
    output reg O_de,
    output reg [23:0] O_rgb
);
    reg [23:0] raw_pipe [0:3];
    reg [10:0] x, y;
    reg de_d, vs_d;
    wire [8:0] r = {1'b0,raw_pipe[3][23:16]};
    wire [8:0] g = {1'b0,raw_pipe[3][15:8]};
    wire [8:0] b = {1'b0,raw_pipe[3][7:0]};
    wire red_mask = r >= 9'd64 && r > g + 9'd24 && r > b + 9'd24;
    wire blue_mask = b >= 9'd64 && b > r + 9'd24 && b > g + 9'd16;

    // Bottom-left panel: first row is Rxxxxx Bxxxxx (hex sampled-pixel counts).
    // Second row is Rxx Gxx Bxx (hex mean of 64 central pixels after AWB).
    // The detector samples one pixel in every 2x2 block, so counts are /4.
    reg [13:0] center_r_sum, center_g_sum, center_b_sum;
    reg [6:0] center_samples;
    reg [7:0] center_r, center_g, center_b;
    wire center_sample = I_de && x >= 11'd632 && x < 11'd648 &&
                         y >= 11'd352 && y < 11'd368 && !x[0] && !y[0];
    wire panel = !I_hide_panel && x >= 11'd16 && x < 11'd240 && y >= 11'd660 && y < 11'd706;
    wire [10:0] tx = x - 11'd24;
    wire second_row = y >= 11'd686;
    wire [10:0] ty = second_row ? y - 11'd686 : y - 11'd670;
    wire text_area = !I_hide_panel && x >= 11'd24 && x < 11'd232 &&
                     ((y >= 11'd670 && y < 11'd684) ||
                      (y >= 11'd686 && y < 11'd700));
    wire [3:0] char_index = tx[7:4];
    wire [2:0] glyph_x = tx[3:1];
    wire [2:0] glyph_y = ty[3:1];
    reg [4:0] char_code;
    reg [4:0] row_bits;
    wire text_pixel = text_area && glyph_x < 3'd5 && row_bits[4-glyph_x];
    wire [23:0] text_color = second_row ? 24'he0e0e0 :
                             (char_index < 4'd7 ? 24'hff7070 : 24'h60b0ff);

    always @* begin
        char_code = 5'd18;
        if (!second_row) begin
            case (char_index)
                4'd0: char_code = 5'd16; // R
                4'd1: char_code = {1'b0,I_red_pixels[19:16]};
                4'd2: char_code = {1'b0,I_red_pixels[15:12]};
                4'd3: char_code = {1'b0,I_red_pixels[11:8]};
                4'd4: char_code = {1'b0,I_red_pixels[7:4]};
                4'd5: char_code = {1'b0,I_red_pixels[3:0]};
                4'd7: char_code = 5'd17; // B
                4'd8: char_code = {1'b0,I_blue_pixels[19:16]};
                4'd9: char_code = {1'b0,I_blue_pixels[15:12]};
                4'd10: char_code = {1'b0,I_blue_pixels[11:8]};
                4'd11: char_code = {1'b0,I_blue_pixels[7:4]};
                4'd12: char_code = {1'b0,I_blue_pixels[3:0]};
                default: char_code = 5'd18;
            endcase
        end else begin
            case (char_index)
                4'd0: char_code = 5'd16; // R
                4'd1: char_code = {1'b0,center_r[7:4]};
                4'd2: char_code = {1'b0,center_r[3:0]};
                4'd4: char_code = 5'd19; // G
                4'd5: char_code = {1'b0,center_g[7:4]};
                4'd6: char_code = {1'b0,center_g[3:0]};
                4'd8: char_code = 5'd17; // B
                4'd9: char_code = {1'b0,center_b[7:4]};
                4'd10: char_code = {1'b0,center_b[3:0]};
                default: char_code = 5'd18;
            endcase
        end
        row_bits = glyph5(char_code, glyph_y);
    end

    // 5x7 hex font. Bits run left to right from [4] to [0].
    function [4:0] glyph5;
        input [4:0] code;
        input [2:0] row;
        begin
            glyph5 = 5'b00000;
            case (code)
                5'h00: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10001;2:glyph5=5'b10011;3:glyph5=5'b10101;4:glyph5=5'b11001;5:glyph5=5'b10001;6:glyph5=5'b01110;endcase
                5'h01: case(row) 0:glyph5=5'b00100;1:glyph5=5'b01100;2:glyph5=5'b00100;3:glyph5=5'b00100;4:glyph5=5'b00100;5:glyph5=5'b00100;6:glyph5=5'b01110;endcase
                5'h02: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10001;2:glyph5=5'b00001;3:glyph5=5'b00010;4:glyph5=5'b00100;5:glyph5=5'b01000;6:glyph5=5'b11111;endcase
                5'h03: case(row) 0:glyph5=5'b11110;1:glyph5=5'b00001;2:glyph5=5'b00001;3:glyph5=5'b01110;4:glyph5=5'b00001;5:glyph5=5'b00001;6:glyph5=5'b11110;endcase
                5'h04: case(row) 0:glyph5=5'b00010;1:glyph5=5'b00110;2:glyph5=5'b01010;3:glyph5=5'b10010;4:glyph5=5'b11111;5:glyph5=5'b00010;6:glyph5=5'b00010;endcase
                5'h05: case(row) 0:glyph5=5'b11111;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b11110;4:glyph5=5'b00001;5:glyph5=5'b00001;6:glyph5=5'b11110;endcase
                5'h06: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b11110;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b01110;endcase
                5'h07: case(row) 0:glyph5=5'b11111;1:glyph5=5'b00001;2:glyph5=5'b00010;3:glyph5=5'b00100;4:glyph5=5'b01000;5:glyph5=5'b01000;6:glyph5=5'b01000;endcase
                5'h08: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b01110;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b01110;endcase
                5'h09: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b01111;4:glyph5=5'b00001;5:glyph5=5'b00001;6:glyph5=5'b01110;endcase
                5'h0a: case(row) 0:glyph5=5'b01110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b11111;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b10001;endcase
                5'h0b: case(row) 0:glyph5=5'b11110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b11110;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b11110;endcase
                5'h0c: case(row) 0:glyph5=5'b01111;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b10000;4:glyph5=5'b10000;5:glyph5=5'b10000;6:glyph5=5'b01111;endcase
                5'h0d: case(row) 0:glyph5=5'b11110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b10001;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b11110;endcase
                5'h0e: case(row) 0:glyph5=5'b11111;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b11110;4:glyph5=5'b10000;5:glyph5=5'b10000;6:glyph5=5'b11111;endcase
                5'h0f: case(row) 0:glyph5=5'b11111;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b11110;4:glyph5=5'b10000;5:glyph5=5'b10000;6:glyph5=5'b10000;endcase
                5'd16: case(row) 0:glyph5=5'b11110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b11110;4:glyph5=5'b10100;5:glyph5=5'b10010;6:glyph5=5'b10001;endcase // R
                5'd17: case(row) 0:glyph5=5'b11110;1:glyph5=5'b10001;2:glyph5=5'b10001;3:glyph5=5'b11110;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b11110;endcase // B
                5'd19: case(row) 0:glyph5=5'b01111;1:glyph5=5'b10000;2:glyph5=5'b10000;3:glyph5=5'b10111;4:glyph5=5'b10001;5:glyph5=5'b10001;6:glyph5=5'b01110;endcase // G
                default: glyph5=5'b00000;
            endcase
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            raw_pipe[0] <= 24'd0; raw_pipe[1] <= 24'd0;
            raw_pipe[2] <= 24'd0; raw_pipe[3] <= 24'd0;
            center_r_sum <= 0; center_g_sum <= 0; center_b_sum <= 0;
            center_samples <= 0;
            center_r <= 0; center_g <= 0; center_b <= 0;
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            raw_pipe[0] <= I_raw_rgb;
            raw_pipe[1] <= raw_pipe[0];
            raw_pipe[2] <= raw_pipe[1];
            raw_pipe[3] <= raw_pipe[2];
            de_d <= I_de;
            vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin
                if (center_samples == 7'd64) begin
                    center_r <= center_r_sum[13:6];
                    center_g <= center_g_sum[13:6];
                    center_b <= center_b_sum[13:6];
                end
                center_r_sum <= 0;
                center_g_sum <= 0;
                center_b_sum <= 0;
                center_samples <= 0;
                x <= 0; y <= 0;
            end else if (de_d && !I_de) begin
                x <= 0; y <= y + 1'b1;
            end else if (I_de) begin
                x <= x + 1'b1;
            end
            if (center_sample) begin
                center_r_sum <= center_r_sum + r[7:0];
                center_g_sum <= center_g_sum + g[7:0];
                center_b_sum <= center_b_sum + b[7:0];
                center_samples <= center_samples + 1'b1;
            end
            O_vsync <= I_vsync;
            O_hsync <= I_hsync;
            O_de <= I_de;
            if (!I_de) O_rgb <= 24'd0;
            else if (text_pixel) O_rgb <= text_color;
            else if (panel) O_rgb <= 24'h101820;
            else if (I_mask_enable) begin
                if (red_mask) O_rgb <= 24'hff2020;
                else if (blue_mask) O_rgb <= 24'h2070ff;
                else O_rgb <= 24'h080808;
            end else O_rgb <= I_rgb;
        end
    end
endmodule
