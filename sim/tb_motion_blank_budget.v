`timescale 1ns/1ps
module tb_motion_blank_budget;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,vsync=0,enable=1;
    wire [4:0] count;
    wire [415:0] boxes;
    wire overflow;
    integer i,t,cycles,seed;
    three_frame_motion_serial dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vsync),.I_de(1'b0),
        .I_rgb(24'd0),.I_enable(enable),.I_brightness_level(3'd5),
        .I_exposure_epoch(1'b0),.I_frame_id(8'd0),.I_frame_id_valid(1'b1),
        .O_box_count(count),.O_boxes(boxes),.O_overflow(overflow));
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1;
        repeat(5) @(negedge clk);
        seed=32'h15ac983;
        for (t=0;t<4;t=t+1) begin
            for (i=0;i<3600;i=i+1) begin
                seed=(seed*1103515245+12345) & 32'h7fffffff;
                // At most 900 changed tiles can enter the scan; larger
                // lighting/camera changes are suppressed by design.
                dut.motion_mask[i]=((seed>>16)%100)<(t==0 ? 10 :
                                                        (t==1 ? 20 : 25)) ?
                                    2'b11 : 2'b00;
            end
            @(negedge clk);
            dut.active_new=1;
            dut.history_count=3;
            dut.changed_tiles=0;
            vsync=1;
            repeat(4) @(negedge clk);
            vsync=0;
            cycles=0;
            while (dut.state!=0 && cycles<41000) begin
                @(negedge clk); cycles=cycles+1;
            end
            if (dut.state!=0)
                $fatal(1,"component scan exceeded 720p vsync-to-active blank t=%0d",t);
            $display("motion blank case %0d completed in %0d clocks",t,cycles);
        end
        $display("PASS tb_motion_blank_budget");
        $finish;
    end
endmodule
