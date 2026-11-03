`timescale 1ns/1ps
module tb_edge_stabilize;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [7:0] gray=0;
    reg [1:0] phase=0;
    wire [7:0] raw_gray, raw_edge, stable_gray, stable_edge;
    integer raw_noise=0, stable_noise=0, stable_line=0;
    integer row, col;

    edge_gradient #(.WIDTH(8), .DENOISE_ENABLE(0), .EDGE_STABILIZE(0)) raw_dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_de(de),
        .I_gray(gray), .I_threshold(8'd10),
        .O_gray(raw_gray), .O_edge(raw_edge)
    );
    edge_gradient #(.WIDTH(8), .DENOISE_ENABLE(0), .EDGE_STABILIZE(1)) stable_dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_de(de),
        .I_gray(gray), .I_threshold(8'd10),
        .O_gray(stable_gray), .O_edge(stable_edge)
    );

    reg de_d1, de_d2;
    always @(posedge clk) if (rst_n) begin
        de_d1 <= de;
        de_d2 <= de_d1;
        #1;
        if (de_d2) begin
            if (phase == 1) begin
                if (raw_edge == 8'hff) raw_noise=raw_noise+1;
                if (stable_edge == 8'hff) stable_noise=stable_noise+1;
            end else if (phase == 2 && stable_edge == 8'hff)
                stable_line=stable_line+1;
        end
    end

    task put;
        input v,d;
        input [7:0] g;
        begin @(negedge clk); vs=v; de=d; gray=g; end
    endtask
    task start_frame;
        begin put(1,0,0); put(0,0,0); end
    endtask

    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        start_frame(); phase=1;
        for (row=0; row<4; row=row+1) begin
            for (col=0; col<8; col=col+1)
                put(0,1,(row==1 && col==3) ? 8'd45 : 8'd40);
            put(0,0,0); put(0,0,0);
        end
        repeat(3) put(0,0,0);
        if (raw_noise != 1 || stable_noise != 0)
            $fatal(1,"isolated weak pixel raw=%0d stable=%0d",raw_noise,stable_noise);

        phase=0; start_frame(); phase=2;
        for (row=0; row<4; row=row+1) begin
            for (col=0; col<8; col=col+1)
                put(0,1,(row==1 && col>=3 && col<=5) ? 8'd50 : 8'd40);
            put(0,0,0); put(0,0,0);
        end
        repeat(3) put(0,0,0);
        if (stable_line < 2)
            $fatal(1,"connected fine stroke lost, count=%0d",stable_line);
        $display("PASS tb_edge_stabilize isolated=%0d/%0d fine_stroke=%0d",
                 raw_noise,stable_noise,stable_line);
        $finish;
    end
endmodule
