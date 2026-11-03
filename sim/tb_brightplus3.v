`timescale 1ns/1ps
module tb_brightplus3;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [23:0] rgb=0;
    reg [2:0] level=3'd3;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer errors=0,i;
    reg [7:0] last_gray=0;
    reg [7:0] expected_dim;
    raw_tone_display dut(.I_clk(clk),.I_rst_n(rst_n),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_rgb(rgb),
        .I_brightness_level(level),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb));

    task begin_frame;
        input [2:0] selected_level;
        begin
            @(negedge clk);level=selected_level;
            repeat(5) @(negedge clk);
            vs=1;
            @(negedge clk);vs=0;
            repeat(5) @(negedge clk);
        end
    endtask
    task check_pixel;
        input [23:0] value;
        output [23:0] measured;
        begin
            @(negedge clk);rgb=value;de=1;hs=1;
            repeat(5) @(posedge clk);#1;
            measured=orgb;
            if(!ode || !ohs) begin
                $display("FAIL sync level=%0d rgb=%h de=%b hs=%b",level,value,ode,ohs);
                errors=errors+1;
            end
            @(negedge clk);de=0;hs=0;
            repeat(6) @(negedge clk);
        end
    endtask
    reg [23:0] observed;
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        for(i=3;i<=6;i=i+1) begin
            begin_frame(i[2:0]);
            check_pixel(24'h505050,observed);
            if(observed[23:16] != observed[15:8] ||
               observed[15:8] != observed[7:0] ||
               (i==3 && observed != 24'h757575) ||
               (i>3 && observed[7:0] <= last_gray)) begin
                $display("FAIL gray level=%0d rgb=%h last=%h",i,observed,last_gray);
                errors=errors+1;
            end
            last_gray=observed[7:0];
            check_pixel(24'h404080,observed);
            if(observed[23:16] != observed[15:8] ||
               observed[7:0] <= observed[23:16]) begin
                $display("FAIL color balance level=%0d rgb=%h",i,observed);
                errors=errors+1;
            end
            check_pixel(24'h000000,observed);
            if(observed != 24'h000000) begin
                $display("FAIL black level=%0d rgb=%h",i,observed);errors=errors+1;
            end
            check_pixel(24'hffffff,observed);
            if(observed != 24'hffffff) begin
                $display("FAIL white level=%0d rgb=%h",i,observed);errors=errors+1;
            end
        end
        // All negative levels must dim the same B0 pixel with a single,
        // spatially constant RGB factor; white is no longer held at 255.
        for(i=2;i>=0;i=i-1) begin
            begin_frame(i[2:0]);
            expected_dim = (i==2) ? 8'd93 : (i==1) ? 8'd75 : 8'd58;
            check_pixel(24'h505050,observed);
            if(observed !== {expected_dim,expected_dim,expected_dim}) begin
                $display("FAIL dim gray level=%0d rgb=%h expected=%h",i,observed,expected_dim);
                errors=errors+1;
            end
            check_pixel(24'h404080,observed);
            if(observed[23:16] !== observed[15:8] ||
               observed[7:0] < (observed[23:16] << 1) - 1 ||
               observed[7:0] > (observed[23:16] << 1) + 2) begin
                $display("FAIL dim colour ratio level=%0d rgb=%h",i,observed);
                errors=errors+1;
            end
            check_pixel(24'h000000,observed);
            if(observed !== 24'h000000) begin
                $display("FAIL dim black level=%0d rgb=%h",i,observed); errors=errors+1;
            end
            check_pixel(24'hffffff,observed);
            expected_dim = (i==2) ? 8'd204 : (i==1) ? 8'd165 : 8'd127;
            if(observed !== {expected_dim,expected_dim,expected_dim}) begin
                $display("FAIL dim white level=%0d rgb=%h expected=%h",i,observed,expected_dim);
                errors=errors+1;
            end
        end
        if(errors==0) $display("PASS tb_brightplus3");
        else $fatal(1,"tb_brightplus3 errors=%0d",errors);
        $finish;
    end
endmodule
