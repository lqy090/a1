`timescale 1ns/1ps
module tb_frame_lag_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=24'h315c7d;
    reg [3:0] lag=2;
    reg [6:0] ms=32;
    reg [6:0] capture_ms=42;
    reg valid=1,capture_valid=1;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer row,col,errors=0;
    frame_lag_overlay dut(.I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_rgb(rgb),
        .I_lag_frames(lag),.I_latency_ms(ms),.I_lag_valid(valid),
        .I_capture_latency_ms(capture_ms),.I_capture_valid(capture_valid),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        @(negedge clk); vs=1;
        @(posedge clk); #1;
        if (!ovs || ode) errors=errors+1;
        @(negedge clk); vs=0;
        for(row=0;row<=100;row=row+1) begin
            for(col=0;col<1280;col=col+1) begin
                @(negedge clk); de=1; hs=1;
                @(posedge clk); #1;
                if (!ode || ovs || !ohs) errors=errors+1;
                if(row==0 && col==0 && orgb!==24'h315c7d) errors=errors+1;
                if(row==28 && col==1084 && orgb!==24'h4eb5ff) errors=errors+1;
                if(row==29 && col==1100 && orgb!==24'h102430) errors=errors+1;
                if(row==46 && col==1096 && orgb!==24'hffffff) errors=errors+1;
                if(row==68 && col==1096 && orgb!==24'hffffff) errors=errors+1;
                if(row==68 && col==1112 && orgb!==24'hffffff) errors=errors+1;
                if(row==90 && col==1098 && orgb!==24'hffffff) errors=errors+1; // C
                if(row==90 && col==1114 && orgb!==24'hffffff) errors=errors+1; // 2
                if(row==90 && col==1128 && orgb!==24'hffffff) errors=errors+1; // H
                if(row==90 && col==1160 && orgb!==24'hffffff) errors=errors+1; // 4
            end
            @(negedge clk); de=0; hs=0;
            @(posedge clk); #1;
            if (ode || orgb!==24'd0) errors=errors+1;
        end
        @(negedge clk); capture_valid=0; dut.x=1160; dut.y=90; de=1;
        @(posedge clk); #1;
        if(orgb!==24'h102430) begin
            $display("FAIL invalid C2H digit top pixel=%h",orgb); errors=errors+1;
        end
        @(negedge clk); dut.x=1160; dut.y=96;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL invalid C2H dash pixel=%h",orgb); errors=errors+1;
        end
        if(errors==0) $display("PASS tb_frame_lag_overlay");
        else $fatal(1,"tb_frame_lag_overlay errors=%0d",errors);
        $finish;
    end
endmodule
