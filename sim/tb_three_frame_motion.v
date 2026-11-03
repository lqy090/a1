`timescale 1ns/1ps
module tb_three_frame_motion;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vsync=0, de=0, enable=0;
    reg [23:0] rgb=0;
    reg [2:0] brightness=5;
    reg [7:0] frame_id=0;
    reg frame_id_valid=1;
    wire [4:0] box_count;
    wire [415:0] boxes;
    wire overflow;
    integer xx, yy;
    three_frame_motion_serial #(.WIDTH(224),.HEIGHT(128),.GRID_W(14),.GRID_H(8),
                         .DIFF_THRESHOLD(7),.GLOBAL_CHANGE_LIMIT(60)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vsync),.I_de(de),.I_rgb(rgb),
        .I_enable(enable),.I_brightness_level(brightness),
        .I_exposure_epoch(1'b0),.I_frame_id(frame_id),.I_frame_id_valid(frame_id_valid),
        .O_box_count(box_count),.O_boxes(boxes),.O_overflow(overflow));
    task send_frame;
        input [7:0] id;
        input integer phase;
        begin
            frame_id=id;
            @(negedge clk); vsync=1;
            repeat(4) @(negedge clk);
            vsync=0;
            repeat(3000) @(negedge clk);
            for (yy=0;yy<128;yy=yy+1) begin
                for (xx=0;xx<224;xx=xx+1) begin
                    de=1;
                    if (yy>=32 && yy<64 &&
                        (((phase==1 || phase==3) && xx>=48 && xx<80) ||
                         ((phase==2 || phase==4) && xx>=64 && xx<96) ||
                         (phase==3 && xx>=128 && xx<160) ||
                         (phase==4 && xx>=144 && xx<176)))
                        rgb=24'hc0c0c0;
                    else rgb=24'h202020;
                    @(negedge clk);
                end
                de=0;
                repeat(2) @(negedge clk);
            end
            repeat(200) @(negedge clk);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1; enable=1;
        send_frame(8'd1,0);
        if (box_count!=0) $fatal(1,"first frame must prime history");
        send_frame(8'd2,1);
        if (box_count!=0) $fatal(1,"second frame must prime history");
        send_frame(8'd3,2);
        // Vsync of the next displayed frame starts the merge stage.
        @(negedge clk); vsync=1;
        repeat(4) @(negedge clk); vsync=0;
        repeat(3000) @(negedge clk);
        if (box_count!=1 || overflow || boxes[6:0]!=3 ||
            boxes[19:13]!=5 || boxes[12:7]!=2 || boxes[25:20]!=3)
            $fatal(1,"three-frame box mismatch count=%0d box=%h",box_count,boxes[25:0]);
        // A repeated HDMI refresh of captured frame 3 must not erase it.
        send_frame(8'd3,2);
        if (box_count!=1) $fatal(1,"duplicate capture frame erased detection");
        brightness=3'd6;
        send_frame(8'd4,2);
        if (box_count!=0) $fatal(1,"gain change did not clear history");
        enable=0;
        repeat(5) @(negedge clk);
        if (box_count!=0) $fatal(1,"KEY4 OFF did not hide boxes");
        enable=1;
        send_frame(8'd10,0);
        send_frame(8'd11,3);
        send_frame(8'd12,4);
        @(negedge clk); vsync=1;
        repeat(4) @(negedge clk); vsync=0;
        repeat(3000) @(negedge clk);
        if (box_count!=2 || overflow)
            $fatal(1,"two moving objects must make two independent boxes, count=%0d",box_count);
        $display("PASS tb_three_frame_motion");
        $finish;
    end
endmodule
