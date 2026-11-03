// Single-object conveyor tally. The fixed screen-space gate must be calibrated
// to marks on the stationary conveyor frame after the camera is mounted.
// One completed left-to-right passage increments exactly one colour/shape bin.
module conveyor_cross_count #(
    parameter integer DEBOUNCE_CYCLES = 1485000,
    parameter integer DOUBLE_CLICK_FRAMES = 18,
    parameter [10:0] LINE_X = 11'd800,
    parameter [10:0] HYST = 11'd32,
    parameter [10:0] BELT_Y0 = 11'd140,
    parameter [10:0] BELT_Y1 = 11'd620,
    parameter [10:0] MAX_STEP = 11'd128
) (
    input wire I_clk, I_rst_n, I_key_n, I_vsync,
    input wire I_detect_enable,
    input wire I_target_valid,
    input wire [2:0] I_color,
    input wire [10:0] I_x0, I_y0, I_x1, I_y1,
    input wire I_shape_valid,
    input wire [2:0] I_shape_color, I_shape,
    output reg O_enable,
    output wire [127:0] O_counts
);
    reg key_meta, key_sync, key_stable, requested, vs_d;
    reg [20:0] debounce_count;
    reg click_pending, clear_requested;
    reg [5:0] click_frames;
    reg [1:0] phase;
    reg [2:0] lost_frames, object_color, object_shape;
    reg prev_valid, shape_prev_valid;
    reg [2:0] shape_prev, shape_prev_color;
    reg [10:0] prev_cx, prev_cy;
    reg [15:0] counts [0:7];
    genvar k;
    generate for (k=0; k<8; k=k+1) begin: expose_count
        assign O_counts[k*16 +: 16] = counts[k];
    end endgenerate

    wire frame_start = I_vsync && !vs_d;
    wire key_press = key_sync != key_stable &&
                     debounce_count == DEBOUNCE_CYCLES-1 && !key_sync;
    wire clear_now = clear_requested || (key_press && click_pending);
    wire [11:0] cx = ({1'b0,I_x0} + {1'b0,I_x1}) >> 1;
    wire [11:0] cy = ({1'b0,I_y0} + {1'b0,I_y1}) >> 1;
    wire [11:0] dx = cx >= {1'b0,prev_cx} ? cx - {1'b0,prev_cx} : {1'b0,prev_cx} - cx;
    wire [11:0] dy = cy >= {1'b0,prev_cy} ? cy - {1'b0,prev_cy} : {1'b0,prev_cy} - cy;
    wire target_here = I_target_valid && cx < 12'd1280 &&
                       cy >= {1'b0,BELT_Y0} && cy <= {1'b0,BELT_Y1};
    wire upstream = cx + {1'b0,HYST} < {1'b0,LINE_X};
    wire downstream = cx > {1'b0,LINE_X} + {1'b0,HYST};
    wire same_motion = prev_valid && dx <= {1'b0,MAX_STEP} &&
                       dy <= {1'b0,MAX_STEP} && I_color == object_color;
    wire [2:0] merged_shape = (I_shape == 3'd1 || I_shape == 3'd2) ?
                              3'd2 : I_shape;
    wire shape_now = target_here && I_shape_valid &&
                     I_shape_color == I_color &&
                     (I_shape == 3'd1 || I_shape == 3'd2 || I_shape == 3'd4);
    wire stable_shape = shape_now && shape_prev_valid &&
                        merged_shape == shape_prev && I_color == shape_prev_color;
    wire [2:0] crossing_shape = stable_shape ? merged_shape : object_shape;
    reg [3:0] bin_index;
    reg bin_valid;
    always @* begin
        bin_valid = 1'b1;
        bin_index = 4'd0;
        case (I_color)
            3'd1: bin_index = 4'd0;
            3'd2: bin_index = 4'd2;
            3'd3: bin_index = 4'd4;
            3'd4: bin_index = 4'd6;
            default: bin_valid = 1'b0;
        endcase
        case (crossing_shape)
            3'd2: bin_index = bin_index + 4'd0; // RECTANGLE, square included
            3'd4: bin_index = bin_index + 4'd1; // TRIANGLE
            default: bin_valid = 1'b0;
        endcase
    end
    function [15:0] bcd_plus_one;
        input [15:0] bcd;
        begin
            bcd_plus_one = bcd;
            if (bcd != 16'h0999) begin
                if (bcd[3:0] != 4'd9) bcd_plus_one[3:0] = bcd[3:0] + 1'b1;
                else begin
                    bcd_plus_one[3:0] = 0;
                    if (bcd[7:4] != 4'd9) bcd_plus_one[7:4] = bcd[7:4] + 1'b1;
                    else begin
                        bcd_plus_one[7:4] = 0;
                        if (bcd[11:8] != 4'd9) bcd_plus_one[11:8] = bcd[11:8] + 1'b1;
                        else begin
                            bcd_plus_one[11:8] = 0;
                            bcd_plus_one[15:12] = bcd[15:12] + 1'b1;
                        end
                    end
                end
            end
        end
    endfunction
    integer i;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            key_meta <= 1; key_sync <= 1; key_stable <= 1;
            requested <= 0; O_enable <= 0; debounce_count <= 0; vs_d <= 0;
            click_pending <= 0; clear_requested <= 0; click_frames <= 0;
            phase <= 0; lost_frames <= 0; object_color <= 0; object_shape <= 0;
            prev_valid <= 0; prev_cx <= 0; prev_cy <= 0;
            shape_prev_valid <= 0; shape_prev <= 0; shape_prev_color <= 0;
            for (i=0; i<8; i=i+1) counts[i] <= 0;
        end else begin
            key_meta <= I_key_n;
            key_sync <= key_meta;
            vs_d <= I_vsync;
            if (key_sync == key_stable) debounce_count <= 0;
            else if (debounce_count == DEBOUNCE_CYCLES-1) begin
                debounce_count <= 0;
                key_stable <= key_sync;
                if (!key_sync) begin
                    if (click_pending) begin
                        click_pending <= 0;
                        clear_requested <= 1;
                        click_frames <= 0;
                    end else begin
                        click_pending <= 1;
                        click_frames <= 0;
                    end
                end
            end else debounce_count <= debounce_count + 1'b1;
            // Defer a single click until the double-click window expires.
            // The second debounced press cancels it and requests a clear.
            if (frame_start && click_pending && !key_press) begin
                if (click_frames == DOUBLE_CLICK_FRAMES-1) begin
                    requested <= ~requested;
                    click_pending <= 0;
                    click_frames <= 0;
                end else click_frames <= click_frames + 1'b1;
            end
            if (frame_start) begin
                O_enable <= requested;
                shape_prev_valid <= shape_now;
                shape_prev <= merged_shape;
                shape_prev_color <= I_color;
                if (clear_now) begin
                    clear_requested <= 0;
                    for (i=0; i<8; i=i+1) counts[i] <= 0;
                    phase <= 0;
                    lost_frames <= 0;
                    prev_valid <= 0;
                    object_color <= 0;
                    object_shape <= 0;
                    shape_prev_valid <= 0;
                    shape_prev <= 0;
                    shape_prev_color <= 0;
                end else if (!requested || !I_detect_enable || requested != O_enable) begin
                    phase <= 0;
                    lost_frames <= 0;
                    prev_valid <= 0;
                    object_shape <= 0;
                    shape_prev_valid <= 0;
                end else if (phase == 2'd0) begin
                    if (target_here && upstream && stable_shape) begin
                        phase <= 2'd1;
                        object_color <= I_color;
                        object_shape <= merged_shape;
                        prev_cx <= cx[10:0];
                        prev_cy <= cy[10:0];
                        prev_valid <= 1;
                        lost_frames <= 0;
                    end
                end else if (phase == 2'd1) begin
                    if (!target_here) begin
                        if (lost_frames == 3'd2) begin
                            phase <= 0;
                            prev_valid <= 0;
                            object_shape <= 0;
                        end else lost_frames <= lost_frames + 1'b1;
                    end else if (!same_motion) begin
                        // A new or implausibly displaced target cannot inherit
                        // the old object's upstream crossing history.
                        phase <= 0;
                        prev_valid <= 0;
                        object_shape <= 0;
                        lost_frames <= 0;
                    end else begin
                        prev_cx <= cx[10:0];
                        prev_cy <= cy[10:0];
                        lost_frames <= 0;
                        if (stable_shape) object_shape <= merged_shape;
                        if (downstream && bin_valid) begin
                            counts[bin_index] <= bcd_plus_one(counts[bin_index]);
                            phase <= 2'd2;
                        end
                    end
                end else begin
                    // Do not rearm while the same object is visible, even if it
                    // jitters back across the line. Require an empty gap.
                    if (!target_here) begin
                        if (lost_frames == 3'd2) begin
                            phase <= 0;
                            prev_valid <= 0;
                            object_shape <= 0;
                            lost_frames <= 0;
                        end else lost_frames <= lost_frames + 1'b1;
                    end else lost_frames <= 0;
                end
            end
        end
    end
endmodule
