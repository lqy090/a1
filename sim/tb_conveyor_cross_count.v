`timescale 1ns/1ps
module tb_conveyor_cross_count;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, key_n=1, vs=0, detect=1, valid=0, shape_valid=0;
    reg [2:0] color=0, shape_color=0, shape=0;
    reg [10:0] x0=0,x1=0,y0=300,y1=340;
    wire enabled;
    wire [127:0] totals;
    integer errors=0;
    integer c,s,idx;
    conveyor_cross_count #(.DEBOUNCE_CYCLES(3),.DOUBLE_CLICK_FRAMES(4),
                           .LINE_X(800),.HYST(20),
                           .BELT_Y0(100),.BELT_Y1(600)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_key_n(key_n),.I_vsync(vs),
        .I_detect_enable(detect),.I_target_valid(valid),.I_color(color),
        .I_x0(x0),.I_y0(y0),.I_x1(x1),.I_y1(y1),
        .I_shape_valid(shape_valid),.I_shape_color(shape_color),.I_shape(shape),
        .O_enable(enabled),.O_counts(totals)
    );
    task frame;
        begin
            @(negedge clk); vs=1;
            @(negedge clk); vs=0;
            repeat(3) @(negedge clk);
        end
    endtask
    task tap;
        begin
            @(negedge clk); key_n=0;
            repeat(7) @(negedge clk);
            key_n=1;
            repeat(7) @(negedge clk);
        end
    endtask
    task press;
        begin
            tap;
            repeat(6) frame;
        end
    endtask
    task double_press;
        begin
            tap;
            frame;
            tap;
            frame;
        end
    endtask
    task target;
        input [10:0] center_x;
        input [2:0] c,s;
        begin
            valid=1; x0=center_x-20; x1=center_x+20;
            color=c; shape_color=c; shape=s; shape_valid=1;
            frame;
        end
    endtask
    task gap;
        begin valid=0; shape_valid=0; frame; frame; frame; frame; end
    endtask
    task check_count;
        input integer index;
        input [15:0] expected;
        begin
            if(totals[index*16 +: 16] !== expected) begin
                $display("bin %0d actual %h expected %h",index,
                         totals[index*16 +: 16],expected); errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        target(680,1,1); target(700,1,1); target(760,1,1);
        target(830,1,1); check_count(0,0); // KEY2 is off at boot
        gap;
        press;
        if(enabled !== 1) errors=errors+1;
        target(680,1,1); target(700,1,1); target(760,1,1);
        target(830,1,1); check_count(0,16'h0001);
        target(790,1,1); target(830,1,1); check_count(0,16'h0001);
        gap;
        target(680,2,4); target(700,2,4); target(760,2,4);
        target(830,2,4); check_count(3,16'h0001); // blue triangle
        gap;
        press;
        if(enabled !== 0) errors=errors+1;
        target(680,1,2); target(700,1,2); target(760,1,2);
        target(830,1,2); check_count(0,16'h0001);
        gap;
        press; detect=0;
        target(680,3,1); target(700,3,1); target(760,3,1);
        target(830,3,1); check_count(4,0);
        gap; detect=1;
        // No counting of a target first seen beyond the gate.
        target(830,4,2); target(850,4,2); check_count(6,0);
        gap;
        target(680,4,2); target(700,4,2); target(760,4,2);
        target(830,4,2); check_count(6,16'h0001);
        gap;
        // Exercise all eight bins. Alternating square/rectangle outcomes
        // must still be stable as the merged RECTANGLE category.
        for (c=1; c<=4; c=c+1) begin
            for (s=0; s<2; s=s+1) begin
                idx=(c-1)*2+s;
                target(680,c,s==0 ? 1 : 4);
                target(700,c,s==0 ? 2 : 4);
                target(760,c,s==0 ? 1 : 4);
                target(830,c,s==0 ? 2 : 4);
                check_count(idx, idx==0 || idx==3 || idx==6 ? 16'h0002 : 16'h0001);
                gap;
            end
        end
        dut.counts[0]=16'h0999;
        target(680,1,1); target(700,1,1);
        target(760,1,1); target(830,1,1);
        check_count(0,16'h0999); // three-digit display saturates
        gap;
        double_press;
        if(enabled !== 1) errors=errors+1; // double click does not toggle
        for (idx=0;idx<8;idx=idx+1) check_count(idx,0);
        target(680,1,1); target(700,1,1);
        target(760,1,1); target(830,1,1);
        check_count(0,16'h0001); // counting re-arms cleanly after reset
        gap;
        press;
        if(enabled !== 0) errors=errors+1;
        check_count(0,16'h0001); // single click keeps count history
        double_press;
        if(enabled !== 0) errors=errors+1;
        for (idx=0;idx<8;idx=idx+1) check_count(idx,0);
        @(negedge clk); key_n=0;
        @(negedge clk); key_n=1; // shorter than debounce interval
        repeat(8) @(negedge clk);
        repeat(6) frame;
        if(enabled !== 0) errors=errors+1;
        tap;
        frame;
        if(enabled !== 0) errors=errors+1; // first click is still pending
        repeat(5) frame;
        if(enabled !== 1) errors=errors+1;
        gap;
        target(680,1,1); target(700,1,1);
        double_press; // clear an in-flight upstream track
        target(830,1,1);
        check_count(0,0); // old crossing state must not count after clear
        if(errors==0) $display("PASS tb_conveyor_cross_count");
        else $fatal(1,"tb_conveyor_cross_count errors=%0d",errors);
        $finish;
    end
endmodule
