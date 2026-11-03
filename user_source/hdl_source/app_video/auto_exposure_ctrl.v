// Low-cost highlight-protecting auto exposure for the existing 720p60 path.
// One pixel per 16x16 tile is sampled; no frame store or histogram is used.
// Exposure changes at most once per eight frames. Only an almost entirely
// dark scene can request the already-validated 7x analog gain setting.
module auto_exposure_ctrl #(
    parameter integer WIDTH=1280, HEIGHT=720,
    parameter integer HIGHLIGHT_TILES=540,
    parameter integer LOW_HIGHLIGHT_TILES=180,
    parameter integer DARK_TILES=3240,
    parameter integer LOW_DARK_TILES=2700,
    parameter integer UPDATE_FRAMES=8
) (
    input wire I_clk, I_rst_n, I_vsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable,
    output reg [15:0] O_exposure,
    output reg O_gain_boost,
    output reg O_update_toggle
);
    reg [10:0] x;
    reg [9:0] y;
    reg de_d, vs_d, enable_d;
    reg [11:0] bright_count, dark_count;
    reg [2:0] frame_div;
    wire frame_start=I_vsync && !vs_d;
    wire sample=I_enable && I_de && x<WIDTH && y<HEIGHT &&
                x[3:0]==4'd0 && y[3:0]==4'd0;
    wire [9:0] luma={2'b0,I_rgb[23:16]}+
                     {1'b0,I_rgb[15:8],1'b0}+
                     {2'b0,I_rgb[7:0]};

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x<=0; y<=0; de_d<=0; vs_d<=0; enable_d<=0;
            bright_count<=0; dark_count<=0; frame_div<=0;
            O_exposure<=16'd1990; O_gain_boost<=0;
            O_update_toggle<=0;
        end else begin
            de_d<=I_de;
            vs_d<=I_vsync;
            enable_d<=I_enable;
            if (frame_start) begin
                x<=0; y<=0;
                bright_count<=0; dark_count<=0;
                if (I_enable && enable_d) begin
                    frame_div <= (frame_div==UPDATE_FRAMES-1) ? 3'd0 : frame_div+3'd1;
                    if (frame_div==UPDATE_FRAMES-1) begin
                        if (bright_count>=HIGHLIGHT_TILES && O_exposure>16'd320) begin
                            O_exposure<=O_exposure-16'd64;
                            if (O_gain_boost) O_gain_boost<=0;
                            O_update_toggle<=~O_update_toggle;
                        end else if (bright_count<=LOW_HIGHLIGHT_TILES && O_exposure<16'd1990) begin
                            O_exposure <= (O_exposure>16'd1926) ? 16'd1990 : O_exposure+16'd64;
                            O_update_toggle<=~O_update_toggle;
                        end else if (O_exposure==16'd1990) begin
                            if (dark_count>=DARK_TILES && !O_gain_boost) begin
                                O_gain_boost<=1;
                                O_update_toggle<=~O_update_toggle;
                            end else if (dark_count<=LOW_DARK_TILES && O_gain_boost) begin
                                O_gain_boost<=0;
                                O_update_toggle<=~O_update_toggle;
                            end
                        end
                    end
                end else frame_div<=0;
            end else if (de_d && !I_de) begin
                x<=0;
                y<=y+10'd1;
            end else if (I_de) x<=x+11'd1;

            if (sample) begin
                if (luma>=10'd980) bright_count<=bright_count+12'd1;
                if (luma<=10'd192) dark_count<=dark_count+12'd1;
            end
            if (!I_enable && enable_d) begin
                if (O_exposure!=16'd1990 || O_gain_boost) begin
                    O_exposure<=16'd1990;
                    O_gain_boost<=0;
                    O_update_toggle<=~O_update_toggle;
                end
            end
        end
    end
endmodule
