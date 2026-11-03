// One-sided 2-D gradient at the current pixel: |P-left| + |P-up|.
// A causal 2x2 box filter suppresses single-pixel sensor noise before the
// gradient. Filtering is EDGE-only: O_gray remains the unfiltered input for
// GRAY/BIN modes. No whole-frame RAM or video backpressure is required.
module edge_gradient #(
    parameter integer WIDTH = 1280,
    parameter integer DENOISE_ENABLE = 1,
    parameter integer EDGE_STABILIZE = 1
) (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_vsync,
    input  wire       I_de,
    input  wire [7:0] I_gray,
    input  wire [7:0] I_threshold,
    output reg  [7:0] O_gray,
    output reg  [7:0] O_edge
);
    reg [7:0] line_mem [0:WIDTH-1]; // Previous filtered line.
    reg [7:0] raw_line_mem [0:WIDTH-1];
    reg [10:0] x;
    reg [7:0] left_gray;
    reg [7:0] left_raw;
    reg [7:0] up_left_raw;
    reg       de_d;
    reg       vs_d;
    reg       have_previous_line;

    reg [7:0] gray_q;
    reg [7:0] gray_raw_q;
    reg [7:0] left_q;
    reg [7:0] up_q;
    reg [10:0] edge_x;
    reg edge_de_prev;
    reg edge_vs_prev;
    reg have_edge_previous_line;
    reg weak_left;
    reg weak_up_left;
    reg weak_line_mem [0:WIDTH-1];

    wire [7:0] dh = (gray_q >= left_q) ? (gray_q-left_q) : (left_q-gray_q);
    wire [7:0] dv = (gray_q >= up_q) ? (gray_q-up_q) : (up_q-gray_q);
    wire [8:0] magnitude = {1'b0, dh} + {1'b0, dv};
    wire [8:0] weak_threshold = {1'b0, I_threshold};
    wire [8:0] strong_threshold = weak_threshold + 9'd4;
    wire weak_now = magnitude >= weak_threshold;
    wire strong_now = magnitude >= strong_threshold;
    wire weak_up = (have_edge_previous_line && edge_x < WIDTH) ?
                   weak_line_mem[edge_x] : 1'b0;
    // A weak candidate must continue a nearby weak stroke. A strong edge
    // passes directly, preserving the start of a fine line.
    wire supported_edge = strong_now ||
                          (weak_now && (weak_left || weak_up || weak_up_left));
    wire [7:0] raw_up = (have_previous_line && x < WIDTH) ? raw_line_mem[x] : I_gray;
    wire [7:0] raw_left = (x == 0) ? I_gray : left_raw;
    wire [7:0] raw_up_left = (x == 0) ? raw_up : up_left_raw;
    wire [9:0] box_sum = {2'b0, I_gray} + {2'b0, raw_left} +
                         {2'b0, raw_up} + {2'b0, raw_up_left};
    wire [7:0] filtered_gray = (DENOISE_ENABLE != 0) ?
                               ((box_sum + 10'd2) >> 2) : I_gray;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x                  <= 11'd0;
            left_gray          <= 8'd0;
            left_raw           <= 8'd0;
            up_left_raw        <= 8'd0;
            de_d               <= 1'b0;
            vs_d               <= 1'b0;
            have_previous_line <= 1'b0;
            gray_q             <= 8'd0;
            gray_raw_q         <= 8'd0;
            left_q             <= 8'd0;
            up_q               <= 8'd0;
            edge_x             <= 11'd0;
            edge_de_prev       <= 1'b0;
            edge_vs_prev       <= 1'b0;
            have_edge_previous_line <= 1'b0;
            weak_left          <= 1'b0;
            weak_up_left       <= 1'b0;
            O_gray             <= 8'd0;
            O_edge             <= 8'd0;
        end else begin
            de_d <= I_de;
            vs_d <= I_vsync;
            edge_de_prev <= de_d;
            edge_vs_prev <= vs_d;

            // Stage 2. The companion RGB/control path delays by two clocks.
            O_gray <= gray_raw_q;
            O_edge <= ((EDGE_STABILIZE != 0) ? supported_edge : weak_now) ?
                      8'hff : 8'h00;

            if (vs_d && !edge_vs_prev)
                have_edge_previous_line <= 1'b0;
            if (de_d) begin
                if (edge_x < WIDTH) begin
                    if (EDGE_STABILIZE != 0)
                        weak_line_mem[edge_x] <= weak_now;
                    edge_x <= edge_x + 11'd1;
                end
                weak_left <= weak_now;
                weak_up_left <= weak_up;
            end else begin
                edge_x <= 11'd0;
                weak_left <= 1'b0;
                weak_up_left <= 1'b0;
                if (edge_de_prev)
                    have_edge_previous_line <= 1'b1;
            end

            if (I_vsync && !vs_d)
                have_previous_line <= 1'b0;

            if (I_de) begin
                // Guard the RAM address if an upstream line is malformed.
                if (x < WIDTH) begin
                    up_q       <= have_previous_line ? line_mem[x] : filtered_gray;
                    line_mem[x] <= filtered_gray;
                    if (DENOISE_ENABLE != 0)
                        raw_line_mem[x] <= I_gray;
                end else begin
                    up_q <= filtered_gray;
                end
                left_q    <= (x == 0) ? filtered_gray : left_gray;
                gray_q    <= filtered_gray;
                gray_raw_q <= I_gray;
                left_gray <= filtered_gray;
                left_raw <= I_gray;
                up_left_raw <= raw_up;
                if (x < WIDTH)
                    x <= x + 11'd1;
            end else begin
                x         <= 11'd0;
                left_gray <= 8'd0;
                left_raw <= 8'd0;
                up_left_raw <= 8'd0;
                if (de_d)
                    have_previous_line <= 1'b1;
            end
        end
    end
endmodule
