`timescale 1ns/1ps
module tb_frame_buffer_lag;
    reg ddr_clk=0, pixel_clk=0, cam_clk=0;
    always #4 ddr_clk=~ddr_clk;
    always #5 pixel_clk=~pixel_clk;
    always #3 cam_clk=~cam_clk;
    reg ddr_rst_n=0, pixel_rst_n=0, cam_rst_n=0;
    reg mipi_start=0, capture=0, display=0, hdmi_de=0;
    reg [1:0] write_slot=0, read_slot=0;
    wire [3:0] lag;
    wire [6:0] latency_ms;
    wire [6:0] capture_latency_ms;
    wire valid,capture_valid;
    wire [7:0] display_frame_id;
    wire display_frame_id_valid;
    integer errors=0;
    time slot_stamp[0:3];
    time mipi_stamp[0:3];
    time first_pixel_stamp;
    integer expected_ms;
    frame_buffer_lag #(.TICKS_PER_MS(10)) dut(
        .I_cam_clk(cam_clk),.I_cam_rst_n(cam_rst_n),
        .I_mipi_frame_start(mipi_start),
        .I_ddr_clk(ddr_clk),.I_ddr_rst_n(ddr_rst_n),
        .I_camera_frame_start(capture),.I_write_slot(write_slot),
        .I_display_frame_start(display),.I_read_slot(read_slot),
        .I_hdmi_de(hdmi_de),
        .I_pixel_clk(pixel_clk),.I_pixel_rst_n(pixel_rst_n),
        .O_lag_frames(lag),.O_latency_ms(latency_ms),.O_valid(valid),
        .O_capture_latency_ms(capture_latency_ms),.O_capture_valid(capture_valid),
        .O_display_frame_id(display_frame_id),
        .O_display_frame_id_valid(display_frame_id_valid));

    task mipi_frame;
        input [1:0] slot;
        begin
            @(negedge cam_clk); mipi_start=1; mipi_stamp[slot]=$time;
            @(negedge cam_clk); mipi_start=0;
            repeat(5) @(negedge ddr_clk);
        end
    endtask

    task camera_frame;
        input [1:0] slot;
        begin
            mipi_frame(slot);
            @(negedge ddr_clk); write_slot=slot; capture=1;
            @(posedge ddr_clk); slot_stamp[slot]=$time;
            @(negedge ddr_clk); capture=0;
        end
    endtask
    task camera_frame_no_mipi;
        input [1:0] slot;
        begin
            @(negedge ddr_clk); write_slot=slot; capture=1;
            @(posedge ddr_clk); slot_stamp[slot]=$time;
            @(negedge ddr_clk); capture=0;
            repeat(20) @(negedge ddr_clk); // let the pairing window expire
        end
    endtask
    task display_frame;
        input [1:0] slot;
        input expected_valid;
        input [3:0] expected_lag;
        input expected_capture_valid;
        begin
            @(negedge ddr_clk); read_slot=slot; display=1;
            @(negedge ddr_clk); display=0;
            repeat(4) @(posedge pixel_clk);
            if (display_frame_id_valid !== expected_valid ||
                (expected_valid && display_frame_id !== dut.slot_seq[slot])) begin
                $display("FAIL early frame ID slot=%d ID=%d valid=%b",
                    slot,display_frame_id,display_frame_id_valid);
                errors=errors+1;
            end
            @(negedge pixel_clk); hdmi_de=1;
            first_pixel_stamp=$time;
            repeat(4) @(posedge pixel_clk);
            @(negedge pixel_clk); hdmi_de=0;
            repeat(5) @(posedge pixel_clk);
            #1;
            if (valid !== expected_valid ||
                capture_valid !== expected_capture_valid ||
                (expected_valid && lag !== expected_lag)) begin
                $display("FAIL slot=%d got valid=%b capture_valid=%b lag=%d expected=%b/%b/%d",
                    slot,valid,capture_valid,lag,expected_valid,expected_capture_valid,expected_lag);
                errors=errors+1;
            end
            if (expected_valid) begin
                expected_ms=(first_pixel_stamp-slot_stamp[slot])/80;
                if (latency_ms < expected_ms-1 || latency_ms > expected_ms+1) begin
                    $display("FAIL slot=%d latency=%dms expected~%dms",
                        slot,latency_ms,expected_ms);
                    errors=errors+1;
                end
            end
            if (expected_capture_valid) begin
                expected_ms=(first_pixel_stamp-mipi_stamp[slot])/80;
                if (capture_latency_ms < expected_ms-1 || capture_latency_ms > expected_ms+1 ||
                    capture_latency_ms < latency_ms) begin
                    $display("FAIL slot=%d CSI-HDMI=%dms expected~%dms buffer=%dms",
                        slot,capture_latency_ms,expected_ms,latency_ms);
                    errors=errors+1;
                end
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge ddr_clk);
        ddr_rst_n=1; pixel_rst_n=1; cam_rst_n=1;
        display_frame(2'd2,1'b0,4'd0,1'b0); // no captured image yet
        camera_frame(2'd0); // frame 1 being written into slot 0
        display_frame(2'd0,1'b0,4'd0,1'b0); // incomplete frame is invalid
        camera_frame(2'd1); // frame 2
        camera_frame(2'd2); // frame 3
        repeat(30) @(posedge ddr_clk);
        display_frame(2'd0,1'b1,4'd2,1'b1);
        camera_frame(2'd3); // frame 4
        display_frame(2'd1,1'b1,4'd2,1'b1);
        camera_frame(2'd0); // frame 5 replaces slot 0
        display_frame(2'd2,1'b1,4'd2,1'b1);
        display_frame(2'd3,1'b1,4'd1,1'b1);
        display_frame(2'd0,1'b0,4'd0,1'b0); // current writer, not completed
        display_frame(2'd3,1'b1,4'd1,1'b1);
        display_frame(2'd3,1'b0,4'd0,1'b0); // capture stalled: invalidate old lag
        camera_frame_no_mipi(2'd1); // missing CSI marker: show --, not a stale timestamp
        camera_frame(2'd2);
        display_frame(2'd1,1'b1,4'd1,1'b0);
        camera_frame(2'd3);
        display_frame(2'd2,1'b1,4'd1,1'b1); // recovery on the next matched frame
        mipi_frame(2'd0); // extra CSI marker before the next ISP frame
        camera_frame(2'd0);
        camera_frame(2'd1);
        display_frame(2'd0,1'b1,4'd1,1'b0); // mismatch must not get a timestamp
        camera_frame(2'd2);
        display_frame(2'd1,1'b1,4'd1,1'b1); // resynchronised after mismatch
        if (errors==0) $display("PASS tb_frame_buffer_lag");
        else $fatal(1,"tb_frame_buffer_lag errors=%0d",errors);
        $finish;
    end
endmodule
