`timescale 1ns/1ps
module tb_shape_label_overlay;
    reg clk=0, rst_n=0, vsync=0, hsync=0, de=0;
    reg enable=1, target_valid=1, shape_valid=1;
    reg [2:0] target_color=2, shape_color=2, shape=4;
    reg [10:0] x0=10,y0=50;
    reg [23:0] rgb=24'h123456;
    wire out_vsync,out_hsync,out_de;
    wire [23:0] out_rgb;
    integer px,py;
    always #5 clk=~clk;
    shape_label_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vsync),.I_hsync(hsync),
        .I_de(de),.I_rgb(rgb),.I_enable(enable),
        .I_target_valid(target_valid),.I_target_color(target_color),
        .I_shape_valid(shape_valid),.I_shape_color(shape_color),
        .I_shape(shape),.I_x0(x0),.I_y0(y0),
        .O_vsync(out_vsync),.O_hsync(out_hsync),.O_de(out_de),.O_rgb(out_rgb)
    );
    task start_frame;
        begin
            @(negedge clk); vsync=1; de=0;
            @(negedge clk); vsync=0;
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        start_frame(); start_frame();
        if (dut.shape_q!=4) $fatal(1,"stable shape did not latch");
        for(py=0;py<7;py=py+1) begin
            for(px=0;px<200;px=px+1) begin
                @(negedge clk); de=1;
                @(posedge clk); #1;
                if (py==6 && px==10 && out_rgb!=24'h40a0ff)
                    $fatal(1,"shape panel absent");
                if (py==6 && px==190 && out_rgb!=rgb)
                    $fatal(1,"shape panel changed unrelated pixel");
            end
            @(negedge clk); de=0;
            @(posedge clk); #1;
        end
        enable=0; start_frame();
        if (dut.shape_q!=0) $fatal(1,"disable did not hide shape");
        enable=1; shape=3; start_frame(); start_frame();
        if (dut.shape_q!=0) $fatal(1,"unsupported circle label appeared");
        shape=2; start_frame(); start_frame();
        if (dut.shape_q!=2) $fatal(1,"rectangle label did not latch");
        shape=1; start_frame(); start_frame();
        if (dut.shape_q!=0) $fatal(1,"legacy square label appeared");
        $display("PASS tb_shape_label_overlay");
        $finish;
    end
endmodule
