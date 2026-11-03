`timescale 1ns/1ps
module tb_motion_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vsync=0, hsync=0, de=0, enable=1;
    reg [23:0] rgb=24'h112233;
    reg [4:0] count=1;
    reg [415:0] boxes=0;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer xx,yy;
    motion_overlay dut(.I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vsync),.I_hsync(hsync),.I_de(de),.I_rgb(rgb),
        .I_enable(enable),.I_overflow(1'b0),
        .I_box_count(count),.I_boxes(boxes),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));
    initial begin
        boxes[25:0]={6'd3,7'd5,6'd2,7'd3};
        repeat(4) @(negedge clk);
        rst_n=1;
        @(negedge clk); vsync=1;
        @(negedge clk); vsync=0;
        for (yy=0;yy<64;yy=yy+1) begin
            for (xx=0;xx<128;xx=xx+1) begin
                de=1;
                @(posedge clk); #1;
                if ((xx==48 && yy==32) || (xx==95 && yy==63)) begin
                    if (orgb!==24'h80d8ff)
                        $fatal(1,"motion box border missing at %0d,%0d",xx,yy);
                end
                if (xx==64 && yy==40 && orgb!==rgb)
                    $fatal(1,"motion box filled its interior");
                @(negedge clk);
            end
            de=0;
            @(negedge clk);
        end
        $display("PASS tb_motion_overlay");
        $finish;
    end
endmodule
