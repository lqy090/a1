// KEY4 toggles the colour mask overlay. RAW always uses the camera RGB stream.
module diag_key_ctrl #(
    parameter integer DEBOUNCE_CYCLES = 1485000
) (
    input wire I_clk,
    input wire I_rst_n,
    input wire I_key_n,
    input wire I_vsync,
    output reg O_mask_enable,
    output reg O_gamma_enable
);
    reg key_meta, key_sync, key_stable;
    reg [20:0] stable_count;
    reg [1:0] requested_state;
    reg vs_d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
            key_stable <= 1'b1;
            stable_count <= 21'd0;
            requested_state <= 2'd0;
            O_mask_enable <= 1'b0;
            O_gamma_enable <= 1'b0;
            vs_d <= 1'b0;
        end else begin
            key_meta <= I_key_n;
            key_sync <= key_meta;
            vs_d <= I_vsync;
            if (key_sync == key_stable) begin
                stable_count <= 21'd0;
            end else if (stable_count == DEBOUNCE_CYCLES-1) begin
                stable_count <= 21'd0;
                key_stable <= key_sync;
                if (!key_sync)
                    requested_state <= (requested_state == 2'd0) ? 2'd1 : 2'd0;
            end else begin
                stable_count <= stable_count + 21'd1;
            end
            if (I_vsync && !vs_d) begin
                O_mask_enable <= (requested_state == 2'd1);
                O_gamma_enable <= 1'b0;
            end
        end
    end
endmodule
