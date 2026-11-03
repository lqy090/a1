// Keep the original one-clock OSD pipeline stage while retiring the old
// Chinese "Anlogic" text box. Future overlays can use this stage again.
module osd_overlay (
    input wire I_clk, I_rst_n, I_vsync, I_hsync, I_de,
    input wire [23:0] I_data,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_data
);
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_vsync <= 1'b0;
            O_hsync <= 1'b0;
            O_de <= 1'b0;
            O_data <= 24'd0;
        end else begin
            O_vsync <= I_vsync;
            O_hsync <= I_hsync;
            O_de <= I_de;
            O_data <= I_de ? I_data : 24'd0;
        end
    end
endmodule
