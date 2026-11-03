`timescale 1ns/1ps
module tb_auto_exposure_ctrl;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,vs=0,de=0,en=0;
    reg [23:0] rgb=0;
    wire [15:0] exposure;
    wire boost,epoch;
    integer x,y,i;
    auto_exposure_ctrl #(.WIDTH(32),.HEIGHT(32),
        .HIGHLIGHT_TILES(3),.LOW_HIGHLIGHT_TILES(0),
        .DARK_TILES(3),.LOW_DARK_TILES(1),.UPDATE_FRAMES(2)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_de(de),
        .I_rgb(rgb),.I_enable(en),.O_exposure(exposure),
        .O_gain_boost(boost),.O_update_toggle(epoch));
    task frame;
        input [23:0] value;
        begin
            @(negedge clk);vs=1;de=0;
            repeat(3) @(negedge clk);vs=0;
            for(y=0;y<32;y=y+1) begin
                for(x=0;x<32;x=x+1) begin
                    de=1;rgb=value;
                    @(negedge clk);
                end
                de=0;repeat(2) @(negedge clk);
            end
            de=0;repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        if (exposure!==1990 || boost!==0) $fatal(1,"wrong reset baseline");
        en=1;
        for(i=0;i<4;i=i+1) frame(24'hffffff);
        if (exposure>=1990) $fatal(1,"bright scene must reduce exposure");
        for(i=0;i<6;i=i+1) frame(24'h808080);
        if (exposure!==1990 || boost!==0) $fatal(1,"midtone must restore baseline");
        for(i=0;i<4;i=i+1) frame(24'h101010);
        if (boost!==1) $fatal(1,"very dark scene may request bounded gain");
        en=0;repeat(4) @(negedge clk);
        if (exposure!==1990 || boost!==0) $fatal(1,"AUTO OFF must restore manual baseline");
        $display("PASS tb_auto_exposure_ctrl");$finish;
    end
endmodule
