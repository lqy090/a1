`timescale 1ns/1ps
module tb_motion_components;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, vsync=0, enable=1;
    wire [4:0] count;
    wire [415:0] boxes;
    wire overflow;
    integer pix[0:111];
    integer seen[0:111];
    integer qx[0:111], qy[0:111];
    integer ex0[0:15],ex1[0:15],ey0[0:15],ey1[0:15];
    integer matched[0:15];
    integer t,x,y,i,j,k,n,head,tail,cx,cy,nx,ny,area,
            lo_x,hi_x,lo_y,hi_y,expected,found,seed;
    reg [25:0] box_data;
    three_frame_motion_serial #(.WIDTH(224),.HEIGHT(128),
        .GRID_W(14),.GRID_H(8),.GLOBAL_CHANGE_LIMIT(112)) dut (
        .I_clk(clk),.I_rst_n(rst_n),.I_vsync(vsync),.I_de(1'b0),
        .I_rgb(24'd0),.I_enable(enable),.I_brightness_level(3'd5),
        .I_exposure_epoch(1'b0),.I_frame_id(8'd0),.I_frame_id_valid(1'b1),
        .O_box_count(count),.O_boxes(boxes),.O_overflow(overflow));
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1;
        repeat(5) @(negedge clk);
        seed=32'h1234567;
        for (t=0;t<500;t=t+1) begin
            // Connected bands and sparse islands exercise both label unions
            // and multiple independent variable-size bounding boxes.
            for (i=0;i<112;i=i+1) begin
                seed=(seed*1103515245+12345) & 32'h7fffffff;
                pix[i]=((seed>>16)%100)<(t%4==0 ? 40 :
                                              (t%3==0 ? 30 : 19));
                seen[i]=0;
                dut.motion_mask[i]=pix[i] ? 2'b11 : 2'b00;
            end
            expected=0;
            for (y=0;y<8;y=y+1)
                for (x=0;x<14;x=x+1)
                    if (pix[y*14+x] && !seen[y*14+x]) begin
                        head=0; tail=1;
                        qx[0]=x; qy[0]=y; seen[y*14+x]=1;
                        lo_x=x;hi_x=x;lo_y=y;hi_y=y;
                        while (head<tail) begin
                            cx=qx[head];cy=qy[head];head=head+1;
                            if (cx<lo_x) lo_x=cx;
                            if (cx>hi_x) hi_x=cx;
                            if (cy<lo_y) lo_y=cy;
                            if (cy>hi_y) hi_y=cy;
                            for (ny=cy-1;ny<=cy+1;ny=ny+1)
                                for (nx=cx-1;nx<=cx+1;nx=nx+1)
                                    if (nx>=0 && nx<14 && ny>=0 && ny<8 &&
                                        pix[ny*14+nx] && !seen[ny*14+nx]) begin
                                        seen[ny*14+nx]=1;
                                        qx[tail]=nx;qy[tail]=ny;tail=tail+1;
                                    end
                        end
                        area=tail;
                        if (area>=3) begin
                            if (expected>=16) $fatal(1,"reference overflow");
                            ex0[expected]=lo_x;ex1[expected]=hi_x;
                            ey0[expected]=lo_y;ey1[expected]=hi_y;
                            matched[expected]=0;
                            expected=expected+1;
                        end
                    end
            @(negedge clk);
            dut.active_new=1;
            dut.history_count=3;
            dut.changed_tiles=0;
            vsync=1;
            repeat(4) @(negedge clk);
            vsync=0;
            repeat(2500) @(negedge clk);
            if (dut.state!=0) $fatal(1,"scan overran blank t=%0d",t);
            if (overflow || count!=expected) begin
                for (y=0;y<8;y=y+1) begin
                    for (x=0;x<14;x=x+1) $write("%0d",pix[y*14+x]);
                    $write("\n");
                end
                for (i=0;i<expected;i=i+1)
                    $display("expected %0d: %0d,%0d to %0d,%0d",i,
                             ex0[i],ey0[i],ex1[i],ey1[i]);
                for (i=0;i<count;i=i+1)
                    $display("got %0d: %h",i,boxes[i*26 +: 26]);
                $fatal(1,"component count t=%0d got=%0d expected=%0d overflow=%0d",
                       t,count,expected,overflow);
            end
            for (i=0;i<count;i=i+1) begin
                box_data=boxes[i*26 +: 26];found=0;
                for (j=0;j<expected;j=j+1)
                    if (!matched[j] && box_data[6:0]==ex0[j] &&
                        box_data[19:13]==ex1[j] &&
                        box_data[12:7]==ey0[j] &&
                        box_data[25:20]==ey1[j]) begin
                        matched[j]=1;found=1;
                    end
                if (!found) $fatal(1,"component bounds t=%0d box=%h",t,box_data);
            end
        end
        $display("PASS tb_motion_components");
        $finish;
    end
endmodule
