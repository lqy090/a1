`timescale 1ns/1ps
module tb_luma_auto_threshold;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [7:0] gray=0;
    wire [7:0] bin_level, edge_level;
    integer k;
    luma_auto_threshold #(
        .X_START(0), .X_END(4), .Y_START(0), .Y_END(2),
        .X_MASK(0), .Y_MASK(0),
        .EXPECTED_SAMPLES(8), .SAMPLE_SHIFT(3)
    ) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_de(de),
        .I_gray(gray), .O_bin_threshold(bin_level),
        .O_edge_threshold(edge_level)
    );
    task put;
        input v,d;
        input [7:0] g;
        begin
            @(negedge clk); vs=v; de=d; gray=g;
            @(posedge clk); #1;
        end
    endtask
    task check;
        input [7:0] b,e;
        begin
            if (bin_level !== b || edge_level !== e)
                $fatal(1,"thresholds %0d/%0d expected %0d/%0d",bin_level,edge_level,b,e);
        end
    endtask
    task full_frame;
        input [7:0] g;
        begin
            for(k=0;k<2;k=k+1) begin
                put(0,1,g); put(0,1,g); put(0,1,g); put(0,1,g);
                put(0,0,0);
            end
            put(1,0,0); put(0,0,0);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        check(40,8);
        put(1,0,0); put(0,0,0);
        full_frame(30);  check(23,8);  // First change only records the candidate.
        full_frame(30);  check(23,7);  // Confirmed; at most one step/frame.
        full_frame(30);  check(23,6);
        full_frame(160); check(120,6);
        full_frame(160); check(120,7);
        full_frame(160); check(120,8);
        full_frame(160); check(120,9);
        full_frame(160); check(120,10);
        full_frame(30);  check(23,10); // Single-frame fluctuation is ignored.
        full_frame(160); check(120,10);
        // Missing a line: retain the last valid thresholds.
        for(k=0;k<4;k=k+1) put(0,1,0);
        put(0,0,0); put(1,0,0); check(120,10);
        $display("PASS tb_luma_auto_threshold");
        $finish;
    end
endmodule
