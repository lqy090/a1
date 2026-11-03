// KEY3 (active low): one click advances the display mode; a double click
// toggles the target box without advancing the mode. Both outputs are
// committed only at the next video-frame boundary.
module mode_key_ctrl #(
    parameter integer DEBOUNCE_CYCLES = 1485000,      // 20 ms at 74.25 MHz
    parameter integer DOUBLE_CLICK_CYCLES = 22275000  // 300 ms at 74.25 MHz
) (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_key_n,
    input  wire       I_vsync,
    output reg  [2:0] O_mode,
    output reg        O_box_enable
);
    localparam [1:0] IDLE = 2'd0, FIRST_DOWN = 2'd1,
                     WAIT_SECOND = 2'd2, SECOND_DOWN = 2'd3;
    reg key_meta, key_sync, key_stable;
    reg [20:0] stable_count;
    reg [24:0] click_count;
    reg [1:0] click_state;
    reg [2:0] requested_mode;
    reg requested_box_enable;
    reg vs_d;
    wire stable_change = key_sync != key_stable &&
                         stable_count == DEBOUNCE_CYCLES-1;
    wire pressed = stable_change && !key_sync;
    wire released = stable_change && key_sync;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            key_meta      <= 1'b1;
            key_sync      <= 1'b1;
            key_stable    <= 1'b1;
            stable_count  <= 21'd0;
            click_count <= 25'd0;
            click_state <= IDLE;
            requested_mode <= 3'd0;
            requested_box_enable <= 1'b0;
            O_mode        <= 3'd0;
            O_box_enable <= 1'b0;
            vs_d          <= 1'b0;
        end else begin
            key_meta <= I_key_n;
            key_sync <= key_meta;
            vs_d <= I_vsync;

            if (key_sync == key_stable) begin
                stable_count <= 21'd0;
            end else if (stable_change) begin
                stable_count <= 21'd0;
                key_stable <= key_sync;
            end else begin
                stable_count <= stable_count + 21'd1;
            end

            case (click_state)
                IDLE: begin
                    click_count <= 25'd0;
                    if (pressed) click_state <= FIRST_DOWN;
                end
                FIRST_DOWN: if (released) begin
                    click_state <= WAIT_SECOND;
                    click_count <= 25'd0;
                end
                WAIT_SECOND: begin
                    if (pressed) begin
                        requested_box_enable <= ~requested_box_enable;
                        click_state <= SECOND_DOWN;
                    end else if (click_count == DOUBLE_CLICK_CYCLES-1) begin
                        requested_mode <= (requested_mode == 3'd5) ?
                                          3'd0 : requested_mode + 3'd1;
                        click_state <= IDLE;
                    end else
                        click_count <= click_count + 25'd1;
                end
                SECOND_DOWN: if (released) click_state <= IDLE;
            endcase

            if (I_vsync && !vs_d) begin
                O_mode <= requested_mode;
                O_box_enable <= requested_box_enable;
            end
        end
    end
endmodule
