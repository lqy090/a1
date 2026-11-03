// Read-only video diagnostics. No pixel or camera-control path is modified.
module video_metrics_counter #(
    parameter integer SYS_CLOCK_HZ = 50000000
) (
    input wire I_sys_clk, I_cam_clk, I_pixel_clk, I_rst_n,
    input wire I_cam_frame_start,
    input wire I_hdmi_vsync, I_hdmi_de,
    output reg [11:0] O_cam_fps_bcd, O_hdmi_fps_bcd,
    output reg O_fps_valid,
    output reg [15:0] O_width_bcd, O_height_bcd,
    output reg O_size_valid
);
    // A toggle preserves a one-cycle MIPI frame pulse across clock domains.
    reg cam_start_d, cam_toggle;
    always @(posedge I_cam_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin cam_start_d<=0; cam_toggle<=0; end
        else begin
            cam_start_d <= I_cam_frame_start;
            if (I_cam_frame_start && !cam_start_d) cam_toggle <= ~cam_toggle;
        end
    end
    reg hdmi_vs_d, hdmi_toggle;
    always @(posedge I_pixel_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin hdmi_vs_d<=0; hdmi_toggle<=0; end
        else begin
            hdmi_vs_d <= I_hdmi_vsync;
            if (I_hdmi_vsync && !hdmi_vs_d) hdmi_toggle <= ~hdmi_toggle;
        end
    end

    function [11:0] bcd8;
        input [7:0] value;
        reg [11:0] digits;
        integer k;
        begin
            digits=12'd0;
            for (k=7;k>=0;k=k-1) begin
                if (digits[3:0]>=5) digits[3:0]=digits[3:0]+4'd3;
                if (digits[7:4]>=5) digits[7:4]=digits[7:4]+4'd3;
                if (digits[11:8]>=5) digits[11:8]=digits[11:8]+4'd3;
                digits={digits[10:0],value[k]};
            end
            bcd8=digits;
        end
    endfunction
    reg cam_meta,cam_sync,cam_seen,out_meta,out_sync,out_seen;
    wire cam_event = cam_sync != cam_seen;
    wire out_event = out_sync != out_seen;
    reg [25:0] second_count;
    reg [7:0] cam_count,out_count;
    wire [7:0] cam_total = (cam_count==8'hff) ? 8'hff :
                            cam_count + {7'd0,cam_event};
    wire [7:0] out_total = (out_count==8'hff) ? 8'hff :
                            out_count + {7'd0,out_event};
    reg [11:0] cam_bcd_sys,out_bcd_sys;
    reg fps_valid_sys,fps_toggle;
    always @(posedge I_sys_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            cam_meta<=0;cam_sync<=0;cam_seen<=0;
            out_meta<=0;out_sync<=0;out_seen<=0;
            second_count<=0;cam_count<=0;out_count<=0;
            cam_bcd_sys<=0;out_bcd_sys<=0;
            fps_valid_sys<=0;fps_toggle<=0;
        end else begin
            cam_meta<=cam_toggle;cam_sync<=cam_meta;cam_seen<=cam_sync;
            out_meta<=hdmi_toggle;out_sync<=out_meta;out_seen<=out_sync;
            if(second_count==SYS_CLOCK_HZ-1) begin
                second_count<=0;
                cam_bcd_sys<=bcd8(cam_total);
                out_bcd_sys<=bcd8(out_total);
                cam_count<=0;out_count<=0;
                fps_valid_sys<=1;
                fps_toggle<=~fps_toggle;
            end else begin
                second_count<=second_count+26'd1;
                if(cam_event) cam_count<=cam_total;
                if(out_event) out_count<=out_total;
            end
        end
    end
    // The BCD buses stay fixed for one second before the next update.
    reg fps_meta,fps_sync,fps_seen;
    always @(posedge I_pixel_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            fps_meta<=0;fps_sync<=0;fps_seen<=0;
            O_cam_fps_bcd<=0;O_hdmi_fps_bcd<=0;O_fps_valid<=0;
        end else begin
            fps_meta<=fps_toggle;fps_sync<=fps_meta;
            if(fps_sync!=fps_seen) begin
                fps_seen<=fps_sync;
                O_cam_fps_bcd<=cam_bcd_sys;
                O_hdmi_fps_bcd<=out_bcd_sys;
                O_fps_valid<=fps_valid_sys;
            end
        end
    end

    // Count the actual HDMI active pixels and lines. Convert the completed
    // frame's dimensions to BCD during vertical blanking (12 pixel clocks).
    function [15:0] bcd_step;
        input [15:0] previous;
        input next_bit;
        reg [15:0] d;
        begin
            d=previous;
            if(d[3:0]>=5) d[3:0]=d[3:0]+4'd3;
            if(d[7:4]>=5) d[7:4]=d[7:4]+4'd3;
            if(d[11:8]>=5) d[11:8]=d[11:8]+4'd3;
            if(d[15:12]>=5) d[15:12]=d[15:12]+4'd3;
            bcd_step={d[14:0],next_bit};
        end
    endfunction
    reg de_prev,vs_prev;
    reg [11:0] line_pixels,active_lines,frame_width;
    reg saw_line,width_consistent;
    reg converting;
    reg [3:0] step_index;
    reg [11:0] width_shift,height_shift;
    reg [15:0] width_bcd_work,height_bcd_work;
    wire [15:0] width_bcd_next = bcd_step(width_bcd_work,width_shift[11]);
    wire [15:0] height_bcd_next = bcd_step(height_bcd_work,height_shift[11]);
    always @(posedge I_pixel_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            de_prev<=0;vs_prev<=0;
            line_pixels<=0;active_lines<=0;frame_width<=0;
            saw_line<=0;width_consistent<=1;
            converting<=0;step_index<=0;
            width_shift<=0;height_shift<=0;
            width_bcd_work<=0;height_bcd_work<=0;
            O_width_bcd<=0;O_height_bcd<=0;O_size_valid<=0;
        end else begin
            de_prev<=I_hdmi_de;vs_prev<=I_hdmi_vsync;
            if(I_hdmi_vsync && !vs_prev) begin
                if(saw_line && width_consistent && active_lines!=0) begin
                    width_shift<=frame_width;
                    height_shift<=active_lines;
                    width_bcd_work<=0;height_bcd_work<=0;
                    step_index<=0;converting<=1;
                end else begin
                    converting<=0;
                    O_size_valid<=0;
                end
                line_pixels<=0;active_lines<=0;frame_width<=0;
                saw_line<=0;width_consistent<=1;
            end else begin
                if(I_hdmi_de) line_pixels<=line_pixels+12'd1;
                if(de_prev && !I_hdmi_de) begin
                    if(!saw_line) begin frame_width<=line_pixels;saw_line<=1;end
                    else if(line_pixels!=frame_width) width_consistent<=0;
                    active_lines<=active_lines+12'd1;
                    line_pixels<=0;
                end
                if(converting) begin
                    width_bcd_work<=width_bcd_next;
                    height_bcd_work<=height_bcd_next;
                    width_shift<={width_shift[10:0],1'b0};
                    height_shift<={height_shift[10:0],1'b0};
                    if(step_index==4'd11) begin
                        O_width_bcd<=width_bcd_next;
                        O_height_bcd<=height_bcd_next;
                        O_size_valid<=1;
                        converting<=0;
                    end else step_index<=step_index+4'd1;
                end
            end
        end
    end
endmodule
