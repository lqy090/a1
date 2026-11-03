`timescale 1ns/1ps
module tb_diag_key_ctrl;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, key_n=1, vs=0;
    wire mask, gamma_enable;
    integer errors=0;
    diag_key_ctrl #(.DEBOUNCE_CYCLES(3)) dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_key_n(key_n),
        .I_vsync(vs),.O_mask_enable(mask),.O_gamma_enable(gamma_enable)
    );
    task frame;
        begin
            @(negedge clk); vs=1;
            @(negedge clk); vs=0;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        @(negedge clk); key_n=0;
        repeat(7) @(negedge clk);
        if (mask!==0 || gamma_enable!==0) begin $display("FAIL changed before frame"); errors=errors+1; end
        frame(); #1;
        if (mask!==1 || gamma_enable!==0) begin $display("FAIL first press"); errors=errors+1; end
        repeat(9) @(negedge clk);
        frame(); #1;
        if (mask!==1 || gamma_enable!==0) begin $display("FAIL long press retriggered"); errors=errors+1; end
        @(negedge clk); key_n=1;
        repeat(7) @(negedge clk);
        @(negedge clk); key_n=0;
        repeat(7) @(negedge clk);
        frame(); #1;
        if (mask!==0 || gamma_enable!==0) begin $display("FAIL second press"); errors=errors+1; end
        @(negedge clk); key_n=1;
        repeat(7) @(negedge clk);
        @(negedge clk); key_n=0;
        repeat(7) @(negedge clk);
        frame(); #1;
        if (mask!==1 || gamma_enable!==0) begin $display("FAIL third press"); errors=errors+1; end
        if (errors==0) $display("PASS tb_diag_key_ctrl");
        else $fatal(1,"tb_diag_key_ctrl errors=%0d",errors);
        $finish;
    end
endmodule
