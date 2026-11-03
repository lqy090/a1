`timescale 1ns/1ps
module tb_mode_box_key;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, key_n=1, vs=0;
    wire [2:0] mode;
    wire box_enable;
    integer errors=0, k;
    mode_key_ctrl #(.DEBOUNCE_CYCLES(3),.DOUBLE_CLICK_CYCLES(20)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_key_n(key_n),.I_vsync(vs),
        .O_mode(mode),.O_box_enable(box_enable)
    );
    task wait_clocks;
        input integer n;
        integer i;
        begin for(i=0;i<n;i=i+1) @(negedge clk); end
    endtask
    task frame_start;
        begin vs=1;wait_clocks(2);vs=0;wait_clocks(2);end
    endtask
    task click;
        begin key_n=0;wait_clocks(6);key_n=1;wait_clocks(6);end
    endtask
    initial begin
        wait_clocks(3);rst_n=1;
        if(mode!==0 || box_enable!==0) begin
            $display("FAIL reset mode/box");errors=errors+1;
        end
        key_n=0;wait_clocks(1);key_n=1;wait_clocks(30);
        frame_start();
        if(mode!==0 || box_enable!==0) begin
            $display("FAIL bounce mode/box");errors=errors+1;
        end
        click();
        frame_start();
        if(mode!==0) begin $display("FAIL early single");errors=errors+1;end
        wait_clocks(25);
        if(mode!==0) begin $display("FAIL mode before frame");errors=errors+1;end
        frame_start();
        if(mode!==1 || box_enable!==0) begin
            $display("FAIL single mode=%0d box=%b",mode,box_enable);
            errors=errors+1;
        end
        click();wait_clocks(2);click();
        if(mode!==1 || box_enable!==0) begin
            $display("FAIL double before frame");errors=errors+1;
        end
        frame_start();
        if(mode!==1 || box_enable!==1) begin
            $display("FAIL double on mode=%0d box=%b",mode,box_enable);
            errors=errors+1;
        end
        wait_clocks(25);frame_start();
        if(mode!==1 || box_enable!==1) begin
            $display("FAIL double changed mode later");errors=errors+1;
        end
        click();wait_clocks(2);click();frame_start();
        if(mode!==1 || box_enable!==0) begin
            $display("FAIL double off mode=%0d box=%b",mode,box_enable);
            errors=errors+1;
        end
        for(k=2;k<=6;k=k+1) begin
            click();wait_clocks(25);frame_start();
            if(mode!==k%6 || box_enable!==0) begin
                $display("FAIL mode cycle k=%0d mode=%0d box=%b",k,mode,box_enable);
                errors=errors+1;
            end
        end
        if(errors==0) $display("PASS tb_mode_box_key");
        else $fatal(1,"tb_mode_box_key errors=%0d",errors);
        $finish;
    end
endmodule
