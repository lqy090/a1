`timescale 1ns/1ps
module tb_shape_classify;
    localparam W=160, H=120;
    reg clk=0, rst_n=0, vsync=0, de=0;
    reg [3:0] mask=0;
    reg valid=1;
    reg [2:0] color=2;
    reg [10:0] x0=40,y0=30,x1=99,y1=89;
    wire out_valid;
    wire [2:0] out_color,out_shape;
    integer px,py,kind,dx,dy;
    always #5 clk=~clk;
    shape_classify #(.WIDTH(W),.HEIGHT(H),.ROI_MARGIN(8),.MIN_SAMPLES(50)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vsync),.I_de(de),
        .I_mask(mask),.I_target_valid(valid),.I_target_color(color),
        .I_x0(x0),.I_y0(y0),.I_x1(x1),.I_y1(y1),
        .O_valid(out_valid),.O_color(out_color),.O_shape(out_shape)
    );
    function object_pixel;
        input integer shape, sx, sy;
        integer ax, ay;
        begin
            ax=sx-80; ay=sy-60;
            case(shape)
                1: object_pixel=(sx>=50 && sx<=109 && sy>=30 && sy<=89);
                2: object_pixel=(sx>=30 && sx<=129 && sy>=40 && sy<=79);
                3: object_pixel=(ax*ax+ay*ay<=900);
                4: object_pixel=(sy>=20 && sy<=99 &&
                                 ((sx-80)*2<=sy-20) &&
                                 ((80-sx)*2<=sy-20));
                default: object_pixel=0;
            endcase
        end
    endfunction
    task frame;
        begin
            @(negedge clk); vsync=1; de=0; mask=0;
            @(negedge clk); vsync=0;
            for(py=0;py<H;py=py+1) begin
                for(px=0;px<W;px=px+1) begin
                    de=1;
                    mask=object_pixel(kind,px,py) && !px[0] && !py[0] ?
                         (4'b0001 << (color-1'b1)):0;
                    @(negedge clk);
                end
                de=0; mask=0;
                @(negedge clk);
            end
        end
    endtask
    task check_shape;
        input integer expected;
        begin
            frame(); frame();
            if (!out_valid || out_color!=color || out_shape!=expected) begin
                $display("shape %0d expected %0d got valid=%b shape=%0d area=%0d w=%0d h=%0d q=%0d/%0d/%0d",
                    kind,expected,out_valid,out_shape,dut.snap_area,dut.snap_w,dut.snap_h,
                    dut.snap_q1,dut.snap_mid,dut.snap_q3);
                $fatal(1,"shape mismatch");
            end
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        kind=1; color=1; x0=50;y0=30;x1=109;y1=89; check_shape(2);
        kind=2; color=2; x0=30;y0=40;x1=129;y1=79; check_shape(2);
        kind=3; color=3; x0=50;y0=30;x1=110;y1=90;
        frame(); frame();
        if (out_valid || out_shape!=0)
            $fatal(1,"circle must not receive a shape label");
        kind=4; color=4; x0=40;y0=20;x1=120;y1=99; check_shape(4);
        kind=0; frame(); frame();
        if (out_valid) $fatal(1,"empty frame classified as a shape");
        $display("PASS tb_shape_classify");
        $finish;
    end
endmodule
