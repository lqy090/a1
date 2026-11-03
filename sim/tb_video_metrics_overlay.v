`timescale 1ns/1ps
module tb_video_metrics_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,vs=0,hs=0,de=0;
    reg [23:0] rgb=24'h315c7d;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer row,col,errors=0;
    video_metrics_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_rgb(rgb),
        .I_cam_fps_bcd(12'h060),.I_hdmi_fps_bcd(12'h061),
        .I_fps_valid(1'b1),.I_width_bcd(16'h1280),
        .I_height_bcd(16'h0720),.I_size_valid(1'b1),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        @(negedge clk); vs=1;
        @(posedge clk); #1;
        if(!ovs || ode) errors=errors+1;
        @(negedge clk); vs=0;
        for(row=0;row<=76;row=row+1) begin
            for(col=0;col<1280;col=col+1) begin
                @(negedge clk); de=1;hs=1;
                @(posedge clk); #1;
                if(!ode || ovs || !ohs) errors=errors+1;
                if(row==0 && col==0 && orgb!==24'h315c7d) errors=errors+1;
                if(row==28 && col==872 && orgb!==24'h4eb5ff) errors=errors+1;
                if(row==29 && col==900 && orgb!==24'h102430) errors=errors+1;
                if(row==36 && col==882 && orgb!==24'hffffff) errors=errors+1;
                if(row==56 && col==882 && orgb!==24'hffffff) errors=errors+1;
                if(row==76 && col==884 && orgb!==24'hffffff) errors=errors+1;
            end
            @(negedge clk); de=0;hs=0;
            @(posedge clk); #1;
            if(ode || orgb!==24'd0) errors=errors+1;
        end
        if(errors==0) $display("PASS tb_video_metrics_overlay");
        else $fatal(1,"tb_video_metrics_overlay errors=%0d",errors);
        $finish;
    end
endmodule
