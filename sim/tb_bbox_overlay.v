`timescale 1ns/1ps
module tb_bbox_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0, valid=1;
    reg [2:0] color=1;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer x,y,ox=0,oy=0,errors=0;
    reg old_de=0,old_vs=0;
    bbox_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(hs),
        .I_de(de),.I_rgb(24'h112233),.I_enable(1'b1),
        .I_valid(valid),.I_color(color),
        .I_x0(11'd2),.I_y0(11'd1),.I_x1(11'd5),.I_y1(11'd3),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb)
    );
    always @(posedge clk) if(rst_n) begin
        #1;
        if (ovs && !old_vs) begin ox=0; oy=0; end
        else if(old_de && !ode) begin ox=0; oy=oy+1; end
        if(ode) begin
            if(ox==3 || oy==2) begin
                if(orgb !== 24'hffffff) errors=errors+1;
            end else if(ox>=2 && ox<=5 && oy>=1 && oy<=3) begin
                if(orgb !== 24'hff4040) errors=errors+1;
            end else if(orgb !== 24'h112233) errors=errors+1;
            ox=ox+1;
        end
        old_de=ode; old_vs=ovs;
    end
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        vs=1; @(negedge clk); vs=0;
        for(y=0;y<5;y=y+1) begin
            for(x=0;x<8;x=x+1) begin de=1; hs=1; @(negedge clk); end
            de=0; hs=0; repeat(3) @(negedge clk);
        end
        repeat(4) @(negedge clk);
        if(errors==0) $display("PASS tb_bbox_overlay");
        else $fatal(1,"tb_bbox_overlay errors=%0d",errors);
        $finish;
    end
endmodule
