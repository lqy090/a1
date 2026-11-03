// Generated from assets/anlogic_logo_user.png by tools/logo_to_rom.py.
// Source SHA-256: b5ca58b7d3aad29828b927a6fefb696d669840ef1dc50aa92eb30c5da7e62346
module logo_rom (
    input wire [6:0] I_x,
    input wire [6:0] I_y,
    output wire [1:0] O_pixel
);
    reg [127:0] blue_row, red_row;
    always @* begin
        blue_row = 128'd0; red_row = 128'd0;
        case (I_y)
            7'd0: begin blue_row = 128'h00000000000000000000000000000000; red_row = 128'h000000000003ffffffffffffffffffff; end
            7'd1: begin blue_row = 128'h00000000002000000000000000000000; red_row = 128'h000000000001fffffffffffffffffffe; end
            7'd2: begin blue_row = 128'h00000000006000000000000000000000; red_row = 128'h000000000001fffffffffffffffffffe; end
            7'd3: begin blue_row = 128'h00000000007000000000000000000000; red_row = 128'h000000000000fffffffffffffffffffc; end
            7'd4: begin blue_row = 128'h0000000000f000000000000000000000; red_row = 128'h000000000000fffffffffffffffffffc; end
            7'd5: begin blue_row = 128'h0000000000f800000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd6: begin blue_row = 128'h0000000001f800000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd7: begin blue_row = 128'h0000000001fc00000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd8: begin blue_row = 128'h0000000003fc00000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd9: begin blue_row = 128'h0000000003fe00000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd10: begin blue_row = 128'h0000000007fe00000000000000000000; red_row = 128'h0000000000001fffffffffffffffffe0; end
            7'd11: begin blue_row = 128'h0000000007ff00000000000000000000; red_row = 128'h0000000000000fffffffffffffffffc0; end
            7'd12: begin blue_row = 128'h000000000fff00000000000000000000; red_row = 128'h0000000000000fffffffffffffffffc0; end
            7'd13: begin blue_row = 128'h000000000fff80000000000000000000; red_row = 128'h00000000000007ffffffffffffffff80; end
            7'd14: begin blue_row = 128'h000000001fff80000000000000000000; red_row = 128'h00000000000007ffffffffffffffff80; end
            7'd15: begin blue_row = 128'h000000001fffc0000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd16: begin blue_row = 128'h000000003fffc0000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd17: begin blue_row = 128'h000000003fffe0000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd18: begin blue_row = 128'h000000007fffe0000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd19: begin blue_row = 128'h000000007ffff0000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd20: begin blue_row = 128'h00000000fffff0000000000000000000; red_row = 128'h00000000000000fffffffffffffffc00; end
            7'd21: begin blue_row = 128'h00000000fffff8000000000000000000; red_row = 128'h00000000000000fffffffffffffff800; end
            7'd22: begin blue_row = 128'h00000001fffff8000000000000000000; red_row = 128'h000000000000007ffffffffffffff800; end
            7'd23: begin blue_row = 128'h00000001fffffc000000000000000000; red_row = 128'h000000000000007ffffffffffffff000; end
            7'd24: begin blue_row = 128'h00000003fffffc000000000000000000; red_row = 128'h000000000000003ffffffffffffff000; end
            7'd25: begin blue_row = 128'h00000003fffffe000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd26: begin blue_row = 128'h00000007fffffe000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd27: begin blue_row = 128'h00000007ffffff000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd28: begin blue_row = 128'h0000000fffffff000000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd29: begin blue_row = 128'h0000001fffffff800000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd30: begin blue_row = 128'h0000001fffffff800000000000000000; red_row = 128'h0000000000000007ffffffffffff8000; end
            7'd31: begin blue_row = 128'h0000003fffffffc00000000000000000; red_row = 128'h0000000000000007ffffffffffff0000; end
            7'd32: begin blue_row = 128'h0000003fffffffc00000000000000000; red_row = 128'h0000000000000003ffffffffffff0000; end
            7'd33: begin blue_row = 128'h0000007fffffffe00000000000000000; red_row = 128'h0000000000000003fffffffffffe0000; end
            7'd34: begin blue_row = 128'h0000007fffffffe00000000000000000; red_row = 128'h0000000000000001fffffffffffe0000; end
            7'd35: begin blue_row = 128'h000000fffffffff00000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd36: begin blue_row = 128'h000000fffffffff00000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd37: begin blue_row = 128'h000001fffffffff80000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd38: begin blue_row = 128'h000001fffffffff80000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd39: begin blue_row = 128'h000003ffff9ffffc0000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd40: begin blue_row = 128'h000003ffff9ffffc0000000000000000; red_row = 128'h00000000000000003ffffffffff00000; end
            7'd41: begin blue_row = 128'h000007ffff1ffffe0000000000000000; red_row = 128'h00000000000000003ffffffffff00000; end
            7'd42: begin blue_row = 128'h000007ffff0ffffe0000000000000000; red_row = 128'h00000000000000001fffffffffe00000; end
            7'd43: begin blue_row = 128'h00000ffffe0fffff0000000000000000; red_row = 128'h00000000000000001fffffffffe00000; end
            7'd44: begin blue_row = 128'h00000ffffe07ffff0000000000000000; red_row = 128'h00000000000000000fffffffffc00000; end
            7'd45: begin blue_row = 128'h00001ffffc07ffff8000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd46: begin blue_row = 128'h00001ffffc03ffff8000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd47: begin blue_row = 128'h00003ffff803ffffc000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd48: begin blue_row = 128'h00003ffff801ffffc000000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd49: begin blue_row = 128'h00007ffff001ffffe000000000000000; red_row = 128'h000000000000000003fffffffe000000; end
            7'd50: begin blue_row = 128'h00007ffff000ffffe000000000000000; red_row = 128'h000000000000000003fffffffe000000; end
            7'd51: begin blue_row = 128'h0000ffffe000fffff000000000000000; red_row = 128'h000000000000000001fffffffe000000; end
            7'd52: begin blue_row = 128'h0000ffffe0007ffff000000000000000; red_row = 128'h000000000000000001fffffffc000000; end
            7'd53: begin blue_row = 128'h0001ffffc0007ffff800000000000000; red_row = 128'h000000000000000000fffffffc000000; end
            7'd54: begin blue_row = 128'h0001ffffc0003ffff800000000000000; red_row = 128'h0000000000000000007ffffff8000000; end
            7'd55: begin blue_row = 128'h0003ffff80003ffffc00000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd56: begin blue_row = 128'h0003ffff80001ffffc00000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd57: begin blue_row = 128'h0007ffff00001ffffe00000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd58: begin blue_row = 128'h0007ffff00000ffffe00000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd59: begin blue_row = 128'h000ffffe00000fffff00000000000000; red_row = 128'h0000000000000000001fffffe0000000; end
            7'd60: begin blue_row = 128'h000ffffe000007ffff00000000000000; red_row = 128'h0000000000000000001fffffc0000000; end
            7'd61: begin blue_row = 128'h001ffffc000007ffff80000000000000; red_row = 128'h0000000000000000000fffffc0000000; end
            7'd62: begin blue_row = 128'h001ffffc000003ffff80000000000000; red_row = 128'h0000000000000000000fffff80000000; end
            7'd63: begin blue_row = 128'h003ffff8000003ffffc0000000000000; red_row = 128'h00000000000000000007ffff80000000; end
            7'd64: begin blue_row = 128'h003ffff8000001ffffc0000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd65: begin blue_row = 128'h007ffff0000001ffffe0000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd66: begin blue_row = 128'h007ffff0000000ffffe0000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd67: begin blue_row = 128'h00ffffe0000000fffff0000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd68: begin blue_row = 128'h00ffffe00000007ffff0000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd69: begin blue_row = 128'h01fffffffffe007ffff8000000000000; red_row = 128'h00000000000000000000fffc00000000; end
            7'd70: begin blue_row = 128'h01fffffffffe003ffff8000000000000; red_row = 128'h00000000000000000000fff800000000; end
            7'd71: begin blue_row = 128'h03ffffffffff003ffffc000000000000; red_row = 128'h000000000000000000007ff800000000; end
            7'd72: begin blue_row = 128'h03ffffffffff001ffffc000000000000; red_row = 128'h000000000000000000007ff000000000; end
            7'd73: begin blue_row = 128'h07ffffffffff801ffffe000000000000; red_row = 128'h000000000000000000003ff000000000; end
            7'd74: begin blue_row = 128'h07ffffffffff800ffffe000000000000; red_row = 128'h000000000000000000003fe000000000; end
            7'd75: begin blue_row = 128'h0fffffffffffc00fffff000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd76: begin blue_row = 128'h0fffffffffffc007ffff000000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd77: begin blue_row = 128'h1fffffffffffe007ffff800000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd78: begin blue_row = 128'h1fffffffffffe003ffff800000000000; red_row = 128'h00000000000000000000000000000000; end
            7'd79: begin blue_row = 128'h3ffffffffffff003ffffc00000000000; red_row = 128'h000000000000000000000f8000000000; end
            7'd80: begin blue_row = 128'h3ffffffffffff801ffffc00000000000; red_row = 128'h00000000000000000000070000000000; end
            7'd81: begin blue_row = 128'h7ffffffffffff801ffffe00000000000; red_row = 128'h00000000000000000000070000000000; end
            7'd82: begin blue_row = 128'h7ffffffffffffc00ffffe00000000000; red_row = 128'h00000000000000000000020000000000; end
            7'd83: begin blue_row = 128'hfffffffffffffc00fffff00000000000; red_row = 128'h00000000000000000000000000000000; end
            default: begin blue_row = 128'd0; red_row = 128'd0; end
        endcase
    end
    wire is_blue = blue_row[127-I_x];
    wire is_red  = red_row[127-I_x];
    assign O_pixel = is_blue ? 2'd1 : is_red ? 2'd2 : 2'd0;
endmodule
