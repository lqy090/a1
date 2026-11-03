// User-supplied Anlogic mark at upper left. Empty logo pixels are transparent.
module logo_overlay (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_hsync,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output reg         O_vsync,
    output reg         O_hsync,
    output reg         O_de,
    output reg  [23:0] O_rgb
);
    reg [11:0] x, y;
    reg de_d, vs_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x <= 12'd0; y <= 12'd0; de_d <= 1'b0; vs_d <= 1'b0;
        end else begin
            de_d <= I_de; vs_d <= I_vsync;
            if (I_vsync && !vs_d) begin
                x <= 12'd0; y <= 12'd0;
            end else if (de_d && !I_de) begin
                x <= 12'd0; y <= y + 12'd1;
            end else if (I_de) begin
                x <= x + 12'd1;
            end
        end
    end
    wire in_logo = x >= 12'd24 && x < 12'd152 &&
                   y >= 12'd20 && y < 12'd104;
    wire [6:0] logo_x = x - 12'd24;
    wire [6:0] logo_y = y - 12'd20;
    wire [1:0] logo_pixel;
    logo_rom u_logo_rom(.I_x(logo_x), .I_y(logo_y), .O_pixel(logo_pixel));
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_vsync <= 1'b0; O_hsync <= 1'b0; O_de <= 1'b0; O_rgb <= 24'd0;
        end else begin
            O_vsync <= I_vsync; O_hsync <= I_hsync; O_de <= I_de;
            if (!I_de) O_rgb <= 24'd0;
            else if (in_logo && logo_pixel == 2'd1) O_rgb <= 24'h1c427c;
            else if (in_logo && logo_pixel == 2'd2) O_rgb <= 24'hf31829;
            else O_rgb <= I_rgb;
        end
    end
endmodule
