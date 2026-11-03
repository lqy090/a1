`timescale 1ns/1ps
module tb_brightness_key_ctrl;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, key_n=1;
    wire [2:0] level;
    wire direction_up;
    wire [15:0] gain_target;
    wire ae_req;
    wire [15:0] exposure, applied_gain;
    integer errors=0;

    brightness_key_ctrl #(.DEBOUNCE_CYCLES(3),
                          .DOUBLE_CLICK_CYCLES(30)) dut (
        .I_clk(clk),.I_rst_n(rst_n),.I_key_n(key_n),
        .O_level(level),.O_direction_up(direction_up),
        .O_gain_target(gain_target)
    );
    ae_set ae_dut (
        .I_clk(clk),.I_rst(~rst_n),.I_btn(4'b1111),
        .I_gain_target(gain_target),.I_auto_enable(1'b0),.I_auto_update_toggle(1'b0),.I_auto_exposure(16'd1990),.I_auto_gain_boost(1'b0),
        .I_cam_cfg_done(1'b1),.I_ae_cfg_done(1'b1),
        .O_ae_req(ae_req),.O_ae(exposure),.O_ag(applied_gain)
    );

    task wait_cycles;
        input integer n;
        integer i;
        begin for(i=0;i<n;i=i+1) @(negedge clk); end
    endtask
    task tap;
        begin
            key_n=0; wait_cycles(7);
            key_n=1; wait_cycles(7);
        end
    endtask
    task check;
        input [2:0] expected_level;
        input expected_direction;
        input [15:0] expected_gain;
        begin
            wait_cycles(4);
            if (level !== expected_level || direction_up !== expected_direction ||
                gain_target !== expected_gain || applied_gain !== expected_gain ||
                exposure !== 16'd1990) begin
                $display("FAIL level=%0d dir=%b gain=%0d applied=%0d exposure=%0d expected=%0d/%b/%0d",
                         level,direction_up,gain_target,applied_gain,exposure,
                         expected_level,expected_direction,expected_gain);
                errors=errors+1;
            end
        end
    endtask

    initial begin
        wait_cycles(4); rst_n=1;
        check(3'd3,1'b1,16'd96);
        key_n=0; wait_cycles(1); key_n=1; wait_cycles(40);
        check(3'd3,1'b1,16'd96); // bounce ignored

        tap(); check(3'd3,1'b1,16'd96); // wait for possible second click
        wait_cycles(31); check(3'd4,1'b1,16'd104);
        tap(); wait_cycles(35); check(3'd5,1'b1,16'd104);
        tap(); wait_cycles(35); check(3'd6,1'b1,16'd104);
        tap(); wait_cycles(35); check(3'd6,1'b1,16'd104); // upper clamp

        tap(); tap(); wait_cycles(35);
        check(3'd6,1'b0,16'd104); // double click only reverses direction
        tap(); wait_cycles(35); check(3'd5,1'b0,16'd104);
        tap(); wait_cycles(35); check(3'd4,1'b0,16'd104);
        tap(); wait_cycles(35); check(3'd3,1'b0,16'd96);
        tap(); wait_cycles(35); check(3'd2,1'b0,16'd96);
        tap(); wait_cycles(35); check(3'd1,1'b0,16'd96);
        tap(); wait_cycles(35); check(3'd0,1'b0,16'd96);
        tap(); wait_cycles(35); check(3'd0,1'b0,16'd96); // lower clamp
        tap(); tap(); wait_cycles(35);
        check(3'd0,1'b1,16'd96);
        tap(); wait_cycles(35); check(3'd1,1'b1,16'd96);
        tap(); wait_cycles(35); check(3'd2,1'b1,16'd96);
        tap(); wait_cycles(35); check(3'd3,1'b1,16'd96);

        if (errors==0) $display("PASS tb_brightness_key_ctrl");
        else $fatal(1,"tb_brightness_key_ctrl errors=%0d",errors);
        $finish;
    end
endmodule
