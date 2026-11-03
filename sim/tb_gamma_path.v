`timescale 1ns/1ps
module tb_gamma_path;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0, gamma=1;
    reg [23:0] rgb=0;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer errors=0;
    reg [23:0] qrgb0=0,qrgb1=0,qrgb2=0,expected;
    reg qde0=0,qde1=0,qde2=0;
    reg qvs0=0,qvs1=0,qvs2=0;
    reg qhs0=0,qhs1=0,qhs2=0;

    video_fx_pipeline #(.WIDTH(4),.AUTO_THRESHOLDS(0),
        .EDGE_DENOISE(0),.EDGE_STABILIZE(0)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(hs),
        .I_de(de),.I_rgb(rgb),.I_mode(2'd0),.I_gamma_enable(gamma),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));

    always @(posedge clk) if(rst_n) begin
        expected=0;
        if(de) begin
            if(!gamma) expected=rgb;
            else case(rgb)
                24'h48544e: expected=24'hafbbb5;
                24'h91a595: expected=24'hd9eddd;
                24'h202020: expected=24'h0a0a0a;
                24'hffffff: expected=24'hffffff;
                default: expected=0;
            endcase
        end
        qrgb2=qrgb1; qrgb1=qrgb0; qrgb0=expected;
        qde2=qde1; qde1=qde0; qde0=de;
        qvs2=qvs1; qvs1=qvs0; qvs0=vs;
        qhs2=qhs1; qhs1=qhs0; qhs0=hs;
        #1;
        if(orgb!==qrgb2 || ode!==qde2 || ovs!==qvs2 || ohs!==qhs2) begin
            $display("FAIL gamma=%b rgb=%h/%h de=%b/%b",gamma,orgb,qrgb2,ode,qde2);
            errors=errors+1;
        end
    end

    task pixel;
        input [23:0] value;
        begin @(negedge clk); de=1; hs=1; vs=0; rgb=value; end
    endtask
    task blank;
        begin @(negedge clk); de=0; hs=0; vs=0; rgb=0; end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        @(negedge clk); vs=1;
        blank();
        pixel(24'h48544e); pixel(24'h91a595);
        pixel(24'h202020); pixel(24'hffffff);
        blank(); repeat(5) @(negedge clk);
        gamma=0;
        pixel(24'h48544e); pixel(24'h91a595);
        pixel(24'h202020); pixel(24'hffffff);
        blank(); repeat(5) @(negedge clk);
        if(errors==0) $display("PASS tb_gamma_path");
        else $fatal(1,"tb_gamma_path errors=%0d",errors);
        $finish;
    end
endmodule
