`timescale 1ns/1ps
module tb_video_metrics_counter;
    reg sys_clk=0,cam_clk=0,pixel_clk=0,rst_n=0;
    always #10 sys_clk=~sys_clk;
    always #7 cam_clk=~cam_clk;
    always #5 pixel_clk=~pixel_clk;
    reg cam_fs=0,hdmi_vs=0,hdmi_de=0;
    wire [11:0] cam_fps_bcd,hdmi_fps_bcd;
    wire fps_valid,size_valid;
    wire [15:0] width_bcd,height_bcd;
    integer errors=0,i;
    video_metrics_counter #(.SYS_CLOCK_HZ(100)) dut(
        .I_sys_clk(sys_clk),.I_cam_clk(cam_clk),
        .I_pixel_clk(pixel_clk),.I_rst_n(rst_n),
        .I_cam_frame_start(cam_fs),.I_hdmi_vsync(hdmi_vs),
        .I_hdmi_de(hdmi_de),
        .O_cam_fps_bcd(cam_fps_bcd),.O_hdmi_fps_bcd(hdmi_fps_bcd),
        .O_fps_valid(fps_valid),.O_width_bcd(width_bcd),
        .O_height_bcd(height_bcd),.O_size_valid(size_valid));
    task cam_pulse;
        begin
            @(negedge cam_clk); cam_fs=1;
            @(negedge cam_clk); cam_fs=0;
        end
    endtask
    task vs_pulse;
        begin
            @(negedge pixel_clk); hdmi_vs=1;
            @(negedge pixel_clk); hdmi_vs=0;
        end
    endtask
    task active_line;
        input integer n;
        integer k;
        begin
            for(k=0;k<n;k=k+1) begin
                @(negedge pixel_clk); hdmi_de=1;
            end
            @(negedge pixel_clk); hdmi_de=0;
            repeat(2) @(posedge pixel_clk);
        end
    endtask
    initial begin
        #70 rst_n=1;
        if(fps_valid!==0 || size_valid!==0) errors=errors+1;
        fork
            begin #100 cam_pulse; #300 cam_pulse; #300 cam_pulse; end
            begin #150 vs_pulse; #450 vs_pulse; end
        join
        #1500;
        if(!fps_valid || cam_fps_bcd!==12'h003 || hdmi_fps_bcd!==12'h002) begin
            $display("FAIL first window cam=%h hdmi=%h valid=%b",
                cam_fps_bcd,hdmi_fps_bcd,fps_valid); errors=errors+1;
        end
        #2200;
        if(cam_fps_bcd!==12'h000 || hdmi_fps_bcd!==12'h000) begin
            $display("FAIL stop-to-zero cam=%h hdmi=%h",cam_fps_bcd,hdmi_fps_bcd);
            errors=errors+1;
        end
        active_line(8);active_line(8);active_line(8);
        vs_pulse;
        repeat(16) @(posedge pixel_clk);
        #1;
        if(!size_valid || width_bcd!==16'h0008 || height_bcd!==16'h0003) begin
            $display("FAIL size width=%h height=%h valid=%b",
                width_bcd,height_bcd,size_valid);errors=errors+1;
        end
        active_line(8);active_line(7);
        vs_pulse;
        #1;
        if(size_valid) begin
            $display("FAIL inconsistent width accepted");errors=errors+1;
        end
        if(errors==0) $display("PASS tb_video_metrics_counter");
        else $fatal(1,"tb_video_metrics_counter errors=%0d",errors);
        $finish;
    end
endmodule
