`timescale 1ns/1ps
module tb_track_coordinates;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0, valid=0;
    reg [2:0] color=0;
    reg enable=1;
    reg [10:0] x0=0,y0=0,x1=0,y1=0;
    wire ovs,ohs,ode;
    wire [23:0] orgb;
    integer errors=0;
    bbox_overlay dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(hs),
        .I_de(de),.I_rgb(24'h112233),.I_enable(enable),
        .I_valid(valid),.I_color(color),
        .I_x0(x0),.I_y0(y0),.I_x1(x1),.I_y1(y1),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_rgb(orgb)
    );
    task frame;
        begin
            @(negedge clk); vs=1;
            @(negedge clk); vs=0;
            repeat(16) @(negedge clk);
        end
    endtask
    task check;
        input want_valid, want_miss;
        input [2:0] want_color;
        input [10:0] want_cx,want_cy;
        begin
            if(dut.valid_q!==want_valid || dut.miss_q!==want_miss ||
               dut.color_q!==want_color || dut.cx_q!==want_cx ||
               dut.cy_q!==want_cy) begin
                $display("FAIL track v=%b miss=%b color=%0d center=(%0d,%0d)",
                    dut.valid_q,dut.miss_q,dut.color_q,dut.cx_q,dut.cy_q);
                errors=errors+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        valid=1; color=1; x0=10; x1=30; y0=8; y1=28;
        frame(); check(1,0,1,20,18);
        if(dut.x_bcd!==16'h0020 || dut.y_bcd!==16'h0018) errors=errors+1;
        if(dut.label_x0_q!==11'd10 || dut.label_y0_q!==11'd32) begin
            $display("FAIL top-edge RED label position (%0d,%0d)",dut.label_x0_q,dut.label_y0_q);
            errors=errors+1;
        end
        @(negedge clk); dut.x=10; dut.y=32; de=1;
        @(posedge clk); #1;
        if(orgb!==24'hff4040) begin
            $display("FAIL RED label background=%h",orgb); errors=errors+1;
        end
        @(negedge clk); dut.x=14; dut.y=35;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL RED glyph=%h",orgb); errors=errors+1;
        end
        @(negedge clk); de=0;

        // Same-colour movement updates without an extra confirmation frame.
        x0=30; x1=50; y0=8; y1=28;
        frame(); check(1,0,1,40,18);
        if(dut.label_x0_q!==11'd30 || dut.label_y0_q!==11'd32) begin
            $display("FAIL moving label position (%0d,%0d)",dut.label_x0_q,dut.label_y0_q);
            errors=errors+1;
        end

        // One implausible blue candidate cannot steal the red track.
        color=2; x0=600; x1=620; y0=400; y1=420;
        frame(); check(1,1,1,40,18);
        color=1; x0=34; x1=54; y0=8; y1=28;
        frame(); check(1,0,1,44,18);

        valid=0;
        frame(); check(1,1,1,44,18); // one-frame hold
        frame(); check(0,0,0,44,18); // then remove the marker
        @(negedge clk); dut.x=34; dut.y=32; de=1;
        @(posedge clk); #1;
        if(orgb!==24'h112233) begin
            $display("FAIL stale label after target loss=%h",orgb); errors=errors+1;
        end
        @(negedge clk); de=0;

        // A new target near the right/bottom of the 1280x720 image.
        valid=1; color=2; x0=1224; x1=1244; y0=557; y1=577;
        frame(); check(1,0,2,1234,567);
        if(dut.label_x0_q!==11'd1208 || dut.label_y0_q!==11'd533) begin
            $display("FAIL BLUE right-edge label position (%0d,%0d)",dut.label_x0_q,dut.label_y0_q);
            errors=errors+1;
        end
        if(dut.x_bcd!==16'h1234 || dut.y_bcd!==16'h0567) begin
            $display("FAIL BCD X=%h Y=%h",dut.x_bcd,dut.y_bcd);
            errors=errors+1;
        end

        @(negedge clk); dut.x=1208; dut.y=533; de=1;
        @(posedge clk); #1;
        if(orgb!==24'h40a0ff) begin
            $display("FAIL BLUE label background=%h",orgb); errors=errors+1;
        end
        @(negedge clk); dut.x=1212; dut.y=536;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL BLUE glyph=%h",orgb); errors=errors+1;
        end
        @(negedge clk); de=0;

        // The visible coordinate panel's X glyph begins at (1040,683).
        @(negedge clk); dut.x=1040; dut.y=683; de=1;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL coordinate glyph pixel=%h",orgb);
            errors=errors+1;
        end
        @(negedge clk); de=0;
        // Disabling the box must clear the track and pass the image through.
        enable=0;
        frame();
        if(dut.valid_q!==0 || dut.miss_q!==0) begin
            $display("FAIL box disabled state");errors=errors+1;
        end
        @(negedge clk); dut.x=1224; dut.y=557; de=1;
        @(posedge clk); #1;
        if(orgb!==24'h112233) begin
            $display("FAIL box disabled passthrough=%h",orgb);errors=errors+1;
        end
        @(negedge clk); de=0;

        // Re-enable with yellow, then green, checking the single-box colour.
        enable=1; valid=1; color=3;
        x0=10; x1=30; y0=8; y1=28;
        frame(); check(1,0,3,20,18);
        @(negedge clk); dut.x=10; dut.y=32; de=1;
        @(posedge clk); #1;
        if(orgb!==24'hffd23f) begin
            $display("FAIL YELLOW label background=%h",orgb);errors=errors+1;
        end
        @(negedge clk); dut.x=94; dut.y=35;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL YELLOW final W glyph=%h",orgb);errors=errors+1;
        end
        @(negedge clk); de=0;
        enable=0;frame();
        enable=1;color=4;frame();check(1,0,4,20,18);
        @(negedge clk); dut.x=10; dut.y=32; de=1;
        @(posedge clk); #1;
        if(orgb!==24'h40d070) begin
            $display("FAIL GREEN label background=%h",orgb);errors=errors+1;
        end
        @(negedge clk); dut.x=78; dut.y=35;
        @(posedge clk); #1;
        if(orgb!==24'hffffff) begin
            $display("FAIL GREEN final N glyph=%h",orgb);errors=errors+1;
        end
        @(negedge clk); de=0;
        if(errors==0) $display("PASS tb_track_coordinates");
        else $fatal(1,"tb_track_coordinates errors=%0d",errors);
        $finish;
    end
endmodule
