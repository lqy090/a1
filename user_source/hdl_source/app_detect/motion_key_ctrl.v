// KEY4: single click toggles motion; double click toggles automatic exposure.
// Both outputs commit at the display frame boundary. A single click is
// intentionally delayed until the double-click window has elapsed.
module motion_key_ctrl #(
    parameter integer DEBOUNCE_CYCLES = 1485000,        // 20 ms @ 74.25 MHz
    parameter integer DOUBLE_CLICK_CYCLES = 22275000    // 300 ms @ 74.25 MHz
) (
    input wire I_clk, I_rst_n, I_key_n, I_vsync,
    output reg O_enable,
    output reg O_auto_enable
);
    localparam [1:0] IDLE=2'd0, FIRST_DOWN=2'd1,
                     WAIT_SECOND=2'd2, SECOND_DOWN=2'd3;
    reg key_meta, key_sync, key_stable;
    reg [20:0] stable_count;
    reg [24:0] click_count;
    reg [1:0] state;
    reg requested_motion, requested_auto, vs_d;
    wire stable_change = (key_sync != key_stable) &&
                         (stable_count == DEBOUNCE_CYCLES-1);
    wire pressed = stable_change && !key_sync;
    wire released = stable_change && key_sync;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            key_meta<=1; key_sync<=1; key_stable<=1;
            stable_count<=0; click_count<=0; state<=IDLE;
            requested_motion<=0; requested_auto<=0; vs_d<=0;
            O_enable<=0; O_auto_enable<=0;
        end else begin
            key_meta<=I_key_n;
            key_sync<=key_meta;
            vs_d<=I_vsync;
            if (key_sync == key_stable) stable_count<=0;
            else if (stable_change) begin
                stable_count<=0;
                key_stable<=key_sync;
            end else stable_count<=stable_count+21'd1;

            case (state)
                IDLE: begin
                    click_count<=0;
                    if (pressed) state<=FIRST_DOWN;
                end
                FIRST_DOWN: if (released) begin
                    state<=WAIT_SECOND;
                    click_count<=0;
                end
                WAIT_SECOND: begin
                    if (pressed) begin
                        requested_auto<=~requested_auto;
                        state<=SECOND_DOWN;
                    end else if (click_count == DOUBLE_CLICK_CYCLES-1) begin
                        requested_motion<=~requested_motion;
                        state<=IDLE;
                    end else click_count<=click_count+25'd1;
                end
                SECOND_DOWN: if (released) state<=IDLE;
            endcase
            if (I_vsync && !vs_d) begin
                O_enable<=requested_motion;
                O_auto_enable<=requested_auto;
            end
        end
    end
endmodule
