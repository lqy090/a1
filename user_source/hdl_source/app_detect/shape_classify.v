// Streaming, single-target silhouette classifier. Uses the colour detector's
// exact 2x2-subsampled mask and the preceding frame's target box as an ROI.
// No display-mode or brightness pixels enter this block.
module shape_classify #(
    parameter integer WIDTH = 1280,
    parameter integer HEIGHT = 720,
    parameter integer ROI_MARGIN = 32,
    parameter integer MIN_SAMPLES = 160
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_vsync,
    input wire I_de,
    input wire [3:0] I_mask, // green,yellow,blue,red
    input wire I_target_valid,
    input wire [2:0] I_target_color,
    input wire [10:0] I_x0, I_y0, I_x1, I_y1,
    output reg O_valid,
    output reg [2:0] O_color,
    output reg [2:0] O_shape // 2=rectangle (including square),4=triangle; 0=unknown
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    wire frame_start = I_vsync && !vs_d;
    wire line_end = de_d && !I_de;

    reg roi_valid;
    reg [2:0] roi_color;
    reg [10:0] roi_x0, roi_y0, roi_x1, roi_y1;
    reg [10:0] roi_cx, roi_cy, roi_q1, roi_q3;
    reg [19:0] area, upper_area, lower_area, left_area, right_area;
    reg [10:0] min_x, min_y, max_x, max_y;
    reg [10:0] line_count, row_q1, row_mid, row_q3;

    wire [3:0] selected_mask = roi_color == 3'd1 ? {3'b0,I_mask[0]} :
                               roi_color == 3'd2 ? {3'b0,I_mask[1]} :
                               roi_color == 3'd3 ? {3'b0,I_mask[2]} :
                               roi_color == 3'd4 ? {3'b0,I_mask[3]} : 4'd0;
    wire hit = roi_valid && I_de && selected_mask[0] &&
               x >= roi_x0 && x <= roi_x1 &&
               y >= roi_y0 && y <= roi_y1;
    wire [10:0] next_roi_x0 = I_x0 > ROI_MARGIN ? I_x0 - ROI_MARGIN : 0;
    wire [10:0] next_roi_y0 = I_y0 > ROI_MARGIN ? I_y0 - ROI_MARGIN : 0;
    wire [10:0] next_roi_x1 = I_x1 + ROI_MARGIN < WIDTH ?
                              I_x1 + ROI_MARGIN : WIDTH-1;
    wire [10:0] next_roi_y1 = I_y1 + ROI_MARGIN < HEIGHT ?
                              I_y1 + ROI_MARGIN : HEIGHT-1;
    wire [10:0] target_h = I_y1 - I_y0;
    wire [10:0] target_cx = ({1'b0,I_x0} + {1'b0,I_x1}) >> 1;
    wire [10:0] target_cy = ({1'b0,I_y0} + {1'b0,I_y1}) >> 1;
    wire [10:0] target_q1 = I_y0 + (target_h >> 2);
    wire [10:0] target_q3 = I_y0 + (target_h >> 1) + (target_h >> 2);
    wire near_q1 = y >= roi_q1 - (roi_q1 != 0) && y <= roi_q1 + 11'd1;
    wire near_mid = y >= roi_cy - (roi_cy != 0) && y <= roi_cy + 11'd1;
    wire near_q3 = y >= roi_q3 - (roi_q3 != 0) && y <= roi_q3 + 11'd1;

    // Snapshot at frame boundary, classify during blanking. The detector and
    // this block commit independently, so the shape is checked against colour
    // again by the OSD before it is displayed.
    reg pending;
    reg [2:0] snap_color;
    reg [19:0] snap_area, snap_upper, snap_lower, snap_left, snap_right;
    reg [10:0] snap_w, snap_h, snap_q1, snap_mid, snap_q3;
    wire [21:0] box_area = snap_w * snap_h;
    wire [21:0] filled_area = {snap_area,2'b00};
    wire dense = ({4'b0,filled_area} << 3) >= {4'b0,box_area} * 7;
    wire round_fill = ({4'b0,filled_area} << 4) >= {4'b0,box_area} * 11;
    wire min_fill = ({4'b0,filled_area} << 3) >= {4'b0,box_area} * 3;
    wire roughly_square = ({2'b0,snap_w} << 2) <= snap_h * 5 &&
                          ({2'b0,snap_h} << 2) <= snap_w * 5;
    wire [19:0] vertical_bias = snap_upper > snap_lower ?
                                snap_upper - snap_lower : snap_lower - snap_upper;
    wire [19:0] horizontal_bias = snap_left > snap_right ?
                                  snap_left - snap_right : snap_right - snap_left;
    wire tapered = {3'b0,vertical_bias} * 5 > {3'b0,snap_area} ||
                   {3'b0,horizontal_bias} * 5 > {3'b0,snap_area};
    wire rounded_rows = snap_mid != 0 && snap_q1 != 0 && snap_q3 != 0 &&
                        ({2'b0,snap_q1} << 2) >= {2'b0,snap_mid} * 3 &&
                        ({2'b0,snap_q3} << 2) >= {2'b0,snap_mid} * 3;
    // Preserve a round-silhouette veto: removing the CIRCLE label alone would
    // let some round targets fall through to another shape. Dense axis-aligned
    // squares remain eligible because their fill exceeds the round band.
    wire round_silhouette = !dense && roughly_square && round_fill &&
                            rounded_rows && !tapered;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            roi_valid <= 0; roi_color <= 0;
            roi_x0 <= 0; roi_y0 <= 0; roi_x1 <= 0; roi_y1 <= 0;
            roi_cx <= 0; roi_cy <= 0; roi_q1 <= 0; roi_q3 <= 0;
            area <= 0; upper_area <= 0; lower_area <= 0;
            left_area <= 0; right_area <= 0;
            min_x <= WIDTH-1; min_y <= HEIGHT-1; max_x <= 0; max_y <= 0;
            line_count <= 0; row_q1 <= 0; row_mid <= 0; row_q3 <= 0;
            pending <= 0; snap_color <= 0; snap_area <= 0;
            snap_upper <= 0; snap_lower <= 0;
            snap_left <= 0; snap_right <= 0;
            snap_w <= 0; snap_h <= 0;
            snap_q1 <= 0; snap_mid <= 0; snap_q3 <= 0;
            O_valid <= 0; O_color <= 0; O_shape <= 0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (frame_start) begin
                x <= 0; y <= 0;
                roi_valid <= I_target_valid && I_x1 >= I_x0 && I_y1 >= I_y0;
                roi_color <= I_target_color;
                roi_x0 <= next_roi_x0; roi_y0 <= next_roi_y0;
                roi_x1 <= next_roi_x1; roi_y1 <= next_roi_y1;
                roi_cx <= target_cx; roi_cy <= target_cy;
                roi_q1 <= target_q1; roi_q3 <= target_q3;
                snap_area <= area;
                snap_color <= roi_color;
                snap_upper <= upper_area; snap_lower <= lower_area;
                snap_left <= left_area; snap_right <= right_area;
                snap_w <= max_x >= min_x ? max_x - min_x + 11'd2 : 0;
                snap_h <= max_y >= min_y ? max_y - min_y + 11'd2 : 0;
                snap_q1 <= row_q1; snap_mid <= row_mid; snap_q3 <= row_q3;
                pending <= roi_valid;
                if (!roi_valid) begin
                    O_valid <= 0;
                    O_shape <= 0;
                end
                area <= 0; upper_area <= 0; lower_area <= 0;
                left_area <= 0; right_area <= 0;
                min_x <= WIDTH-1; min_y <= HEIGHT-1;
                max_x <= 0; max_y <= 0;
                line_count <= 0; row_q1 <= 0; row_mid <= 0; row_q3 <= 0;
            end else begin
                if (line_end) begin
                    x <= 0; y <= y + 1'b1;
                    if (!y[0] && near_q1) row_q1 <= line_count;
                    if (!y[0] && near_mid) row_mid <= line_count;
                    if (!y[0] && near_q3) row_q3 <= line_count;
                    line_count <= 0;
                end else if (I_de) x <= x + 1'b1;
                if (hit) begin
                    area <= area + 1'b1;
                    line_count <= line_count + 1'b1;
                    if (x < min_x) min_x <= x;
                    if (x > max_x) max_x <= x;
                    if (y < min_y) min_y <= y;
                    if (y > max_y) max_y <= y;
                    if (y < roi_cy) upper_area <= upper_area + 1'b1;
                    else lower_area <= lower_area + 1'b1;
                    if (x < roi_cx) left_area <= left_area + 1'b1;
                    else right_area <= right_area + 1'b1;
                end
                if (pending) begin
                    pending <= 0;
                    O_color <= snap_color;
                    O_shape <= 0;
                    O_valid <= 0;
                    if (snap_area >= MIN_SAMPLES && snap_w >= 11'd20 &&
                        snap_h >= 11'd20 && min_fill) begin
                        if (round_silhouette) begin
                            O_shape <= 0;
                            O_valid <= 0;
                        end else if (dense) begin
                            O_shape <= 3'd2;
                            O_valid <= 1;
                        end else if (!round_fill && tapered &&
                                     !(roughly_square && rounded_rows)) begin
                            O_shape <= 3'd4;
                            O_valid <= 1;
                        end
                    end
                end
            end
        end
    end
endmodule
