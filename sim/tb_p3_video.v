`timescale 1ns/1ps
module tb_p3_video;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=0;
    reg [2:0] mode=0;
    wire ovs, ohs, ode;
    wire [23:0] orgb;

    video_fx_pipeline #(
        .WIDTH(4), .AUTO_THRESHOLDS(0), .EDGE_DENOISE(0),
        .EDGE_STABILIZE(0),
        .BINARY_INITIAL_THRESHOLD(8'd96),
        .EDGE_INITIAL_THRESHOLD(8'd48)
    ) dut(
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_hsync(hs),
        .I_de(de), .I_rgb(rgb), .I_mode(mode), .I_gamma_enable(1'b0),
        .O_vsync(ovs), .O_hsync(ohs), .O_de(ode), .O_rgb(orgb)
    );

    reg [23:0] qrgb0=0,qrgb1=0,qrgb2=0;
    reg qde0=0,qde1=0,qde2=0;
    reg qvs0=0,qvs1=0,qvs2=0;
    reg qhs0=0,qhs1=0,qhs2=0;
    reg [7:0] mem [0:3];
    reg [7:0] left=0;
    reg have_up=0, de_old=0, vs_old=0;
    integer x=0, cycles=0, errors=0;
    integer gray, up, dh, dv, val;
    reg [23:0] expected_rgb;

    always @(posedge clk) if (rst_n) begin
        gray = (rgb[23:16] >> 2) + (rgb[15:8] >> 1) + (rgb[7:0] >> 2);
        expected_rgb = 0;
        if (de) begin
            case (mode)
                0: expected_rgb = rgb;
                1: expected_rgb = {3{gray[7:0]}};
                2: expected_rgb = (gray >= 96) ? 24'hffffff : 24'h000000;
                3: begin
                    up = have_up ? mem[x] : gray;
                    dh = (x == 0) ? 0 : ((gray > left) ? gray-left : left-gray);
                    dv = (gray > up) ? gray-up : up-gray;
                    val = (dh+dv >= 48) ? 255 : 0;
                    expected_rgb = {3{val[7:0]}};
                end
                4: begin
                    up = have_up ? mem[x] : gray;
                    dh = (x == 0) ? 0 : ((gray > left) ? gray-left : left-gray);
                    dv = (gray > up) ? gray-up : up-gray;
                    expected_rgb = (dh+dv >= 48) ? 24'h000000 : {
                        {4{rgb[23:22]}}, {4{rgb[15:14]}}, {4{rgb[7:6]}}
                    };
                end
                5: expected_rgb = ~rgb;
            endcase
            mem[x] = gray;
            left = gray;
            x = x+1;
        end else begin
            x = 0;
            left = 0;
            if (de_old) have_up=1;
        end
        if (vs && !vs_old) have_up=0;
        de_old=de; vs_old=vs;

        qrgb2=qrgb1; qrgb1=qrgb0; qrgb0=expected_rgb;
        qde2=qde1; qde1=qde0; qde0=de;
        qvs2=qvs1; qvs1=qvs0; qvs0=vs;
        qhs2=qhs1; qhs1=qhs0; qhs0=hs;
        #1;
        cycles=cycles+1;
        if (ode !== qde2 || ovs !== qvs2 || ohs !== qhs2 || orgb !== qrgb2) begin
            $display("FAIL cycle=%0d mode=%0d de=%b/%b vs=%b/%b rgb=%h/%h", cycles, mode, ode,qde2,ovs,qvs2,orgb,qrgb2);
            errors=errors+1;
        end
    end

    task put;
        input d, v, h;
        input [23:0] c;
        begin
            @(negedge clk); de=d; vs=v; hs=h; rgb=c;
        end
    endtask
    task wait_clocks;
        input integer n;
        integer k;
        begin for(k=0;k<n;k=k+1) @(negedge clk); end
    endtask
    task frame;
        input [2:0] m;
        begin
            mode=m;
            put(0,1,0,0); put(0,0,0,0);
            put(1,0,1,24'h000000); put(1,0,1,24'h203040);
            put(1,0,1,24'hffffff); put(1,0,1,24'hffffff);
            put(0,0,0,0); put(0,0,0,0);
            put(1,0,1,24'h000000); put(1,0,1,24'h203040);
            put(1,0,1,24'hffffff); put(1,0,1,24'hffffff);
            put(0,0,0,0); wait_clocks(4);
        end
    endtask

    initial begin
        wait_clocks(3); rst_n=1;
        frame(0); frame(1); frame(2); frame(3); frame(4); frame(5);
        if (errors == 0) $display("PASS tb_p3_video cycles=%0d",cycles);
        else $fatal(1,"tb_p3_video errors=%0d",errors);
        $finish;
    end
endmodule
