// One-pass red/blue/yellow/green card detector in the HDMI pixel clock domain.
// Results are committed at frame start and describe the previous full frame.
module color_card_detect #(
    parameter integer WIDTH = 1280,
    parameter integer HEIGHT = 720,
    parameter integer MIN_PIXELS = 192,
    parameter integer MIN_SPAN = 12,
    parameter integer RUN_MIN = 3
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_vsync,
    input wire I_de,
    input wire [23:0] I_rgb,
    output reg O_valid,
    output reg [2:0] O_color, // 1=red, 2=blue, 3=yellow, 4=green
    output reg [19:0] O_red_pixels,
    output reg [19:0] O_blue_pixels,
    output reg [10:0] O_x0,
    output reg [10:0] O_y0,
    output reg [10:0] O_x1,
    output reg [10:0] O_y1,
    output wire [3:0] O_shape_mask
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    reg [19:0] red_count, blue_count;
    reg [19:0] yellow_count, green_count;
    reg [10:0] red_x0, red_y0, red_x1, red_y1;
    reg [10:0] blue_x0, blue_y0, blue_x1, blue_y1;
    reg [10:0] yellow_x0, yellow_y0, yellow_x1, yellow_y1;
    reg [10:0] green_x0, green_y0, green_x1, green_y1;
    reg [9:0] red_run_len, blue_run_len;
    reg [9:0] yellow_run_len, green_run_len;
    reg [10:0] red_run_x0, red_run_x1;
    reg [10:0] blue_run_x0, blue_run_x1;
    // For blue, keep the longest contiguous run on each sampled row, then
    // join overlapping runs on nearby rows. A remote blue-tinted highlight
    // cannot stretch the box around the main object.
    reg [9:0] blue_row_len;
    reg [10:0] blue_row_x0, blue_row_x1;
    reg blue_band_active;
    reg [19:0] blue_band_count, blue_best_count;
    reg [10:0] blue_band_x0, blue_band_y0, blue_band_x1, blue_band_y1;
    reg [10:0] blue_best_x0, blue_best_y0, blue_best_x1, blue_best_y1;
    reg [10:0] blue_band_last_y;
    reg [10:0] yellow_run_x0, yellow_run_x1;
    reg [10:0] green_run_x0, green_run_x1;
    wire [19:0] red_selected_count;
    wire [10:0] red_selected_x0, red_selected_y0, red_selected_x1, red_selected_y1;
    wire frame_start = I_vsync && !vs_d;
    wire line_end = de_d && !I_de;
    wire [8:0] r = {1'b0,I_rgb[23:16]};
    wire [8:0] g = {1'b0,I_rgb[15:8]};
    wire [8:0] b = {1'b0,I_rgb[7:0]};
    // Both channel difference and absolute level are required to reject
    // dark sensor noise and neutral highlights. Sample every second pixel
    // in each direction to keep the feature counter and timing modest.
    wire sample = I_de && x < WIDTH && y < HEIGHT && !x[0] && !y[0];
    // Red uses a 3:2 ratio against both other channels. Blue only needs that
    // ratio against red: at 6x gain its green channel can rise substantially,
    // while neutral blue-tinted highlights still have blue near red.
    wire is_red = sample && r >= 9'd64 && r > g + 9'd24 && r > b + 9'd24 &&
                  r > g + (g >> 1) && r > b + (b >> 1);
    wire is_blue = sample && b >= 9'd64 && b > r + 9'd24 && b > g + 9'd16 &&
                   b > r + (r >> 1);
    // Reject neutral highlights and skin: yellow needs two strong channels
    // but a genuinely weak blue channel. Green must dominate both neighbours.
    // Keep the existing red/blue predicates unchanged.
    wire is_yellow = sample && r >= 9'd80 && g >= 9'd80 &&
                     r > b + (b >> 1) + 9'd16 &&
                     g > b + (b >> 1) + 9'd16 &&
                     r <= g + (g >> 2) + 9'd16 && g <= r + 9'd24;
    wire is_green = sample && g >= 9'd64 &&
                    g > r + 9'd24 && g > b + 9'd16 &&
                    g > r + (r >> 2) && g > b + (b >> 2);
    // Export the exact predicates used for colour selection. Shape analysis
    // must not use the brightness-adjusted display path or duplicate thresholds.
    assign O_shape_mask = {is_green,is_yellow,is_blue,is_red};
    // V3 coherent-region selection for red. Blue keeps its established
    // selector; yellow and green use the V2 full-frame bounds below.
    color_band_selector #(.RUN_MIN(RUN_MIN)) red_region (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_frame_start(frame_start),
        .I_line_end(line_end), .I_sample(sample), .I_match(is_red),
        .I_y(y), .I_run_len(red_run_len), .I_run_x0(red_run_x0),
        .I_run_x1(red_run_x1), .O_count(red_selected_count),
        .O_x0(red_selected_x0), .O_y0(red_selected_y0),
        .O_x1(red_selected_x1), .O_y1(red_selected_y1)
    );
    wire blue_tail_wins = blue_run_len >= RUN_MIN &&
                          blue_run_len > blue_row_len;
    wire [9:0] blue_line_len = blue_tail_wins ? blue_run_len : blue_row_len;
    wire [10:0] blue_line_x0 = blue_tail_wins ? blue_run_x0 : blue_row_x0;
    wire [10:0] blue_line_x1 = blue_tail_wins ? blue_run_x1 : blue_row_x1;
    wire blue_join = blue_band_active &&
                     y - blue_band_last_y <= 11'd8 &&
                     {1'b0,blue_line_x0} <= {1'b0,blue_band_x1} + 12'd8 &&
                     {1'b0,blue_band_x0} <= {1'b0,blue_line_x1} + 12'd8;
    wire blue_band_wins = blue_band_count >= blue_best_count;
    wire [19:0] blue_selected_count = blue_band_wins ? blue_band_count : blue_best_count;
    wire [10:0] blue_selected_x0 = blue_band_wins ? blue_band_x0 : blue_best_x0;
    wire [10:0] blue_selected_y0 = blue_band_wins ? blue_band_y0 : blue_best_y0;
    wire [10:0] blue_selected_x1 = blue_band_wins ? blue_band_x1 : blue_best_x1;
    wire [10:0] blue_selected_y1 = blue_band_wins ? blue_band_y1 : blue_best_y1;
    wire red_good = red_selected_count >= MIN_PIXELS &&
                    (red_selected_x1 - red_selected_x0) >= MIN_SPAN &&
                    (red_selected_y1 - red_selected_y0) >= MIN_SPAN;
    wire blue_good = blue_selected_count >= MIN_PIXELS &&
                     (blue_selected_x1 - blue_selected_x0) >= MIN_SPAN &&
                     (blue_selected_y1 - blue_selected_y0) >= MIN_SPAN;
    wire yellow_good = yellow_count >= MIN_PIXELS &&
                       (yellow_x1 - yellow_x0) >= MIN_SPAN &&
                       (yellow_y1 - yellow_y0) >= MIN_SPAN;
    wire green_good = green_count >= MIN_PIXELS &&
                      (green_x1 - green_x0) >= MIN_SPAN &&
                      (green_y1 - green_y0) >= MIN_SPAN;
    // A single box is retained. Largest qualified sampled area wins;
    // red, blue, yellow, green is the deterministic tie order.
    wire red_wins = red_good &&
                    (!blue_good || red_selected_count >= blue_selected_count) &&
                    (!yellow_good || red_selected_count >= yellow_count) &&
                    (!green_good || red_selected_count >= green_count);
    wire blue_wins = blue_good &&
                     (!yellow_good || blue_selected_count >= yellow_count) &&
                     (!green_good || blue_selected_count >= green_count);
    wire yellow_wins = yellow_good &&
                       (!green_good || yellow_count >= green_count);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            red_count <= 0; blue_count <= 0;
            yellow_count <= 0; green_count <= 0;
            red_x0 <= WIDTH-1; red_y0 <= HEIGHT-1;
            red_x1 <= 0; red_y1 <= 0;
            blue_x0 <= WIDTH-1; blue_y0 <= HEIGHT-1;
            blue_x1 <= 0; blue_y1 <= 0;
            yellow_x0 <= WIDTH-1; yellow_y0 <= HEIGHT-1;
            yellow_x1 <= 0; yellow_y1 <= 0;
            green_x0 <= WIDTH-1; green_y0 <= HEIGHT-1;
            green_x1 <= 0; green_y1 <= 0;
            red_run_len <= 0; blue_run_len <= 0;
            blue_row_len <= 0; blue_row_x0 <= 0; blue_row_x1 <= 0;
            blue_band_active <= 0;
            blue_band_count <= 0; blue_best_count <= 0;
            blue_band_x0 <= 0; blue_band_y0 <= 0;
            blue_band_x1 <= 0; blue_band_y1 <= 0;
            blue_best_x0 <= 0; blue_best_y0 <= 0;
            blue_best_x1 <= 0; blue_best_y1 <= 0;
            blue_band_last_y <= 0;
            yellow_run_len <= 0; green_run_len <= 0;
            red_run_x0 <= 0; red_run_x1 <= 0;
            blue_run_x0 <= 0; blue_run_x1 <= 0;
            yellow_run_x0 <= 0; yellow_run_x1 <= 0;
            green_run_x0 <= 0; green_run_x1 <= 0;
            O_valid <= 0; O_color <= 0;
            O_red_pixels <= 0; O_blue_pixels <= 0;
            O_x0 <= 0; O_y0 <= 0; O_x1 <= 0; O_y1 <= 0;
        end else begin
            de_d <= I_de;
            vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin
                x <= 0; y <= 0;
                // Exact 2x2-subsampled qualified counts for the last frame.
                // Export independently of the winner so mask failures can be diagnosed.
                O_red_pixels <= red_selected_count;
                O_blue_pixels <= blue_selected_count;
                if (red_wins) begin
                    O_valid <= 1; O_color <= 1;
                    O_x0 <= red_selected_x0; O_y0 <= red_selected_y0;
                    O_x1 <= red_selected_x1; O_y1 <= red_selected_y1;
                end else if (blue_wins) begin
                    O_valid <= 1; O_color <= 2;
                    O_x0 <= blue_selected_x0; O_y0 <= blue_selected_y0;
                    O_x1 <= blue_selected_x1; O_y1 <= blue_selected_y1;
                end else if (yellow_wins) begin
                    O_valid <= 1; O_color <= 3;
                    O_x0 <= yellow_x0; O_y0 <= yellow_y0;
                    O_x1 <= yellow_x1; O_y1 <= yellow_y1;
                end else if (green_good) begin
                    O_valid <= 1; O_color <= 4;
                    O_x0 <= green_x0; O_y0 <= green_y0;
                    O_x1 <= green_x1; O_y1 <= green_y1;
                end else begin
                    O_valid <= 0; O_color <= 0;
                end
                red_count <= 0; blue_count <= 0;
                yellow_count <= 0; green_count <= 0;
                red_x0 <= WIDTH-1; red_y0 <= HEIGHT-1;
                red_x1 <= 0; red_y1 <= 0;
                blue_x0 <= WIDTH-1; blue_y0 <= HEIGHT-1;
                blue_x1 <= 0; blue_y1 <= 0;
                yellow_x0 <= WIDTH-1; yellow_y0 <= HEIGHT-1;
                yellow_x1 <= 0; yellow_y1 <= 0;
                green_x0 <= WIDTH-1; green_y0 <= HEIGHT-1;
                green_x1 <= 0; green_y1 <= 0;
                red_run_len <= 0; blue_run_len <= 0;
                blue_row_len <= 0;
                blue_band_active <= 0;
                blue_band_count <= 0; blue_best_count <= 0;
                yellow_run_len <= 0; green_run_len <= 0;
            end else begin
                if (de_d && !I_de) begin x <= 0; y <= y + 1'b1; end
                else if (I_de) x <= x + 1'b1;
                // Test only every second pixel. A qualifying horizontal run
                // rejects isolated colour noise before it reaches the box.
                if (sample) begin
                    if (is_red) begin
                        if (red_run_len == 0) red_run_x0 <= x;
                        red_run_x1 <= x;
                        if (red_run_len != 10'h3ff) red_run_len <= red_run_len + 1'b1;
                    end else if (red_run_len != 0) begin
                        if (red_run_len >= RUN_MIN) begin
                            red_count <= red_count + red_run_len;
                            if (red_run_x0 < red_x0) red_x0 <= red_run_x0;
                            if (red_run_x1 > red_x1) red_x1 <= red_run_x1;
                            if (y < red_y0) red_y0 <= y;
                            if (y > red_y1) red_y1 <= y;
                        end
                        red_run_len <= 0;
                    end
                    if (is_blue) begin
                        if (blue_run_len == 0) blue_run_x0 <= x;
                        blue_run_x1 <= x;
                        if (blue_run_len != 10'h3ff) blue_run_len <= blue_run_len + 1'b1;
                    end else if (blue_run_len != 0) begin
                        if (blue_run_len >= RUN_MIN) begin
                            blue_count <= blue_count + blue_run_len;
                            if (blue_run_len > blue_row_len) begin
                                blue_row_len <= blue_run_len;
                                blue_row_x0 <= blue_run_x0;
                                blue_row_x1 <= blue_run_x1;
                            end
                            if (blue_run_x0 < blue_x0) blue_x0 <= blue_run_x0;
                            if (blue_run_x1 > blue_x1) blue_x1 <= blue_run_x1;
                            if (y < blue_y0) blue_y0 <= y;
                            if (y > blue_y1) blue_y1 <= y;
                        end
                        blue_run_len <= 0;
                    end
                    if (is_yellow) begin
                        if (yellow_run_len == 0) yellow_run_x0 <= x;
                        yellow_run_x1 <= x;
                        if (yellow_run_len != 10'h3ff)
                            yellow_run_len <= yellow_run_len + 1'b1;
                    end else if (yellow_run_len != 0) begin
                        if (yellow_run_len >= RUN_MIN) begin
                            yellow_count <= yellow_count + yellow_run_len;
                            if (yellow_run_x0 < yellow_x0) yellow_x0 <= yellow_run_x0;
                            if (yellow_run_x1 > yellow_x1) yellow_x1 <= yellow_run_x1;
                            if (y < yellow_y0) yellow_y0 <= y;
                            if (y > yellow_y1) yellow_y1 <= y;
                        end
                        yellow_run_len <= 0;
                    end
                    if (is_green) begin
                        if (green_run_len == 0) green_run_x0 <= x;
                        green_run_x1 <= x;
                        if (green_run_len != 10'h3ff)
                            green_run_len <= green_run_len + 1'b1;
                    end else if (green_run_len != 0) begin
                        if (green_run_len >= RUN_MIN) begin
                            green_count <= green_count + green_run_len;
                            if (green_run_x0 < green_x0) green_x0 <= green_run_x0;
                            if (green_run_x1 > green_x1) green_x1 <= green_run_x1;
                            if (y < green_y0) green_y0 <= y;
                            if (y > green_y1) green_y1 <= y;
                        end
                        green_run_len <= 0;
                    end
                end else if (de_d && !I_de) begin
                    // Commit the last run at the end of each sampled line.
                    if (red_run_len >= RUN_MIN) begin
                        red_count <= red_count + red_run_len;
                        if (red_run_x0 < red_x0) red_x0 <= red_run_x0;
                        if (red_run_x1 > red_x1) red_x1 <= red_run_x1;
                        if (y < red_y0) red_y0 <= y;
                        if (y > red_y1) red_y1 <= y;
                    end
                    if (blue_run_len >= RUN_MIN) begin
                        blue_count <= blue_count + blue_run_len;
                        if (blue_run_x0 < blue_x0) blue_x0 <= blue_run_x0;
                        if (blue_run_x1 > blue_x1) blue_x1 <= blue_run_x1;
                        if (y < blue_y0) blue_y0 <= y;
                        if (y > blue_y1) blue_y1 <= y;
                    end
                    if (!y[0] && blue_line_len >= 10'd6) begin
                        if (blue_join) begin
                            blue_band_count <= blue_band_count + blue_line_len;
                            if (blue_line_x0 < blue_band_x0)
                                blue_band_x0 <= blue_line_x0;
                            if (blue_line_x1 > blue_band_x1)
                                blue_band_x1 <= blue_line_x1;
                            blue_band_y1 <= y;
                            blue_band_last_y <= y;
                        end else begin
                            if (blue_band_active && blue_band_count > blue_best_count) begin
                                blue_best_count <= blue_band_count;
                                blue_best_x0 <= blue_band_x0;
                                blue_best_y0 <= blue_band_y0;
                                blue_best_x1 <= blue_band_x1;
                                blue_best_y1 <= blue_band_y1;
                            end
                            blue_band_active <= 1'b1;
                            blue_band_count <= blue_line_len;
                            blue_band_x0 <= blue_line_x0;
                            blue_band_x1 <= blue_line_x1;
                            blue_band_y0 <= y;
                            blue_band_y1 <= y;
                            blue_band_last_y <= y;
                        end
                    end
                    blue_row_len <= 0;
                    if (yellow_run_len >= RUN_MIN) begin
                        yellow_count <= yellow_count + yellow_run_len;
                        if (yellow_run_x0 < yellow_x0) yellow_x0 <= yellow_run_x0;
                        if (yellow_run_x1 > yellow_x1) yellow_x1 <= yellow_run_x1;
                        if (y < yellow_y0) yellow_y0 <= y;
                        if (y > yellow_y1) yellow_y1 <= y;
                    end
                    if (green_run_len >= RUN_MIN) begin
                        green_count <= green_count + green_run_len;
                        if (green_run_x0 < green_x0) green_x0 <= green_run_x0;
                        if (green_run_x1 > green_x1) green_x1 <= green_run_x1;
                        if (y < green_y0) green_y0 <= y;
                        if (y > green_y1) green_y1 <= y;
                    end
                    red_run_len <= 0; blue_run_len <= 0;
                    yellow_run_len <= 0; green_run_len <= 0;
                end
            end
        end
    end
endmodule

// One streaming region selector for a single colour. The caller owns the RGB
// predicate and run counter. A short line (triangle tip) is accepted if it
// already passes the caller's original RUN_MIN threshold.
module color_band_selector #(
    parameter integer RUN_MIN = 3
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_frame_start,
    input wire I_line_end,
    input wire I_sample,
    input wire I_match,
    input wire [10:0] I_y,
    input wire [9:0] I_run_len,
    input wire [10:0] I_run_x0,
    input wire [10:0] I_run_x1,
    output wire [19:0] O_count,
    output wire [10:0] O_x0, O_y0, O_x1, O_y1
);
    reg [9:0] row_len;
    reg [10:0] row_x0, row_x1;
    reg band_active;
    reg [19:0] band_count, best_count;
    reg [10:0] band_x0, band_y0, band_x1, band_y1, band_last_y;
    reg [10:0] best_x0, best_y0, best_x1, best_y1;
    wire tail_wins = I_run_len >= RUN_MIN && I_run_len > row_len;
    wire [9:0] line_len = tail_wins ? I_run_len : row_len;
    wire [10:0] line_x0 = tail_wins ? I_run_x0 : row_x0;
    wire [10:0] line_x1 = tail_wins ? I_run_x1 : row_x1;
    wire join_band = band_active &&
                     I_y - band_last_y <= 11'd8 &&
                     {1'b0,line_x0} <= {1'b0,band_x1} + 12'd8 &&
                     {1'b0,band_x0} <= {1'b0,line_x1} + 12'd8;
    wire band_wins = band_count >= best_count;
    assign O_count = band_wins ? band_count : best_count;
    assign O_x0 = band_wins ? band_x0 : best_x0;
    assign O_y0 = band_wins ? band_y0 : best_y0;
    assign O_x1 = band_wins ? band_x1 : best_x1;
    assign O_y1 = band_wins ? band_y1 : best_y1;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            row_len <= 0; row_x0 <= 0; row_x1 <= 0;
            band_active <= 0; band_count <= 0; best_count <= 0;
            band_x0 <= 0; band_y0 <= 0; band_x1 <= 0; band_y1 <= 0;
            band_last_y <= 0;
            best_x0 <= 0; best_y0 <= 0; best_x1 <= 0; best_y1 <= 0;
        end else if (I_frame_start) begin
            row_len <= 0;
            band_active <= 0; band_count <= 0; best_count <= 0;
        end else begin
            if (I_sample && !I_match && I_run_len >= RUN_MIN &&
                I_run_len > row_len) begin
                row_len <= I_run_len;
                row_x0 <= I_run_x0;
                row_x1 <= I_run_x1;
            end
            if (I_line_end) begin
                if (!I_y[0] && line_len >= RUN_MIN) begin
                    if (join_band) begin
                        band_count <= band_count + line_len;
                        if (line_x0 < band_x0) band_x0 <= line_x0;
                        if (line_x1 > band_x1) band_x1 <= line_x1;
                        band_y1 <= I_y;
                        band_last_y <= I_y;
                    end else begin
                        if (band_active && band_count > best_count) begin
                            best_count <= band_count;
                            best_x0 <= band_x0; best_y0 <= band_y0;
                            best_x1 <= band_x1; best_y1 <= band_y1;
                        end
                        band_active <= 1'b1;
                        band_count <= line_len;
                        band_x0 <= line_x0; band_x1 <= line_x1;
                        band_y0 <= I_y; band_y1 <= I_y;
                        band_last_y <= I_y;
                    end
                end
                row_len <= 0;
            end
        end
    end
endmodule
