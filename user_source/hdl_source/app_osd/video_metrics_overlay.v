// Compact measured camera/HDMI frame-rate and HDMI active-size panel.
module video_metrics_overlay (
    input wire I_clk,I_rst_n,I_vsync,I_hsync,I_de,
    input wire [23:0] I_rgb,
    input wire [11:0] I_cam_fps_bcd,I_hdmi_fps_bcd,
    input wire I_fps_valid,
    input wire [15:0] I_width_bcd,I_height_bcd,
    input wire I_size_valid,
    output reg O_vsync,O_hsync,O_de,
    output reg [23:0] O_rgb
);
    reg [11:0] x,y;
    reg de_prev,vs_prev;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x<=0;y<=0;de_prev<=0;vs_prev<=0;
        end else begin
            de_prev<=I_de;vs_prev<=I_vsync;
            if(I_vsync && !vs_prev) begin x<=0;y<=0;end
            else if(de_prev && !I_de) begin x<=0;y<=y+12'd1;end
            else if(I_de) x<=x+12'd1;
        end
    end
    function [4:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            glyph_row=5'b00000;
            case(ch)
                "0":case(row) 0,6:glyph_row=5'b01110;1,2,3,4,5:glyph_row=5'b10001;endcase
                "1":case(row) 0:glyph_row=5'b00100;1:glyph_row=5'b01100;2,3,4,5:glyph_row=5'b00100;6:glyph_row=5'b01110;endcase
                "2":case(row) 0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b00010;4:glyph_row=5'b00100;5:glyph_row=5'b01000;6:glyph_row=5'b11111;endcase
                "3":case(row) 0:glyph_row=5'b11110;1,2:glyph_row=5'b00001;3:glyph_row=5'b01110;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "4":case(row) 0,1,2:glyph_row=5'b10010;3:glyph_row=5'b11111;4,5,6:glyph_row=5'b00010;endcase
                "5":case(row) 0:glyph_row=5'b11111;1,2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "6":case(row) 0:glyph_row=5'b01111;1,2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "7":case(row) 0:glyph_row=5'b11111;1,2:glyph_row=5'b00001;3:glyph_row=5'b00010;4:glyph_row=5'b00100;5,6:glyph_row=5'b01000;endcase
                "8":case(row) 0,3,6:glyph_row=5'b01110;1,2,4,5:glyph_row=5'b10001;endcase
                "9":case(row) 0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b01111;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "A":case(row) 0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b11111;4,5,6:glyph_row=5'b10001;endcase
                "C":case(row) 0,6:glyph_row=5'b01111;1,2,3,4,5:glyph_row=5'b10000;endcase
                "F":case(row) 0:glyph_row=5'b11111;1,2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5,6:glyph_row=5'b10000;endcase
                "M":case(row) 0:glyph_row=5'b10001;1:glyph_row=5'b11011;2:glyph_row=5'b10101;3,4,5,6:glyph_row=5'b10001;endcase
                "O":case(row) 0,6:glyph_row=5'b01110;1,2,3,4,5:glyph_row=5'b10001;endcase
                "P":case(row) 0,3:glyph_row=5'b11110;1,2:glyph_row=5'b10001;4,5,6:glyph_row=5'b10000;endcase
                "S":case(row) 0:glyph_row=5'b01111;1,2:glyph_row=5'b10000;3:glyph_row=5'b01110;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "T":case(row) 0:glyph_row=5'b11111;1,2,3,4,5,6:glyph_row=5'b00100;endcase
                "U":case(row) 0,1,2,3,4,5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "X":case(row) 0,6:glyph_row=5'b10001;1,5:glyph_row=5'b01010;2,3,4:glyph_row=5'b00100;endcase
                "-":if(row==3) glyph_row=5'b11111;
                default:glyph_row=5'b00000;
            endcase
        end
    endfunction
    wire panel=x>=12'd872 && x<12'd1072 && y>=12'd28 && y<12'd98;
    wire border=panel && (x==12'd872 || x==12'd1071 || y==12'd28 || y==12'd97);
    wire text_x_ok=x>=12'd880 && x<12'd1040;
    wire line_cam=text_x_ok && y>=12'd36 && y<12'd50;
    wire line_out=text_x_ok && y>=12'd56 && y<12'd70;
    wire line_size=text_x_ok && y>=12'd76 && y<12'd90;
    wire [7:0] dx=x-12'd880;
    wire [3:0] char_index=dx[7:4];
    wire [2:0] col=dx[3:1];
    wire [2:0] row=line_cam ? ((y-12'd36)>>1) :
                   line_out ? ((y-12'd56)>>1) : ((y-12'd76)>>1);
    wire [11:0] fps_bcd=line_cam ? I_cam_fps_bcd : I_hdmi_fps_bcd;
    reg [7:0] ch;
    always @* begin
        ch=" ";
        if(line_cam || line_out) begin
            case(char_index)
                0:ch=line_cam ? "C" : "O";
                1:ch=line_cam ? "A" : "U";
                2:ch=line_cam ? "M" : "T";
                4:ch=I_fps_valid ? (8'd48+fps_bcd[11:8]) : "-";
                5:ch=I_fps_valid ? (8'd48+fps_bcd[7:4]) : "-";
                6:ch=I_fps_valid ? (8'd48+fps_bcd[3:0]) : "-";
                7:ch=I_fps_valid ? "F" : " ";
                8:ch=I_fps_valid ? "P" : " ";
                9:ch=I_fps_valid ? "S" : " ";
                default:ch=" ";
            endcase
        end else if(line_size) begin
            case(char_index)
                0:ch=I_size_valid ? (8'd48+I_width_bcd[15:12]) : "-";
                1:ch=I_size_valid ? (8'd48+I_width_bcd[11:8]) : "-";
                2:ch=I_size_valid ? (8'd48+I_width_bcd[7:4]) : "-";
                3:ch=I_size_valid ? (8'd48+I_width_bcd[3:0]) : "-";
                4:ch="X";
                5:ch=I_size_valid ? (8'd48+(I_height_bcd[15:12]==0 ?
                      I_height_bcd[11:8] : I_height_bcd[15:12])) : "-";
                6:ch=I_size_valid ? (8'd48+(I_height_bcd[15:12]==0 ?
                      I_height_bcd[7:4] : I_height_bcd[11:8])) : "-";
                7:ch=I_size_valid ? (8'd48+(I_height_bcd[15:12]==0 ?
                      I_height_bcd[3:0] : I_height_bcd[7:4])) : "-";
                8:ch=I_size_valid && I_height_bcd[15:12]!=0 ?
                      (8'd48+I_height_bcd[3:0]) : " ";
                default:ch=" ";
            endcase
        end
    end
    wire [4:0] bits=glyph_row(ch,row);
    wire letter=(line_cam || line_out || line_size) && col<5 && bits[4-col];
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin O_vsync<=0;O_hsync<=0;O_de<=0;O_rgb<=0;end
        else begin
            O_vsync<=I_vsync;O_hsync<=I_hsync;O_de<=I_de;
            if(!I_de) O_rgb<=24'd0;
            else if(letter) O_rgb<=24'hffffff;
            else if(border) O_rgb<=24'h4eb5ff;
            else if(panel) O_rgb<=24'h102430;
            else O_rgb<=I_rgb;
        end
    end
endmodule
