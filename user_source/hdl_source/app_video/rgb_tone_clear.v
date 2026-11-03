// Display-domain luminance remapping. One luminance LUT and a common offset
// retain channel differences, unlike three independent per-channel curves.
// All arithmetic is signed and saturated, so dark subtraction never wraps.
module rgb_tone_clear (
    input wire [23:0] I_rgb,
    output wire [23:0] O_rgb
);
    wire [7:0] y_in;
    wire [7:0] y_out;
    rgb_to_gray u_luma(.I_rgb(I_rgb), .O_gray(y_in));
    luma_tone_clear u_curve(.I_luma(y_in), .O_luma(y_out));

    wire signed [9:0] delta = $signed({2'b00, y_out}) - $signed({2'b00, y_in});
    wire signed [9:0] r_sum = $signed({2'b00, I_rgb[23:16]}) + delta;
    wire signed [9:0] g_sum = $signed({2'b00, I_rgb[15:8]}) + delta;
    wire signed [9:0] b_sum = $signed({2'b00, I_rgb[7:0]}) + delta;

    function [7:0] saturate8;
        input signed [9:0] value;
        begin
            if (value < 0) saturate8 = 8'd0;
            else if (value > 10'sd255) saturate8 = 8'd255;
            else saturate8 = value[7:0];
        end
    endfunction

    assign O_rgb = {saturate8(r_sum), saturate8(g_sum), saturate8(b_sum)};
endmodule
