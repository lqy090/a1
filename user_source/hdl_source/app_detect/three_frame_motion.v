// Three distinct captured frames, reduced to 16x16 luminance tiles.
// The HDMI refresh clock alone is not a frame identity: the DDR readout can
// repeat one captured frame. I_frame_id is the captured slot sequence number.
module three_frame_motion #(
    parameter integer WIDTH = 1280,
    parameter integer HEIGHT = 720,
    parameter integer GRID_W = WIDTH/16,
    parameter integer GRID_H = HEIGHT/16,
    parameter integer DIFF_THRESHOLD = 7,
    parameter integer MIN_AREA_TILES = 3,
    parameter integer MAX_LABELS = 128,
    parameter integer MAX_BOXES = 16,
    parameter integer GLOBAL_CHANGE_LIMIT = 900
) (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable,
    input wire [2:0] I_brightness_level,
    input wire [7:0] I_frame_id,
    input wire I_frame_id_valid,
    output reg [4:0] O_box_count,
    output reg [MAX_BOXES*26-1:0] O_boxes,
    output reg O_overflow
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    reg [7:0] last_frame_id;
    reg have_frame_id, active_new;
    reg [1:0] history_count;
    reg [2:0] last_brightness;
    reg enable_d;
    reg [15:0] column_sum [0:GRID_W-1];
    reg [15:0] tile_sum;
    reg [7:0] older [0:GRID_W*GRID_H-1];
    reg [7:0] recent [0:GRID_W*GRID_H-1];
    wire [9:0] weighted_luma = {2'b0,I_rgb[23:16]} +
                                {1'b0,I_rgb[15:8],1'b0} +
                                {2'b0,I_rgb[7:0]};
    wire [7:0] luma = weighted_luma[9:2];
    wire [6:0] tx = x[10:4];
    wire [5:0] ty = y[9:4];
    wire [11:0] addr = (GRID_W == 80) ?
                       (({6'd0,ty} << 6) + ({6'd0,ty} << 4) + tx) :
                       (ty * GRID_W + tx);
    wire [15:0] completed_sum = tile_sum + {8'd0,luma};
    wire [7:0] tile_luma = completed_sum[15:8];
    reg [7:0] recent_q, older_q;
    wire [7:0] d_now = tile_luma >= recent_q ?
                       tile_luma - recent_q : recent_q - tile_luma;
    wire [7:0] d_old = recent_q >= older_q ?
                       recent_q - older_q : older_q - recent_q;
    wire in_roi = (tx >= 7'd2) && (tx < GRID_W-2) &&
                  (ty >= 6'd2) && (ty < GRID_H-2);
    wire support = active_new && history_count == 2'd3 && in_roi &&
                   ((d_now > DIFF_THRESHOLD) || (d_old > DIFF_THRESHOLD));
    wire seed = support && (d_now > DIFF_THRESHOLD) &&
                (d_old > DIFF_THRESHOLD);

    // One row of labels in each bank. Eight-connected neighbours join the
    // motion support region; only regions containing a three-frame seed pass.
    reg [7:0] row_a [0:GRID_W-1];
    reg [7:0] row_b [0:GRID_W-1];
    reg [7:0] left_label;
    wire [7:0] up = (ty == 0) ? 8'd0 :
                    (ty[0] ? row_a[tx] : row_b[tx]);
    wire [7:0] up_left = (ty == 0 || tx == 0) ? 8'd0 :
                         (ty[0] ? row_a[tx-1'b1] : row_b[tx-1'b1]);
    wire [7:0] up_right = (ty == 0 || tx == GRID_W-1) ? 8'd0 :
                          (ty[0] ? row_a[tx+1'b1] : row_b[tx+1'b1]);
    wire [7:0] left = (tx == 0) ? 8'd0 : left_label;
    function [7:0] nonzero_min;
        input [7:0] a, b;
        begin
            if (a == 0) nonzero_min = b;
            else if (b == 0) nonzero_min = a;
            else nonzero_min = a < b ? a : b;
        end
    endfunction
    wire [7:0] neighbour = nonzero_min(nonzero_min(left,up),
                                       nonzero_min(up_left,up_right));
    reg [7:0] left_q, up_q, up_left_q, up_right_q, neighbour_q;
    reg [7:0] left_parent_q, up_parent_q, up_left_parent_q, up_right_parent_q;
    reg [6:0] min_x_q, max_x_q;
    reg [5:0] min_y_q, max_y_q;
    reg [1:0] area_q;
    reg [7:0] label_count;
    reg [7:0] parent [0:MAX_LABELS-1];
    reg [6:0] min_x [0:MAX_LABELS-1], max_x [0:MAX_LABELS-1];
    reg [5:0] min_y [0:MAX_LABELS-1], max_y [0:MAX_LABELS-1];
    // Only the >=3 threshold and presence of an AND seed are needed.
    // Saturation preserves that decision through union operations.
    reg [1:0] area [0:MAX_LABELS-1];
    reg has_seed [0:MAX_LABELS-1];
    reg [11:0] changed_tiles;
    reg label_overflow;

    localparam ST_IDLE=2'd0, ST_MERGE=2'd1, ST_SELECT=2'd2;
    reg [1:0] state;
    reg [7:0] merge_i, select_i, final_label_count;
    reg final_bad;
    wire [7:0] merge_parent = parent[merge_i];

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            last_frame_id <= 0; have_frame_id <= 0; active_new <= 0;
            history_count <= 0; last_brightness <= 0; enable_d <= 0;
            tile_sum <= 0; left_label <= 0;
            label_count <= 8'd1; changed_tiles <= 0;
            label_overflow <= 0; final_bad <= 0;
            state <= ST_IDLE; merge_i <= 0; select_i <= 0;
            final_label_count <= 0;
            O_box_count <= 0; O_boxes <= 0; O_overflow <= 0;
        end else begin
            de_d <= I_de;
            vs_d <= I_vsync;
            enable_d <= I_enable;
            // Three pixel clocks before the tile completes. Synchronous
            // read allows the two history arrays to map to on-chip RAM.
            if (I_de && y < HEIGHT && y[3:0] == 4'd15 &&
                x < WIDTH && x[3:0] == 4'd12) begin
                recent_q <= recent[addr];
                older_q <= older[addr];
                left_q <= left; up_q <= up;
                up_left_q <= up_left; up_right_q <= up_right;
                neighbour_q <= neighbour;
            end
            if (I_de && y < HEIGHT && y[3:0] == 4'd15 &&
                x < WIDTH && x[3:0] == 4'd13) begin
                min_x_q <= min_x[neighbour_q];
                max_x_q <= max_x[neighbour_q];
                min_y_q <= min_y[neighbour_q];
                max_y_q <= max_y[neighbour_q];
                area_q <= area[neighbour_q];
                left_parent_q <= parent[left_q];
                up_parent_q <= parent[up_q];
                up_left_parent_q <= parent[up_left_q];
                up_right_parent_q <= parent[up_right_q];
            end
            if (!I_enable) begin
                history_count <= 0;
                have_frame_id <= 0;
                active_new <= 0;
                label_count <= 8'd1;
                changed_tiles <= 0;
                label_overflow <= 0;
                state <= ST_IDLE;
                O_box_count <= 0;
                O_overflow <= 0;
            end else begin
                if (!enable_d) begin
                    history_count <= 0;
                    have_frame_id <= 0;
                    active_new <= 0;
                    O_box_count <= 0;
                end
                if (I_vsync && !vs_d) begin
                    x <= 0; y <= 0;
                    active_new <= 0;
                    final_label_count <= label_count;
                    final_bad <= label_overflow ||
                                 (changed_tiles > GLOBAL_CHANGE_LIMIT);
                    if (active_new && history_count == 2'd3 &&
                        label_count > 8'd1) begin
                        merge_i <= label_count - 8'd1;
                        state <= ST_MERGE;
                    end else if (active_new) begin
                        O_box_count <= 0;
                        O_overflow <= 0;
                    end
                    label_count <= 8'd1;
                    changed_tiles <= 0;
                    label_overflow <= 0;
                    left_label <= 0;
                end else if (de_d && !I_de) begin
                    x <= 0; y <= y + 11'd1;
                end else if (I_de) begin
                    x <= x + 11'd1;
                end

                // The DDR metadata crosses into this clock domain just after
                // the first active pixel. Pixel 12 leaves enough CDC settling
                // time before the first tile completes at pixel 15.
                if (I_de && x == 11'd12 && y == 0) begin
                    active_new <= I_frame_id_valid &&
                                  (!have_frame_id || I_frame_id != last_frame_id);
                    if (!I_frame_id_valid) begin
                        O_box_count <= 0;
                        history_count <= 0;
                        have_frame_id <= 0;
                    end
                    if (I_frame_id_valid &&
                        (!have_frame_id || I_frame_id != last_frame_id)) begin
                        have_frame_id <= 1;
                        last_frame_id <= I_frame_id;
                        if (I_brightness_level != last_brightness) begin
                            history_count <= 2'd1;
                            O_box_count <= 0;
                        end else if (history_count != 2'd3)
                            history_count <= history_count + 2'd1;
                    end
                    last_brightness <= I_brightness_level;
                end

                if (I_de && x < WIDTH && y < HEIGHT) begin
                    if (x[3:0] == 4'd0)
                        tile_sum <= (y[3:0] == 4'd0 ? 16'd0 : column_sum[tx]) + luma;
                    else if (x[3:0] != 4'd15)
                        tile_sum <= tile_sum + luma;
                    else begin
                        if (y[3:0] != 4'd15)
                            column_sum[tx] <= completed_sum;
                        else if (active_new) begin
                            older[addr] <= recent_q;
                            recent[addr] <= tile_luma;
                            if (support) changed_tiles <= changed_tiles + 12'd1;
                            if (support) begin
                                if (neighbour_q == 0) begin
                                    if (label_count < MAX_LABELS) begin
                                        if (ty[0]) row_b[tx] <= label_count;
                                        else row_a[tx] <= label_count;
                                        left_label <= label_count;
                                        parent[label_count] <= label_count;
                                        min_x[label_count] <= tx; max_x[label_count] <= tx;
                                        min_y[label_count] <= ty; max_y[label_count] <= ty;
                                        area[label_count] <= 2'd1;
                                        has_seed[label_count] <= seed;
                                        label_count <= label_count + 8'd1;
                                    end else begin
                                        if (ty[0]) row_b[tx] <= 0;
                                        else row_a[tx] <= 0;
                                        left_label <= 0;
                                        label_overflow <= 1;
                                    end
                                end else begin
                                    if (ty[0]) row_b[tx] <= neighbour_q;
                                    else row_a[tx] <= neighbour_q;
                                    left_label <= neighbour_q;
                                    if (tx < min_x_q) min_x[neighbour_q] <= tx;
                                    if (tx > max_x_q) max_x[neighbour_q] <= tx;
                                    if (ty < min_y_q) min_y[neighbour_q] <= ty;
                                    if (ty > max_y_q) max_y[neighbour_q] <= ty;
                                    if (area_q < 2'd3)
                                        area[neighbour_q] <= area_q + 2'd1;
                                    if (seed) has_seed[neighbour_q] <= 1;
                                    if (left_q != 0 && left_q != neighbour_q && left_parent_q > neighbour_q)
                                        parent[left_q] <= neighbour_q;
                                    if (up_q != 0 && up_q != neighbour_q && up_parent_q > neighbour_q)
                                        parent[up_q] <= neighbour_q;
                                    if (up_left_q != 0 && up_left_q != neighbour_q && up_left_parent_q > neighbour_q)
                                        parent[up_left_q] <= neighbour_q;
                                    if (up_right_q != 0 && up_right_q != neighbour_q && up_right_parent_q > neighbour_q)
                                        parent[up_right_q] <= neighbour_q;
                                end
                            end else begin
                                if (ty[0]) row_b[tx] <= 0;
                                else row_a[tx] <= 0;
                                left_label <= 0;
                            end
                        end
                    end
                end

                // Parent links always point to smaller label numbers. Folding
                // high to low therefore resolves transitive unions in 127 clocks.
                if (state == ST_MERGE) begin
                    if (merge_parent != merge_i) begin
                        if (min_x[merge_i] < min_x[merge_parent])
                            min_x[merge_parent] <= min_x[merge_i];
                        if (max_x[merge_i] > max_x[merge_parent])
                            max_x[merge_parent] <= max_x[merge_i];
                        if (min_y[merge_i] < min_y[merge_parent])
                            min_y[merge_parent] <= min_y[merge_i];
                        if (max_y[merge_i] > max_y[merge_parent])
                            max_y[merge_parent] <= max_y[merge_i];
                        area[merge_parent] <=
                            ({1'b0,area[merge_parent]} + {1'b0,area[merge_i]} >= 3) ?
                            2'd3 : area[merge_parent] + area[merge_i];
                        has_seed[merge_parent] <=
                            has_seed[merge_parent] | has_seed[merge_i];
                    end
                    if (merge_i == 8'd1) begin
                        select_i <= 8'd1;
                        O_box_count <= 0;
                        O_overflow <= final_bad;
                        state <= ST_SELECT;
                    end else merge_i <= merge_i - 8'd1;
                end else if (state == ST_SELECT) begin
                    if (!final_bad && !O_overflow && parent[select_i] == select_i &&
                        area[select_i] >= MIN_AREA_TILES && has_seed[select_i]) begin
                        if (O_box_count < MAX_BOXES) begin
                            O_boxes[O_box_count*26 +: 26] <=
                                {max_y[select_i],max_x[select_i],
                                 min_y[select_i],min_x[select_i]};
                            O_box_count <= O_box_count + 5'd1;
                        end else begin
                            O_box_count <= 0;
                            O_overflow <= 1;
                        end
                    end
                    if (select_i == final_label_count - 8'd1)
                        state <= ST_IDLE;
                    else select_i <= select_i + 8'd1;
                end
            end
        end
    end
endmodule
