`timescale 1ns/1ps
module tb_edge_denoise;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [7:0] gray=0;
    reg [1:0] phase=0;
    wire [7:0] raw_gray, raw_edge, filtered_gray, filtered_edge;
    integer raw_noise_count=0, filtered_noise_count=0, filtered_step_count=0;
    integer row, col;
    reg [7:0] gray_d1, gray_d2;
    reg de_d1, de_d2;

    edge_gradient #(.WIDTH(8), .DENOISE_ENABLE(0), .EDGE_STABILIZE(0)) raw_dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_de(de),
        .I_gray(gray), .I_threshold(8'd100),
        .O_gray(raw_gray), .O_edge(raw_edge)
    );
    edge_gradient #(.WIDTH(8), .DENOISE_ENABLE(1), .EDGE_STABILIZE(0)) filtered_dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_de(de),
        .I_gray(gray), .I_threshold(8'd100),
        .O_gray(filtered_gray), .O_edge(filtered_edge)
    );

    always @(posedge clk) if (rst_n) begin
        gray_d1 <= gray;
        gray_d2 <= gray_d1;
        de_d1 <= de;
        de_d2 <= de_d1;
        #1;
        if (de_d2 && (raw_gray !== gray_d2 || filtered_gray !== gray_d2))
            $fatal(1,"GRAY/BIN path changed: raw=%0d filtered=%0d expected=%0d",
                   raw_gray,filtered_gray,gray_d2);
        if (phase == 1) begin
            if (raw_edge == 8'hff) raw_noise_count=raw_noise_count+1;
            if (filtered_edge == 8'hff) filtered_noise_count=filtered_noise_count+1;
        end
        if (phase == 2 && filtered_edge == 8'hff)
            filtered_step_count=filtered_step_count+1;
    end

    task put;
        input v,d;
        input [7:0] g;
        begin @(negedge clk); vs=v; de=d; gray=g; end
    endtask
    task start_frame;
        begin put(1,0,0); put(0,0,0); end
    endtask
    task flush_line;
        begin put(0,0,0); put(0,0,0); end
    endtask

    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        start_frame();
        phase=1;
        for (row=0; row<4; row=row+1) begin
            for (col=0; col<8; col=col+1)
                put(0,1,(row==1 && col==3) ? 8'd200 : 8'd40);
            flush_line();
        end
        repeat(4) put(0,0,0);
        if (raw_noise_count == 0 || filtered_noise_count != 0)
            $fatal(1,"single-pixel noise raw=%0d filtered=%0d",
                   raw_noise_count,filtered_noise_count);

        phase=0;
        start_frame();
        phase=2;
        for (row=0; row<4; row=row+1) begin
            for (col=0; col<8; col=col+1)
                put(0,1,(col>=4) ? 8'd255 : 8'd40);
            flush_line();
        end
        repeat(4) put(0,0,0);
        if (filtered_step_count == 0)
            $fatal(1,"real edge was lost");
        $display("PASS tb_edge_denoise noise=%0d/%0d edge=%0d",
                 raw_noise_count,filtered_noise_count,filtered_step_count);
        $finish;
    end
endmodule
