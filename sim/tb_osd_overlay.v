`timescale 1ns/1ps
module tb_osd_overlay;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=24'h224466;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    reg qvs=0,qhs=0,qde=0;
    reg [23:0] qrgb=0;
    integer i, errors=0;

    osd_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(hs),.I_de(de),
        .I_data(rgb),.O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(orgb)
    );
    always @(posedge clk) if (rst_n) begin
        qvs=vs; qhs=hs; qde=de; qrgb=de?rgb:24'd0;
        #1;
        if (ovs !== qvs || ohs !== qhs || ode !== qde || orgb !== qrgb) begin
            $display("FAIL retired text layer vs=%b/%b de=%b/%b rgb=%h/%h",
                     ovs,qvs,ode,qde,orgb,qrgb);
            errors=errors+1;
        end
    end
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        for(i=0;i<100;i=i+1) begin
            @(negedge clk);
            vs=(i==0); hs=(i%12<8); de=(i%12<8);
            rgb=(i[0])?24'h224466:24'h123456;
        end
        if(errors==0) $display("PASS tb_osd_overlay pass-through");
        else $fatal(1,"tb_osd_overlay errors=%0d",errors);
        $finish;
    end
endmodule
