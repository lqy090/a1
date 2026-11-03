`timescale 1ns/1ps
module tb_p3_osd;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vs=0, hs=0, de=0;
    reg [2:0] mode=0;
    reg [2:0] brightness_level=3;
    reg brightness_up=1;
    reg box_enable=0;
    wire ovs,ohs,ode, lvs,lhs,lde, svs,shs,sde;
    wire [23:0] orgb,lrgb,srgb;
    integer x=0,y=0,errors=0,blue_count=0,red_count=0,transparent_count=0;
    reg old_de=0, old_vs=0;
    integer line,p,dim_level;

    osd_overlay old_text_stage(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vs),.I_hsync(hs),.I_de(de),
        .I_data(24'h112233),.O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(orgb)
    );
    logo_overlay logo(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(ovs),.I_hsync(ohs),.I_de(ode),
        .I_rgb(orgb),.O_vsync(lvs),.O_hsync(lhs),.O_de(lde),.O_rgb(lrgb)
    );
    mode_status_overlay status(
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(lvs),.I_hsync(lhs),.I_de(lde),
        .I_rgb(lrgb),.I_mode(mode),.I_gamma_enable(1'b0),.I_mask_enable(1'b0),
        .I_box_enable(box_enable),.I_auto_enable(1'b0),
        .I_brightness_level(brightness_level),.I_brightness_up(brightness_up),
        .O_vsync(svs),.O_hsync(shs),.O_de(sde),.O_rgb(srgb)
    );

    always @(posedge clk) if (rst_n) begin
        #1;
        if (svs && !old_vs) begin x=0; y=0; end
        else if (old_de && !sde) begin x=0; y=y+1; end
        if (sde) begin
            if (x == 0 && y == 0 && srgb !== 24'h112233) begin
                $display("FAIL passthrough %h",srgb); errors=errors+1;
            end
            if (x == 16 && y == 16 && srgb !== 24'h112233) begin
                $display("FAIL old text border remains %h",srgb); errors=errors+1;
            end
            if (mode == 3'd0 && x == 176 && y == 28 && srgb !== 24'h4eb5ff) begin
                $display("FAIL status border %h",srgb); errors=errors+1;
            end
            if (mode == 3'd0 && x == 192 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL status text %h",srgb); errors=errors+1;
            end
            if (mode == 3'd4 && x == 319 && y == 28 && srgb !== 24'h9bdc80) begin
                $display("FAIL CARTOON panel border %h",srgb); errors=errors+1;
            end
            if (mode == 3'd4 && x == 288 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL CARTOON final N %h",srgb); errors=errors+1;
            end
            if (mode == 3'd5 && x == 176 && y == 28 && srgb !== 24'hd59cff) begin
                $display("FAIL INVERT panel border %h",srgb); errors=errors+1;
            end
            if (mode == 3'd5 && x == 224 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL INVERT V glyph %h",srgb); errors=errors+1;
            end
            if (mode == 3'd5 && x == 272 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL INVERT final T %h",srgb); errors=errors+1;
            end
            if (mode == 3'd5 && x == 288 && y == 46 && srgb !== 24'h102430) begin
                $display("FAIL INVERT trailing space %h",srgb); errors=errors+1;
            end
            if (x == 328 && y == 28 && srgb !== 24'hf0d252) begin
                $display("FAIL brightness panel border %h",srgb); errors=errors+1;
            end
            if (x == 336 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL brightness B label %h",srgb); errors=errors+1;
            end
            if (x == 416 && y == 28 &&
                srgb !== (box_enable ? 24'h40d070 : 24'hb8c2cc)) begin
                $display("FAIL box status border=%h enable=%b",srgb,box_enable);
                errors=errors+1;
            end
            if (x == 424 && y == 46 && srgb !== 24'hffffff) begin
                $display("FAIL DETECT label %h",srgb);errors=errors+1;
            end
            if (x == 568 && y == 46 &&
                srgb !== (box_enable ? 24'h102430 : 24'hffffff)) begin
                $display("FAIL DETECT ON/OFF ending %h",srgb);errors=errors+1;
            end
            if (brightness_level == 3'd5 && x == 368 && y == 46 &&
                srgb !== 24'h102430) begin
                $display("FAIL B+2 digit %h",srgb); errors=errors+1;
            end
            if (brightness_level == 3'd6 && x == 368 && y == 46 &&
                srgb !== 24'hffffff) begin
                $display("FAIL B+3 digit %h",srgb); errors=errors+1;
            end
            if (brightness_level < 3'd3 && x == 352 && y == 52 &&
                srgb !== 24'hffffff) begin
                $display("FAIL negative sign level=%0d rgb=%h",brightness_level,srgb);
                errors=errors+1;
            end
            if (brightness_level == 3'd2 && x == 372 && y == 46 &&
                srgb !== 24'hffffff) begin
                $display("FAIL B-1 digit %h",srgb); errors=errors+1;
            end
            if (brightness_level == 3'd1 && x == 370 && y == 46 &&
                srgb !== 24'hffffff) begin
                $display("FAIL B-2 digit %h",srgb); errors=errors+1;
            end
            if (brightness_level == 3'd0 && x == 368 && y == 46 &&
                srgb !== 24'hffffff) begin
                $display("FAIL B-3 digit %h",srgb); errors=errors+1;
            end
            if (x == 1092 && y == 12 && srgb !== 24'h112233) begin
                $display("FAIL upper-right old logo remains %h",srgb); errors=errors+1;
            end
            if (x >= 24 && x < 152 && y >= 20 && y < 104) begin
                if (srgb == 24'h1c427c) blue_count=blue_count+1;
                if (srgb == 24'hf31829) red_count=red_count+1;
                if (srgb == 24'h112233) transparent_count=transparent_count+1;
            end
            x=x+1;
        end
        old_de=sde; old_vs=svs;
    end

    initial begin
        repeat(3) @(negedge clk);
        rst_n=1;
        vs=1;
        @(negedge clk); vs=0;
        for(line=0;line<110;line=line+1) begin
            for(p=0;p<1280;p=p+1) begin
                de=1; hs=1; @(negedge clk);
            end
            de=0; hs=0; repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        mode=3'd4; brightness_level=4; brightness_up=0; vs=1;
        @(negedge clk); vs=0;
        for(line=0;line<65;line=line+1) begin
            for(p=0;p<420;p=p+1) begin
                de=1; hs=1; @(negedge clk);
            end
            de=0; hs=0; repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        brightness_level=3'd5;
        repeat(5) @(negedge clk);
        vs=1;
        @(negedge clk);vs=0;
        for(line=0;line<50;line=line+1) begin
            for(p=0;p<420;p=p+1) begin de=1;hs=1;@(negedge clk);end
            de=0;hs=0;repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        for(dim_level=2;dim_level>=0;dim_level=dim_level-1) begin
            brightness_level=dim_level[2:0];
            repeat(5) @(negedge clk);
            vs=1;
            @(negedge clk);vs=0;
            for(line=0;line<60;line=line+1) begin
                for(p=0;p<420;p=p+1) begin de=1;hs=1;@(negedge clk);end
                de=0;hs=0;repeat(4) @(negedge clk);
            end
            repeat(5) @(negedge clk);
        end
        brightness_level=3'd6;
        repeat(5) @(negedge clk);
        vs=1;
        @(negedge clk);vs=0;
        for(line=0;line<50;line=line+1) begin
            for(p=0;p<420;p=p+1) begin de=1;hs=1;@(negedge clk);end
            de=0;hs=0;repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        mode=3'd5;
        vs=1;
        @(negedge clk); vs=0;
        for(line=0;line<60;line=line+1) begin
            for(p=0;p<420;p=p+1) begin de=1;hs=1;@(negedge clk);end
            de=0;hs=0;repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        box_enable=1;
        vs=1;
        @(negedge clk); vs=0;
        for(line=0;line<50;line=line+1) begin
            for(p=0;p<600;p=p+1) begin de=1;hs=1;@(negedge clk);end
            de=0;hs=0;repeat(4) @(negedge clk);
        end
        repeat(5) @(negedge clk);
        if (blue_count == 0 || red_count == 0 || transparent_count == 0) begin
            $display("FAIL logo colours/alpha blue=%0d red=%0d transparent=%0d",blue_count,red_count,transparent_count);
            errors=errors+1;
        end
        if (errors == 0) $display("PASS tb_p3_osd blue=%0d red=%0d transparent=%0d",blue_count,red_count,transparent_count);
        else $fatal(1,"tb_p3_osd errors=%0d",errors);
        $finish;
    end
endmodule
