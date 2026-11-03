// Observes the four existing DDR frame slots without touching video pixels.
// The CSI timestamp is matched to the ISP frame before the slot is read out.
module frame_buffer_lag #(
    // DDR user clock is 66.667 MHz (15 ns in the TD timing report).
    parameter integer TICKS_PER_MS = 66667,
    parameter integer PAIR_WAIT_CYCLES = 16
) (
    input wire I_cam_clk, I_cam_rst_n, I_mipi_frame_start,
    input wire I_ddr_clk, I_ddr_rst_n,
    input wire I_camera_frame_start,
    input wire [1:0] I_write_slot,
    input wire I_display_frame_start,
    input wire [1:0] I_read_slot,
    input wire I_hdmi_de,
    input wire I_pixel_clk, I_pixel_rst_n,
    output reg [3:0] O_lag_frames,
    output reg [6:0] O_latency_ms,
    output reg O_valid,
    output reg [6:0] O_capture_latency_ms,
    output reg O_capture_valid,
    output reg [7:0] O_display_frame_id,
    output reg O_display_frame_id_valid
);
    // A toggle carries the one-cycle CSI start pulse to the DDR timebase.
    reg mipi_start_prev, mipi_toggle;
    always @(posedge I_cam_clk or negedge I_cam_rst_n) begin
        if (!I_cam_rst_n) begin
            mipi_start_prev <= 1'b0;
            mipi_toggle <= 1'b0;
        end else begin
            mipi_start_prev <= I_mipi_frame_start;
            if (I_mipi_frame_start && !mipi_start_prev)
                mipi_toggle <= ~mipi_toggle;
        end
    end
    reg mipi_meta, mipi_sync, mipi_seen;
    wire mipi_event = mipi_sync != mipi_seen;
    reg [16:0] tick_count;
    reg [15:0] time_ms;
    reg [7:0] mipi_seq, linked_mipi_seq;
    reg [15:0] mipi_time_ms;
    wire [7:0] unpaired_mipi = mipi_seq - linked_mipi_seq;
    wire [15:0] mipi_to_isp_ms = time_ms - mipi_time_ms;
    reg pending_pair;
    reg [1:0] pending_slot;
    reg [4:0] pending_wait;
    reg [7:0] frame_seq;
    reg [7:0] slot_seq [0:3];
    reg [15:0] slot_time_ms [0:3];
    reg [15:0] slot_capture_ms [0:3];
    reg [3:0] slot_valid;
    reg [3:0] slot_capture_valid;
    reg [2:0] display_frames_without_capture;
    reg [3:0] selected_lag, lag_ddr;
    reg [7:0] frame_id_ddr;
    reg frame_id_valid_ddr, frame_id_toggle;
    reg [15:0] selected_time_ms;
    reg [15:0] selected_capture_ms;
    reg selected_valid, await_first_pixel;
    reg selected_capture_valid;
    reg [6:0] latency_ddr;
    reg [6:0] capture_latency_ddr;
    wire [15:0] capture_elapsed_ms = time_ms - selected_capture_ms;
    reg valid_ddr, update_toggle;
    reg capture_valid_ddr;
    wire [7:0] age_now = frame_seq - slot_seq[I_read_slot];
    wire [15:0] elapsed_ms = time_ms - selected_time_ms;
    // The HDMI active-video edge is synchronized into the DDR timebase.
    reg de_meta, de_sync, de_prev;
    wire first_active_edge = de_sync && !de_prev;
    integer i;
    always @(posedge I_ddr_clk or negedge I_ddr_rst_n) begin
        if (!I_ddr_rst_n) begin
            tick_count <= 17'd0;
            time_ms <= 16'd0;
            mipi_meta <= 0; mipi_sync <= 0; mipi_seen <= 0;
            mipi_seq <= 0; linked_mipi_seq <= 0; mipi_time_ms <= 0;
            pending_pair <= 0; pending_slot <= 0; pending_wait <= 0;
            frame_seq <= 8'd0;
            slot_valid <= 4'd0;
            slot_capture_valid <= 4'd0;
            display_frames_without_capture <= 3'd0;
            for (i=0; i<4; i=i+1) begin
                slot_seq[i] <= 8'd0;
                slot_time_ms[i] <= 16'd0;
                slot_capture_ms[i] <= 16'd0;
            end
            selected_lag <= 4'd0;
            frame_id_ddr <= 8'd0;
            frame_id_valid_ddr <= 1'b0;
            frame_id_toggle <= 1'b0;
            selected_time_ms <= 16'd0;
            selected_capture_ms <= 16'd0;
            selected_valid <= 1'b0;
            selected_capture_valid <= 1'b0;
            await_first_pixel <= 1'b0;
            lag_ddr <= 4'd0;
            latency_ddr <= 7'd0;
            capture_latency_ddr <= 7'd0;
            valid_ddr <= 1'b0;
            capture_valid_ddr <= 1'b0;
            update_toggle <= 1'b0;
            de_meta <= 1'b0; de_sync <= 1'b0; de_prev <= 1'b0;
        end else begin
            mipi_meta <= mipi_toggle;
            mipi_sync <= mipi_meta;
            if (mipi_event) begin
                mipi_seen <= mipi_sync;
                mipi_seq <= mipi_seq + 8'd1;
                mipi_time_ms <= time_ms;
            end
            de_meta <= I_hdmi_de;
            de_sync <= de_meta;
            de_prev <= de_sync;
            if (tick_count == TICKS_PER_MS-1) begin
                tick_count <= 17'd0;
                time_ms <= time_ms + 16'd1;
            end else tick_count <= tick_count + 17'd1;
            if (I_camera_frame_start) begin
                frame_seq <= frame_seq + 8'd1;
                slot_seq[I_write_slot] <= frame_seq + 8'd1;
                slot_time_ms[I_write_slot] <= time_ms;
                slot_valid[I_write_slot] <= 1'b1;
                slot_capture_valid[I_write_slot] <= 1'b0;
                pending_pair <= 1'b0;
                // Both frame markers originate in the camera-clock domain.
                // Accept exactly one new CSI event for this ISP frame.
                if (unpaired_mipi == 8'd1 && mipi_to_isp_ms <= 16'd99) begin
                    slot_capture_ms[I_write_slot] <= mipi_time_ms;
                    slot_capture_valid[I_write_slot] <= 1'b1;
                    linked_mipi_seq <= mipi_seq;
                end else if (unpaired_mipi == 8'd0 && mipi_event) begin
                    // The two CDC paths may deliver markers in either order.
                    slot_capture_ms[I_write_slot] <= time_ms;
                    slot_capture_valid[I_write_slot] <= 1'b1;
                    linked_mipi_seq <= mipi_seq + 8'd1;
                end else if (unpaired_mipi == 8'd0) begin
                    pending_pair <= 1'b1;
                    pending_slot <= I_write_slot;
                    pending_wait <= 5'd0;
                end else begin
                    // Missing or extra frame marker: suppress the bad value
                    // and re-synchronize on the next frame.
                    linked_mipi_seq <= mipi_seq;
                end
                display_frames_without_capture <= 3'd0;
            end else if (I_display_frame_start && display_frames_without_capture < 3'd4) begin
                display_frames_without_capture <= display_frames_without_capture + 3'd1;
            end
            if (pending_pair && !I_camera_frame_start) begin
                if (mipi_event && unpaired_mipi == 8'd0) begin
                    slot_capture_ms[pending_slot] <= time_ms;
                    slot_capture_valid[pending_slot] <= 1'b1;
                    linked_mipi_seq <= mipi_seq + 8'd1;
                    pending_pair <= 1'b0;
                end else if (pending_wait == PAIR_WAIT_CYCLES-1) begin
                    pending_pair <= 1'b0;
                end else pending_wait <= pending_wait + 5'd1;
            end
            if (I_display_frame_start) begin
                // Latch the same slot video_out selects at the frame boundary.
                selected_lag <= age_now[3:0];
                // Publish frame identity at the DDR read-slot boundary, well
                // before the first active pixel. Latency metrics are sampled
                // later and must not delay the motion detector's identity.
                frame_id_ddr <= slot_seq[I_read_slot];
                frame_id_valid_ddr <= slot_valid[I_read_slot] &&
                                      (age_now >= 8'd1) && (age_now <= 8'd3) &&
                                      (display_frames_without_capture < 3'd4);
                frame_id_toggle <= ~frame_id_toggle;
                selected_time_ms <= slot_time_ms[I_read_slot];
                selected_capture_ms <= slot_capture_ms[I_read_slot];
                selected_valid <= slot_valid[I_read_slot] &&
                                  (age_now >= 8'd1) && (age_now <= 8'd3) &&
                                  (display_frames_without_capture < 3'd4);
                selected_capture_valid <= slot_capture_valid[I_read_slot];
                await_first_pixel <= 1'b1;
            end else if (first_active_edge && await_first_pixel) begin
                // First active HDMI pixel of the selected frame, quantized to
                // 1 ms. Invalid/overrange values are displayed as "--".
                lag_ddr <= selected_lag;
                latency_ddr <= elapsed_ms[6:0];
                valid_ddr <= selected_valid && (elapsed_ms <= 16'd99);
                capture_latency_ddr <= capture_elapsed_ms[6:0];
                capture_valid_ddr <= selected_valid && selected_capture_valid &&
                                     (capture_elapsed_ms <= 16'd99) &&
                                     (capture_elapsed_ms >= elapsed_ms);
                update_toggle <= ~update_toggle;
                await_first_pixel <= 1'b0;
            end
        end
    end

    // Bundled-data toggle CDC. The DDR result remains stable for a full frame;
    // sample its bus only after the toggle has crossed two pixel-clock flops.
    reg toggle_meta, toggle_sync, toggle_seen;
    reg id_meta, id_sync, id_seen;
    always @(posedge I_pixel_clk or negedge I_pixel_rst_n) begin
        if (!I_pixel_rst_n) begin
            toggle_meta <= 1'b0; toggle_sync <= 1'b0;
            toggle_seen <= 1'b0;
            id_meta <= 1'b0; id_sync <= 1'b0; id_seen <= 1'b0;
            O_lag_frames <= 4'd0; O_latency_ms <= 7'd0;
            O_valid <= 1'b0;
            O_capture_latency_ms <= 7'd0;
            O_capture_valid <= 1'b0;
            O_display_frame_id <= 8'd0;
            O_display_frame_id_valid <= 1'b0;
        end else begin
            toggle_meta <= update_toggle;
            toggle_sync <= toggle_meta;
            id_meta <= frame_id_toggle;
            id_sync <= id_meta;
            if (id_sync != id_seen) begin
                id_seen <= id_sync;
                O_display_frame_id <= frame_id_ddr;
                O_display_frame_id_valid <= frame_id_valid_ddr;
            end
            if (toggle_sync != toggle_seen) begin
                toggle_seen <= toggle_sync;
                O_lag_frames <= lag_ddr;
                O_latency_ms <= latency_ddr;
                O_valid <= valid_ddr;
                O_capture_latency_ms <= capture_latency_ddr;
                O_capture_valid <= capture_valid_ddr;
            end
        end
    end
endmodule
