// Conservative luminance tone mapping for the RAW-only display probe.
// RGB ratios are preserved by applying one gain to all three channels.
module raw_tone_display (
    input wire I_clk, I_rst_n,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_rgb,
    input wire [2:0] I_brightness_level,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_rgb
);
    wire [7:0] r = I_rgb[23:16], g = I_rgb[15:8], b = I_rgb[7:0];
    wire [15:0] luma_sum = r * 8'd77 + g * 8'd150 + b * 8'd29;
    wire [7:0] luma = luma_sum[15:8];
    wire [7:0] max_rg = (r > g) ? r : g;
    wire [7:0] max_rgb = (max_rg > b) ? max_rg : b;

    // Q8 gain: black stays black; midtones rise; highlights return to 1x.
    function [8:0] tone_gain;
        input [7:0] y;
        begin
            if (y <= 8'd8) tone_gain = 9'd256;
            else if (y <= 8'd72) tone_gain = 9'd256 + ({1'b0,y} - 9'd8) * 9'd2;
            else if (y <= 8'd136) tone_gain = 9'd384 - ({1'b0,y} - 9'd72);
            else if (y <= 8'd200) tone_gain = 9'd320 - ({1'b0,y} - 9'd136);
            else tone_gain = 9'd256;
        end
    endfunction
    // Limit the gain when one colour channel is already high, avoiding
    // coloured highlights turning into white through channel clipping.
    function [8:0] highlight_limit;
        input [7:0] m;
        begin
            if (m >= 8'd224) highlight_limit = 9'd256;
            else if (m >= 8'd192) highlight_limit = 9'd288;
            else if (m >= 8'd160) highlight_limit = 9'd320;
            else highlight_limit = 9'd384;
        end
    endfunction

    // The button state crosses from 24 MHz and is committed only at a frame
    // boundary, so one HDMI frame never contains two brightness settings.
    reg [2:0] level_meta,level_sync,level_frame;
    reg vs_prev;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            level_meta<=3'd3;level_sync<=3'd3;level_frame<=3'd3;vs_prev<=0;
        end else begin
            level_meta<=I_brightness_level;
            level_sync<=level_meta;
            vs_prev<=I_vsync;
            if (I_vsync && !vs_prev) level_frame<=level_sync;
        end
    end

    reg [23:0] rgb_d1, rgb_d2;
    reg [7:0] luma_d1, max_d1;
    reg [8:0] gain_d2;
    reg [16:0] rp_d3, gp_d3, bp_d3;
    reg [2:0] level_d1,level_d2,level_d3;
    reg [7:0] base_r_d4,base_g_d4,base_b_d4;
    reg [8:0] display_gain_d4;
    reg [3:0] vs_pipe, hs_pipe, de_pipe;
    wire [8:0] selected_gain = (tone_gain(luma_d1) < highlight_limit(max_d1)) ?
                               tone_gain(luma_d1) : highlight_limit(max_d1);
    wire [7:0] base_r = rp_d3[16] ? 8'hff : rp_d3[15:8];
    wire [7:0] base_g = gp_d3[16] ? 8'hff : gp_d3[15:8];
    wire [7:0] base_b = bp_d3[16] ? 8'hff : bp_d3[15:8];
    wire [7:0] base_rg_max = base_r > base_g ? base_r : base_g;
    wire [7:0] base_max = base_rg_max > base_b ? base_rg_max : base_b;
    // The three dimming levels use a fixed Q8 multiplier on every RAW pixel
    // and colour channel. Positive levels retain their validated boost curve.
    wire [7:0] boost_strength = (level_d3 == 3'd4) ? 8'd48 :
                                (level_d3 == 3'd5) ? 8'd96 :
                                (level_d3 == 3'd6) ? 8'd160 : 8'd0;
    wire [15:0] boost_product = (8'd255-base_max) * boost_strength;
    wire [8:0] display_gain = (level_d3 == 3'd0) ? 9'd128 : // B-3: 50%
                              (level_d3 == 3'd1) ? 9'd166 : // B-2: 65%
                              (level_d3 == 3'd2) ? 9'd205 : // B-1: 80%
                              9'd256 + boost_product[15:8];
    wire [16:0] out_r_product = base_r_d4 * display_gain_d4;
    wire [16:0] out_g_product = base_g_d4 * display_gain_d4;
    wire [16:0] out_b_product = base_b_d4 * display_gain_d4;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            rgb_d1 <= 0; rgb_d2 <= 0; luma_d1 <= 0; max_d1 <= 0;
            gain_d2 <= 9'd256;
            rp_d3 <= 0; gp_d3 <= 0; bp_d3 <= 0;
            level_d1<=3'd3;level_d2<=3'd3;level_d3<=3'd3;
            base_r_d4<=0;base_g_d4<=0;base_b_d4<=0;
            display_gain_d4<=9'd256;
            vs_pipe <= 0; hs_pipe <= 0; de_pipe <= 0;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
        end else begin
            rgb_d1 <= I_rgb;
            luma_d1 <= luma;
            max_d1 <= max_rgb;
            level_d1<=level_frame;
            rgb_d2 <= rgb_d1;
            gain_d2 <= selected_gain;
            level_d2<=level_d1;
            rp_d3 <= rgb_d2[23:16] * gain_d2;
            gp_d3 <= rgb_d2[15:8] * gain_d2;
            bp_d3 <= rgb_d2[7:0] * gain_d2;
            level_d3<=level_d2;
            base_r_d4<=base_r;base_g_d4<=base_g;base_b_d4<=base_b;
            display_gain_d4<=display_gain;
            vs_pipe <= {vs_pipe[2:0],I_vsync};
            hs_pipe <= {hs_pipe[2:0],I_hsync};
            de_pipe <= {de_pipe[2:0],I_de};
            O_vsync <= vs_pipe[3];
            O_hsync <= hs_pipe[3];
            O_de <= de_pipe[3];
            if (de_pipe[3])
                O_rgb <= {out_r_product[16] ? 8'hff : out_r_product[15:8],
                          out_g_product[16] ? 8'hff : out_g_product[15:8],
                          out_b_product[16] ? 8'hff : out_b_product[15:8]};
            else O_rgb <= 24'd0;
        end
    end
endmodule
