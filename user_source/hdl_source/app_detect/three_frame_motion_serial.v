// Three-frame motion detector. Capture is streamed; component labelling runs
// sequentially during vertical blank, preserving the original 16x16 grid.
module three_frame_motion_serial #(
    parameter integer WIDTH=1280, HEIGHT=720,
    parameter integer GRID_W=WIDTH/16, GRID_H=HEIGHT/16,
    parameter integer DIFF_THRESHOLD=7,
    parameter integer MIN_AREA_TILES=3,
    parameter integer MAX_LABELS=128,
    parameter integer MAX_BOXES=16,
    parameter integer GLOBAL_CHANGE_LIMIT=900
) (
    input wire I_clk, I_rst_n, I_vsync, I_de,
    input wire [23:0] I_rgb,
    input wire I_enable,
    input wire [2:0] I_brightness_level,
    input wire I_exposure_epoch,
    input wire [7:0] I_frame_id,
    input wire I_frame_id_valid,
    output reg [4:0] O_box_count,
    output reg [MAX_BOXES*26-1:0] O_boxes,
    output reg O_overflow
);
    reg [10:0] x,y;
    reg de_d,vs_d,enable_d;
    reg [7:0] last_frame_id;
    reg have_frame_id,active_new;
    reg [1:0] history_count;
    reg [2:0] last_brightness;
    reg last_exposure_epoch;
    reg [15:0] column_sum [0:GRID_W-1];
    reg [15:0] tile_sum;
    reg [7:0] older [0:GRID_W*GRID_H-1];
    reg [7:0] recent [0:GRID_W*GRID_H-1];
    reg [1:0] motion_mask [0:GRID_W*GRID_H-1];
    reg [7:0] older_q,recent_q;
    wire [9:0] weighted_luma={2'b0,I_rgb[23:16]}+
                              {1'b0,I_rgb[15:8],1'b0}+
                              {2'b0,I_rgb[7:0]};
    wire [7:0] luma=weighted_luma[9:2];
    wire [6:0] tx=x[10:4];
    wire [5:0] ty=y[9:4];
    wire [11:0] tile_addr=(GRID_W==80) ?
                           (({6'd0,ty}<<6)+({6'd0,ty}<<4)+tx) :
                           (ty*GRID_W+tx);
    wire [15:0] completed_sum=tile_sum+{8'd0,luma};
    wire [7:0] tile_luma=completed_sum[15:8];
    wire [7:0] d_now=tile_luma>=recent_q ?
                       tile_luma-recent_q : recent_q-tile_luma;
    wire [7:0] d_old=recent_q>=older_q ?
                       recent_q-older_q : older_q-recent_q;
    wire in_roi=tx>=7'd2 && tx<GRID_W-2 && ty>=6'd2 && ty<GRID_H-2;
    wire support=history_count==2'd3 && in_roi &&
                 (d_now>DIFF_THRESHOLD || d_old>DIFF_THRESHOLD);
    wire seed=support && d_now>DIFF_THRESHOLD && d_old>DIFF_THRESHOLD;
    reg [11:0] changed_tiles;

    // An entry is {has_seed, saturated_area[1:0], max_y[5:0],
    // min_y[5:0], max_x[6:0], min_x[6:0]}.
    reg [28:0] stats [0:MAX_LABELS-1];
    reg [28:0] stats_rdata;
    reg [7:0] parent [0:MAX_LABELS-1];
    reg [7:0] row_a [0:GRID_W-1];
    reg [7:0] row_b [0:GRID_W-1];
    reg [7:0] left_label;
    reg [7:0] label_count;
    reg label_overflow;
    reg [11:0] scan_addr;
    reg [6:0] scan_x;
    reg [5:0] scan_y;
    reg [1:0] mask_q;
    reg support_q,seed_q;
    reg [7:0] n_left,n_up,n_ul,n_ur,n_min;
    reg [1:0] union_i;
    reg [7:0] root_a,root_b;
    reg [28:0] stat_q,child_stat_q,parent_stat_q;
    reg [7:0] merge_i,merge_parent_q,select_i,select_parent_q;
    reg [7:0] final_label_count;
    wire [7:0] left_now=scan_x==0 ? 8'd0 : left_label;
    wire [7:0] up_now=scan_y==0 ? 8'd0 :
                      (scan_y[0] ? row_a[scan_x] : row_b[scan_x]);
    wire [7:0] ul_now=(scan_y==0 || scan_x==0) ? 8'd0 :
                      (scan_y[0] ? row_a[scan_x-1'b1] : row_b[scan_x-1'b1]);
    wire [7:0] ur_now=(scan_y==0 || scan_x==GRID_W-1) ? 8'd0 :
                      (scan_y[0] ? row_a[scan_x+1'b1] : row_b[scan_x+1'b1]);
    function [7:0] nonzero_min;
        input [7:0] a,b;
        begin
            if (a==0) nonzero_min=b;
            else if (b==0) nonzero_min=a;
            else nonzero_min=a<b?a:b;
        end
    endfunction
    wire [7:0] neighbour_now=nonzero_min(nonzero_min(left_now,up_now),
                                          nonzero_min(ul_now,ur_now));
    wire [7:0] union_candidate=union_i==0 ? n_left :
                                union_i==1 ? n_up :
                                union_i==2 ? n_ul : n_ur;
    function [6:0] min7; input [6:0] a,b; begin min7=a<b?a:b; end endfunction
    function [6:0] max7; input [6:0] a,b; begin max7=a>b?a:b; end endfunction
    function [5:0] min6; input [5:0] a,b; begin min6=a<b?a:b; end endfunction
    function [5:0] max6; input [5:0] a,b; begin max6=a>b?a:b; end endfunction
    function [1:0] area_add;
        input [1:0] a,b;
        reg [2:0] sum;
        begin sum={1'b0,a}+{1'b0,b}; area_add=sum>=3 ? 2'd3 : sum[1:0]; end
    endfunction
    function [28:0] add_tile;
        input [28:0] a;
        input [6:0] px;
        input [5:0] py;
        input is_seed;
        begin
            add_tile={a[28]|is_seed,area_add(a[27:26],2'd1),
                      max6(a[25:20],py),min6(a[19:14],py),
                      max7(a[13:7],px),min7(a[6:0],px)};
        end
    endfunction
    function [28:0] merge_stats;
        input [28:0] a,b;
        begin
            merge_stats={a[28]|b[28],area_add(a[27:26],b[27:26]),
                         max6(a[25:20],b[25:20]),min6(a[19:14],b[19:14]),
                         max7(a[13:7],b[13:7]),min7(a[6:0],b[6:0])};
        end
    endfunction

    localparam [3:0] IDLE=0,FETCH=1,NEIGH=2,LOOK=3,UPDATE=4,
                     UNION=5,NEXT=6,MERGE_A=7,MERGE_B=8,MERGE_C=9,
                     MERGE_D=10,SELECT_A=11,SELECT_B=12,
                     ROOT_A=13,ROOT_B=14,LINK=15;
    reg [3:0] state;
    wire [7:0] stats_raddr=state==NEIGH ? neighbour_now :
                           state==MERGE_A ? merge_i :
                           state==MERGE_B ? merge_parent_q : select_i;
    wire stats_we=(state==LOOK && support_q && n_min==0 &&
                   label_count<MAX_LABELS) ||
                  state==UPDATE ||
                  (state==MERGE_D && merge_parent_q!=merge_i);
    wire [7:0] stats_waddr=state==LOOK ? label_count :
                            state==UPDATE ? n_min : merge_parent_q;
    wire [28:0] stats_wdata=state==LOOK ?
                         {seed_q,2'd1,scan_y,scan_y,scan_x,scan_x} :
                         state==UPDATE ?
                         add_tile(stat_q,scan_x,scan_y,seed_q) :
                         merge_stats(parent_stat_q,child_stat_q);
    // One synchronous read and one write allow the label statistics to use
    // embedded RAM instead of a large distributed multiport register bank.
    always @(posedge I_clk) begin
        stats_rdata<=stats[stats_raddr];
        if (stats_we) stats[stats_waddr]<=stats_wdata;
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            x<=0; y<=0; de_d<=0; vs_d<=0; enable_d<=0;
            last_frame_id<=0; have_frame_id<=0; active_new<=0;
            history_count<=0; last_brightness<=0; last_exposure_epoch<=0;
            tile_sum<=0; changed_tiles<=0;
            state<=IDLE; scan_addr<=0; scan_x<=0; scan_y<=0;
            left_label<=0; label_count<=8'd1; label_overflow<=0;
            O_box_count<=0; O_boxes<=0; O_overflow<=0;
        end else begin
            de_d<=I_de; vs_d<=I_vsync; enable_d<=I_enable;
            if (I_de && y<HEIGHT && y[3:0]==4'd15 &&
                x<WIDTH && x[3:0]==4'd12) begin
                recent_q<=recent[tile_addr];
                older_q<=older[tile_addr];
            end
            if (!I_enable) begin
                history_count<=0; have_frame_id<=0; active_new<=0;
                state<=IDLE; O_box_count<=0; O_overflow<=0;
            end else begin
                if (!enable_d) begin
                    history_count<=0; have_frame_id<=0; active_new<=0;
                    O_box_count<=0;
                end
                if (I_vsync && !vs_d) begin
                    x<=0; y<=0; active_new<=0;
                    if (active_new && history_count==2'd3) begin
                        if (changed_tiles>GLOBAL_CHANGE_LIMIT) begin
                            O_box_count<=0; O_overflow<=0;
                            state<=IDLE;
                        end else begin
                            scan_addr<=0; scan_x<=0; scan_y<=0;
                            left_label<=0; label_count<=8'd1;
                            label_overflow<=0; state<=FETCH;
                        end
                    end else if (active_new) begin
                        O_box_count<=0; O_overflow<=0;
                    end
                    changed_tiles<=0;
                end else if (de_d && !I_de) begin
                    x<=0; y<=y+11'd1;
                end else if (I_de) x<=x+11'd1;

                if (I_de && x==11'd12 && y==0) begin
                    active_new<=I_frame_id_valid &&
                                (!have_frame_id || I_frame_id!=last_frame_id);
                    if (!I_frame_id_valid) begin
                        O_box_count<=0; history_count<=0; have_frame_id<=0;
                    end else if (!have_frame_id || I_frame_id!=last_frame_id) begin
                        have_frame_id<=1; last_frame_id<=I_frame_id;
                        if (I_brightness_level!=last_brightness ||
                            I_exposure_epoch!=last_exposure_epoch) begin
                            history_count<=2'd1; O_box_count<=0;
                        end else if (history_count!=2'd3)
                            history_count<=history_count+2'd1;
                    end
                    last_brightness<=I_brightness_level;
                    last_exposure_epoch<=I_exposure_epoch;
                end
                if (I_de && x<WIDTH && y<HEIGHT) begin
                    if (x[3:0]==4'd0)
                        tile_sum<=(y[3:0]==0 ? 16'd0 : column_sum[tx])+luma;
                    else if (x[3:0]!=4'd15)
                        tile_sum<=tile_sum+luma;
                    else if (y[3:0]!=4'd15)
                        column_sum[tx]<=completed_sum;
                    else if (active_new) begin
                        older[tile_addr]<=recent_q;
                        recent[tile_addr]<=tile_luma;
                        motion_mask[tile_addr]<={seed,support};
                        if (support) changed_tiles<=changed_tiles+12'd1;
                    end
                end
                // The 720p vertical blank has about 49,500 pixel clocks.
                // Worst-case scan: 9*3600 + 3*127 + 2*127 < 34,000.
                // If a non-standard timing violates this, suppress stale boxes.
                if (I_de && x==0 && y==0 && state!=IDLE) begin
                    state<=IDLE; O_box_count<=0; O_overflow<=1;
                end else case (state)
                    IDLE: begin end
                    FETCH: begin
                        mask_q<=motion_mask[scan_addr];
                        state<=NEIGH;
                    end
                    NEIGH: begin
                        support_q<=mask_q[0]; seed_q<=mask_q[1];
                        n_left<=left_now; n_up<=up_now;
                        n_ul<=ul_now; n_ur<=ur_now;
                        n_min<=neighbour_now;
                        state<=LOOK;
                    end
                    LOOK: begin
                        if (!support_q) begin
                            if (scan_y[0]) row_b[scan_x]<=0;
                            else row_a[scan_x]<=0;
                            left_label<=0;
                            state<=NEXT;
                        end else if (n_min==0) begin
                            if (label_count<MAX_LABELS) begin
                                if (scan_y[0]) row_b[scan_x]<=label_count;
                                else row_a[scan_x]<=label_count;
                                left_label<=label_count;
                                parent[label_count]<=label_count;
                                label_count<=label_count+8'd1;
                            end else begin
                                if (scan_y[0]) row_b[scan_x]<=0;
                                else row_a[scan_x]<=0;
                                left_label<=0; label_overflow<=1;
                            end
                            state<=NEXT;
                        end else begin
                            if (scan_y[0]) row_b[scan_x]<=n_min;
                            else row_a[scan_x]<=n_min;
                            left_label<=n_min;
                            stat_q<=stats_rdata;
                            state<=UPDATE;
                        end
                    end
                    UPDATE: begin
                        union_i<=0; state<=UNION;
                    end
                    UNION: begin
                        if (union_candidate!=0 && union_candidate!=n_min) begin
                            root_a<=n_min;
                            root_b<=union_candidate;
                            state<=ROOT_A;
                        end else if (union_i==2'd3) state<=NEXT;
                        else union_i<=union_i+2'd1;
                    end
                    ROOT_A: begin
                        if (parent[root_a]!=root_a)
                            root_a<=parent[root_a];
                        else state<=ROOT_B;
                    end
                    ROOT_B: begin
                        if (parent[root_b]!=root_b)
                            root_b<=parent[root_b];
                        else state<=LINK;
                    end
                    LINK: begin
                        if (root_a<root_b) parent[root_b]<=root_a;
                        else if (root_b<root_a) parent[root_a]<=root_b;
                        if (union_i==2'd3) state<=NEXT;
                        else begin union_i<=union_i+2'd1; state<=UNION; end
                    end
                    NEXT: begin
                        if (scan_x==GRID_W-1 && scan_y==GRID_H-1) begin
                            final_label_count<=label_count;
                            if (label_count>8'd1) begin
                                merge_i<=label_count-8'd1;
                                state<=MERGE_A;
                            end else begin
                                O_box_count<=0;
                                O_overflow<=label_overflow;
                                state<=IDLE;
                            end
                        end else begin
                            scan_addr<=scan_addr+12'd1;
                            if (scan_x==GRID_W-1) begin
                                scan_x<=0; scan_y<=scan_y+6'd1;
                                left_label<=0;
                            end else scan_x<=scan_x+7'd1;
                            state<=FETCH;
                        end
                    end
                    MERGE_A: begin
                        merge_parent_q<=parent[merge_i];
                        state<=MERGE_B;
                    end
                    MERGE_B: begin
                        child_stat_q<=stats_rdata;
                        state<=MERGE_C;
                    end
                    MERGE_C: begin
                        parent_stat_q<=stats_rdata;
                        state<=MERGE_D;
                    end
                    MERGE_D: begin
                        if (merge_i==8'd1) begin
                            select_i<=8'd1; O_box_count<=0;
                            O_overflow<=label_overflow;
                            state<=SELECT_A;
                        end else begin
                            merge_i<=merge_i-8'd1; state<=MERGE_A;
                        end
                    end
                    SELECT_A: begin
                        select_parent_q<=parent[select_i];
                        state<=SELECT_B;
                    end
                    SELECT_B: begin
                        if (!O_overflow && select_parent_q==select_i &&
                            stats_rdata[28] &&
                            stats_rdata[27:26]>=MIN_AREA_TILES) begin
                            if (O_box_count<MAX_BOXES) begin
                                O_boxes[O_box_count*26 +: 26]<=
                                    {stats_rdata[25:20],stats_rdata[13:7],
                                     stats_rdata[19:14],stats_rdata[6:0]};
                                O_box_count<=O_box_count+5'd1;
                            end else begin
                                O_box_count<=0; O_overflow<=1;
                            end
                        end
                        if (select_i==final_label_count-8'd1) state<=IDLE;
                        else begin select_i<=select_i+8'd1; state<=SELECT_A; end
                    end
                    default: state<=IDLE;
                endcase
            end
        end
    end
endmodule
