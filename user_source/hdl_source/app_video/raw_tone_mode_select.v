// Add the validated display curve to RAW only. All other modes pass through
// unchanged, with the same latency as RAW so downstream boxes/OSD stay aligned.
module raw_tone_mode_select (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire [2:0] I_mode,
    input wire [2:0] I_brightness_level,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    wire tone_vs, tone_hs, tone_de;
    wire [23:0] tone_rgb;
    raw_tone_display u_raw_tone_display (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        .I_vsync(I_vsync),.I_hsync(I_hsync),.I_de(I_de),.I_rgb(I_rgb),
        .I_brightness_level(I_brightness_level),
        .O_vsync(tone_vs),.O_hsync(tone_hs),.O_de(tone_de),.O_rgb(tone_rgb)
    );

    reg [23:0] rgb_d1, rgb_d2, rgb_d3, rgb_d4, rgb_d5;
    reg [2:0] mode_d1, mode_d2, mode_d3, mode_d4, mode_d5;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            rgb_d1 <= 0; rgb_d2 <= 0; rgb_d3 <= 0; rgb_d4 <= 0; rgb_d5 <= 0;
            mode_d1 <= 0; mode_d2 <= 0; mode_d3 <= 0; mode_d4 <= 0; mode_d5 <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            rgb_d1 <= I_rgb; rgb_d2 <= rgb_d1;
            rgb_d3 <= rgb_d2; rgb_d4 <= rgb_d3; rgb_d5 <= rgb_d4;
            mode_d1 <= I_mode; mode_d2 <= mode_d1;
            mode_d3 <= mode_d2; mode_d4 <= mode_d3; mode_d5 <= mode_d4;
            O_vsync <= tone_vs;
            O_hsync <= tone_hs;
            O_de <= tone_de;
            if (!tone_de) O_rgb <= 24'd0;
            else O_rgb <= (mode_d5 == 3'd0) ? tone_rgb : rgb_d5;
        end
    end
endmodule
