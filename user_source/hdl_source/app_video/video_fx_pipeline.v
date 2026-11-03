// RGB mode processing after DDR read/HDMI mixer. All six modes have exactly
// three pixel-clock cycles of latency and pass the same sync/de pipeline.
module video_fx_pipeline #(
    parameter integer WIDTH = 1280,
    parameter integer AUTO_THRESHOLDS = 1,
    parameter integer EDGE_DENOISE = 1,
    parameter integer EDGE_STABILIZE = 1,
    parameter [7:0] BINARY_INITIAL_THRESHOLD = 8'd40,
    parameter [7:0] EDGE_INITIAL_THRESHOLD = 8'd8
) (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_vsync,
    input  wire       I_hsync,
    input  wire       I_de,
    input  wire [23:0] I_rgb,
    input  wire [2:0] I_mode,
    input  wire       I_gamma_enable,
    output reg        O_vsync,
    output reg        O_hsync,
    output reg        O_de,
    output reg  [23:0] O_rgb
);
    wire [7:0] gray_now;
    wire [7:0] gray_edge_d2;
    wire [7:0] edge_d2;
    wire [7:0] bin_threshold;
    wire [7:0] edge_threshold;
    rgb_to_gray u_gray(.I_rgb(I_rgb), .O_gray(gray_now));
    generate if (AUTO_THRESHOLDS != 0) begin : gen_auto_threshold
        luma_auto_threshold #(
            .INITIAL_BIN(BINARY_INITIAL_THRESHOLD),
            .INITIAL_EDGE(EDGE_INITIAL_THRESHOLD)
        ) u_luma_auto_threshold(
            .I_clk(I_clk), .I_rst_n(I_rst_n), .I_vsync(I_vsync),
            .I_de(I_de), .I_gray(gray_now),
            .O_bin_threshold(bin_threshold),
            .O_edge_threshold(edge_threshold)
        );
    end else begin : gen_fixed_threshold
        assign bin_threshold = BINARY_INITIAL_THRESHOLD;
        assign edge_threshold = EDGE_INITIAL_THRESHOLD;
    end endgenerate
    edge_gradient #(.WIDTH(WIDTH), .DENOISE_ENABLE(EDGE_DENOISE),
                    .EDGE_STABILIZE(EDGE_STABILIZE)) u_edge(
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_vsync(I_vsync),
        .I_de(I_de), .I_gray(gray_now), .I_threshold(edge_threshold),
        .O_gray(gray_edge_d2), .O_edge(edge_d2)
    );

    reg [23:0] rgb_d1, rgb_d2;
    reg [2:0] mode_d1, mode_d2;
    reg gamma_d1, gamma_d2;
    reg vs_d1, vs_d2, hs_d1, hs_d2, de_d1, de_d2;
    wire [23:0] gray_rgb = {3{gray_edge_d2}};
    wire [7:0] binary_value = (gray_edge_d2 >= bin_threshold) ? 8'hff : 8'h00;
    wire [23:0] binary_rgb = {3{binary_value}};
    wire [23:0] edge_rgb = {3{edge_d2}};
    // Four-level colour posterization with the existing aligned edge stroke.
    // Recognition still uses the original RGB before this display pipeline.
    wire [23:0] poster_rgb = {
        {4{rgb_d2[23:22]}},
        {4{rgb_d2[15:14]}},
        {4{rgb_d2[7:6]}}
    };
    wire [23:0] cartoon_rgb = (edge_d2 != 8'd0) ? 24'h000000 : poster_rgb;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            rgb_d1 <= 24'd0; rgb_d2 <= 24'd0;
            mode_d1 <= 3'd0; mode_d2 <= 3'd0;
            gamma_d1 <= 1'b1; gamma_d2 <= 1'b1;
            vs_d1 <= 1'b0; vs_d2 <= 1'b0; O_vsync <= 1'b0;
            hs_d1 <= 1'b0; hs_d2 <= 1'b0; O_hsync <= 1'b0;
            de_d1 <= 1'b0; de_d2 <= 1'b0; O_de <= 1'b0;
            O_rgb <= 24'd0;
        end else begin
            rgb_d1 <= I_rgb;
            rgb_d2 <= rgb_d1;
            mode_d1 <= I_mode;
            mode_d2 <= mode_d1;
            gamma_d1 <= I_gamma_enable;
            gamma_d2 <= gamma_d1;
            vs_d1 <= I_vsync; vs_d2 <= vs_d1; O_vsync <= vs_d2;
            hs_d1 <= I_hsync; hs_d2 <= hs_d1; O_hsync <= hs_d2;
            de_d1 <= I_de; de_d2 <= de_d1; O_de <= de_d2;
            if (!de_d2)
                O_rgb <= 24'd0;
            else case (mode_d2)
                3'd0: O_rgb <= rgb_d2;
                3'd1: O_rgb <= gray_rgb;
                3'd2: O_rgb <= binary_rgb;
                3'd3: O_rgb <= edge_rgb;
                3'd4: O_rgb <= cartoon_rgb;
                3'd5: O_rgb <= ~rgb_d2;
                default: O_rgb <= rgb_d2;
            endcase
        end
    end
endmodule

// Estimate illumination from 4096 regularly spaced central pixels.
// The measured frame controls the next frame; thresholds never change mid-frame.
module luma_auto_threshold #(
    parameter integer X_START = 128,
    parameter integer X_END = 1152,
    parameter integer Y_START = 104,
    parameter integer Y_END = 616,
    parameter integer X_MASK = 15,
    parameter integer Y_MASK = 7,
    parameter integer EXPECTED_SAMPLES = 4096,
    parameter integer SAMPLE_SHIFT = 12,
    parameter [7:0] INITIAL_BIN = 8'd40,
    parameter [7:0] INITIAL_EDGE = 8'd8
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_vsync,
    input wire I_de,
    input wire [7:0] I_gray,
    output reg [7:0] O_bin_threshold,
    output reg [7:0] O_edge_threshold
);
    reg [10:0] x, y;
    reg de_d, vs_d;
    reg [19:0] sample_sum;
    reg [12:0] sample_count;
    reg [7:0] edge_pending;

    wire sample_here = I_de &&
                       x >= X_START && x < X_END &&
                       y >= Y_START && y < Y_END &&
                       ((x & X_MASK) == 0) && ((y & Y_MASK) == 0);
    wire [7:0] average = sample_sum >> SAMPLE_SHIFT;
    wire [7:0] bin_candidate = average - (average >> 2); // 75% of mean
    wire [7:0] edge_candidate = average >> 4; // 6.25% of mean, as in V3
    wire [7:0] edge_target = (edge_candidate < 8'd6) ? 8'd6 : edge_candidate;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 11'd0;
            y <= 11'd0;
            de_d <= 1'b0;
            vs_d <= 1'b0;
            sample_sum <= 20'd0;
            sample_count <= 13'd0;
            O_bin_threshold <= INITIAL_BIN;
            O_edge_threshold <= INITIAL_EDGE;
            edge_pending <= INITIAL_EDGE;
        end else begin
            de_d <= I_de;
            vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin
                // An incomplete input frame cannot corrupt the last good setting.
                if (sample_count == EXPECTED_SAMPLES) begin
                    O_bin_threshold <= (bin_candidate < 8'd8) ? 8'd8 : bin_candidate;
                    // Ignore a one-frame threshold fluctuation. Once two
                    // consecutive complete frames agree, move by at most one
                    // gray level per frame toward the new setting.
                    if (edge_target == edge_pending) begin
                        if (O_edge_threshold < edge_target)
                            O_edge_threshold <= O_edge_threshold + 8'd1;
                        else if (O_edge_threshold > edge_target)
                            O_edge_threshold <= O_edge_threshold - 8'd1;
                    end else begin
                        edge_pending <= edge_target;
                    end
                end
                sample_sum <= 20'd0;
                sample_count <= 13'd0;
                x <= 11'd0;
                y <= 11'd0;
            end else begin
                if (sample_here && sample_count < EXPECTED_SAMPLES) begin
                    sample_sum <= sample_sum + I_gray;
                    sample_count <= sample_count + 13'd1;
                end
                if (de_d && !I_de) begin
                    x <= 11'd0;
                    y <= y + 11'd1;
                end else if (I_de) begin
                    x <= x + 11'd1;
                end
            end
        end
    end
endmodule
