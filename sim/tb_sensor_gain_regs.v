`timescale 1ns/1ps
module tb_sensor_gain_regs;
    reg clk=0;
    always #5 clk=~clk;
    reg [8:0] idx;
    wire [31:0] data;
    wire [8:0] size;
    reg [6:0] gain_index=0;
    wire [15:0] gain_value;
    integer errors=0;
    uics500reg_720p60 dut(.REG_INDEX(idx), .REG_DATA(data), .REG_SIZE(size));
    SC500GainTbl gain_dut(.I_clk(clk), .I_rstn(1'b1), .I(gain_index), .O(gain_value));
    task check;
        input [8:0] address;
        input [23:0] expected;
        begin
            idx=address; #1;
            if (data[23:0] !== expected) begin
                $display("FAIL idx=%0d got=%h expected=%h",idx,data[23:0],expected);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        if(size!==9'd119) begin $display("FAIL size=%0d",size); errors=errors+1; end
        check(9'd28,24'h320e03);
        check(9'd29,24'h320fe8);
        check(9'd94,24'h3e0000);
        check(9'd95,24'h3e017c);
        check(9'd96,24'h3e0260);
        check(9'd112,24'h3e030b);
        check(9'd113,24'h3e0600);
        check(9'd114,24'h3e0780);
        check(9'd115,24'h3e080f);
        check(9'd116,24'h3e0930);
        check(9'd117,24'h010001);
        check(9'd118,24'h302d00);
        @(negedge clk); gain_index=7'd76;
        @(negedge clk); #1;
        if (gain_value!==16'h0f2c) begin
            $display("FAIL gain index 76 got=%h expected=0f2c",gain_value);
            errors=errors+1;
        end
        @(negedge clk); gain_index=7'd80;
        @(negedge clk); #1;
        if (gain_value!==16'h0f30) begin
            $display("FAIL gain index 80 got=%h expected=0f30",gain_value);
            errors=errors+1;
        end
        @(negedge clk); gain_index=7'd88;
        @(negedge clk); #1;
        if (gain_value!==16'h0f38) begin
            $display("FAIL gain index 88 got=%h expected=0f38",gain_value);
            errors=errors+1;
        end
        if(errors==0) $display("PASS tb_sensor_gain_regs");
        else $fatal(1,"tb_sensor_gain_regs errors=%0d",errors);
        $finish;
    end
endmodule
