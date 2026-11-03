`timescale 1ns/1ps
module tb_motion_key_ctrl;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,key_n=1,vsync=0;
    wire motion,auto_on;
    motion_key_ctrl #(.DEBOUNCE_CYCLES(3),.DOUBLE_CLICK_CYCLES(20)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_key_n(key_n),
        .I_vsync(vsync),.O_enable(motion),.O_auto_enable(auto_on));
    task frame_edge;
        begin
            @(negedge clk); vsync=1;
            repeat(3) @(negedge clk); vsync=0;
        end
    endtask
    task tap;
        begin
            @(negedge clk);key_n=0;
            repeat(7) @(negedge clk);key_n=1;
            repeat(7) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        frame_edge();
        if (motion!==0 || auto_on!==0) $fatal(1,"both modes must start OFF");
        tap(); frame_edge();
        if (motion!==0 || auto_on!==0) $fatal(1,"single click committed too early");
        repeat(22) @(negedge clk);frame_edge();
        if (motion!==1 || auto_on!==0) $fatal(1,"single click failed");
        tap();tap();frame_edge();
        if (motion!==1 || auto_on!==1) $fatal(1,"double click must toggle auto only");
        tap();tap();frame_edge();
        if (motion!==1 || auto_on!==0) $fatal(1,"second double click must disable auto");
        tap();repeat(22) @(negedge clk);frame_edge();
        if (motion!==0 || auto_on!==0) $fatal(1,"single click must disable motion");
        $display("PASS tb_motion_key_ctrl");$finish;
    end
endmodule
