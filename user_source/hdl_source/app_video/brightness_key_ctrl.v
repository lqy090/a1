// Board KEY1 (D5, active low): one click changes brightness by one step;
// two clicks within the window reverse direction without changing the level.
// Level encoding: 0/1/2 = B-3/B-2/B-1 (6x sensor gain),
// 3 = B0 (6x, power-on), 4/5/6 = B+1/B+2/B+3 (7x sensor gain).
module brightness_key_ctrl #(
    parameter integer DEBOUNCE_CYCLES = 240000,      // 10 ms at 24 MHz
    parameter integer DOUBLE_CLICK_CYCLES = 7200000  // 300 ms at 24 MHz
) (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_key_n,
    output reg  [2:0]  O_level,
    output reg         O_direction_up,
    output reg  [15:0] O_gain_target
);
    localparam [1:0] IDLE = 2'd0, FIRST_DOWN = 2'd1,
                     WAIT_SECOND = 2'd2, SECOND_DOWN = 2'd3;

    reg key_meta, key_sync, key_stable;
    reg [17:0] debounce_count;
    reg [22:0] click_count;
    reg [1:0] click_state;
    wire stable_change = key_sync != key_stable &&
                         debounce_count == DEBOUNCE_CYCLES - 1;
    wire pressed = stable_change && !key_sync;
    wire released = stable_change && key_sync;

    always @* begin
        O_gain_target = (O_level <= 3'd3) ? 16'd96 : 16'd104;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
            key_stable <= 1'b1;
            debounce_count <= 18'd0;
            click_count <= 23'd0;
            click_state <= IDLE;
            O_level <= 3'd3;
            O_direction_up <= 1'b1;
        end else begin
            key_meta <= I_key_n;
            key_sync <= key_meta;
            if (key_sync == key_stable)
                debounce_count <= 18'd0;
            else if (stable_change) begin
                debounce_count <= 18'd0;
                key_stable <= key_sync;
            end else
                debounce_count <= debounce_count + 18'd1;

            case (click_state)
                IDLE: begin
                    click_count <= 23'd0;
                    if (pressed) click_state <= FIRST_DOWN;
                end
                FIRST_DOWN: begin
                    if (released) begin
                        click_state <= WAIT_SECOND;
                        click_count <= 23'd0;
                    end
                end
                WAIT_SECOND: begin
                    if (pressed) begin
                        O_direction_up <= ~O_direction_up;
                        click_state <= SECOND_DOWN;
                    end else if (click_count == DOUBLE_CLICK_CYCLES - 1) begin
                        if (O_direction_up && O_level < 3'd6)
                            O_level <= O_level + 3'd1;
                        else if (!O_direction_up && O_level > 3'd0)
                            O_level <= O_level - 3'd1;
                        click_state <= IDLE;
                    end else
                        click_count <= click_count + 23'd1;
                end
                SECOND_DOWN: begin
                    if (released) click_state <= IDLE;
                end
            endcase
        end
    end
endmodule
