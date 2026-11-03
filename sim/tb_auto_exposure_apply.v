`timescale 1ns/1ps
module tb_auto_exposure_apply;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,auto_on=0,toggle=0,boost=0;
    reg [15:0] target=1990,manual_gain=96;
    wire req;
    wire [15:0] exposure,gain;
    ae_set dut(.I_clk(clk),.I_rst(rst),.I_btn(4'b1111),
        .I_gain_target(manual_gain),.I_auto_enable(auto_on),
        .I_auto_update_toggle(toggle),.I_auto_exposure(target),
        .I_auto_gain_boost(boost),.I_ae_cfg_done(1'b1),
        .I_cam_cfg_done(1'b1),.O_ae_req(req),.O_ae(exposure),.O_ag(gain));
    task wait_apply;
        begin repeat(15) @(negedge clk); end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;
        wait_apply();
        if (exposure!==1990 || gain!==96) $fatal(1,"manual baseline");
        auto_on=1;target=1734;toggle=~toggle;
        wait_apply();
        if (exposure!==1734 || gain!==96) $fatal(1,"auto exposure not applied");
        target=1990;boost=1;toggle=~toggle;
        wait_apply();
        if (exposure!==1990 || gain!==104) $fatal(1,"bounded gain boost not applied");
        auto_on=0;wait_apply();
        if (exposure!==1990 || gain!==96) $fatal(1,"manual gain not restored");
        $display("PASS tb_auto_exposure_apply");$finish;
    end
endmodule
