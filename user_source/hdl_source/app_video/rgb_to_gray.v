// ITU-R BT.601-like integer approximation: 0.25 R + 0.5 G + 0.25 B.
// It is deliberately shift/add only, with an 8-bit bounded result.
module rgb_to_gray (
    input  wire [23:0] I_rgb,
    output wire [7:0]  O_gray
);
    wire [7:0] r_part = {2'b00, I_rgb[23:18]};
    wire [7:0] g_part = {1'b0, I_rgb[15:9]};
    wire [7:0] b_part = {2'b00, I_rgb[7:2]};
    assign O_gray = r_part + g_part + b_part;
endmodule
