

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    inout wire [1:0]  I_button,
    input wire        I_mode_key_n,
    input wire        I_diag_key_n,
    input wire        I_brightness_key_n,
    input wire        I_count_key_n,

    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);

    // Calibrate this fixed gate to stationary marks on the conveyor frame.
    // Both the counting logic and HDMI line use these same coordinates.
    localparam [10:0] COUNT_LINE_X = 11'd800;
    localparam [10:0] COUNT_BELT_Y0 = 11'd140;
    localparam [10:0] COUNT_BELT_Y1 = 11'd620;


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
    wire [2:0]      S_brightness_level;
    wire            S_brightness_up;
    wire [15:0]     S_brightness_gain;
    wire            S_auto_enable;
    reg             S_auto_enable_24_meta, S_auto_enable_24;
    wire [15:0]     S_auto_exposure;
    wire            S_auto_gain_boost, S_auto_update_toggle;
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;
    wire[2:0]   S_video_mode;
    wire        S_fx_vsync, S_fx_hsync, S_fx_de;
    wire[23:0]  S_fx_data;
    wire        S_tone_vsync, S_tone_hsync, S_tone_de;
    wire[23:0]  S_tone_data;
    wire        S_card_valid;
    wire[2:0]   S_card_color;
    wire        S_box_enable;
    wire[10:0]  S_card_x0, S_card_y0, S_card_x1, S_card_y1;
    wire[19:0]  S_red_pixels, S_blue_pixels;
    wire[3:0]   S_shape_mask;
    wire        S_shape_valid;
    wire[2:0]   S_shape_color, S_shape;
    wire        S_motion_enable;
    wire [4:0]  S_motion_box_count;
    wire [415:0] S_motion_boxes;
    wire        S_motion_overflow;
    wire        S_gamma_enable;
    wire        S_box_vsync, S_box_hsync, S_box_de;
    wire[23:0]  S_box_data;
    wire        S_track_valid;
    wire[2:0]   S_track_color;
    wire[10:0]  S_track_x0, S_track_y0;
    wire[10:0]  S_track_x1, S_track_y1;
    wire        S_count_enable;
    wire[127:0] S_counts;
    wire        S_diag_vsync, S_diag_hsync, S_diag_de;
    wire[23:0]  S_diag_data;
    wire        S_osd_vsync;
    wire        S_osd_hsync;
    wire        S_osd_de;
    wire[23:0]  S_osd_data;
    wire        S_logo_vsync, S_logo_hsync, S_logo_de;
    wire[23:0]  S_logo_data;
    wire        S_status_vsync, S_status_hsync, S_status_de;
    wire[23:0]  S_status_data;
    wire        S_lag_vsync, S_lag_hsync, S_lag_de;
    wire[23:0]  S_lag_data;
    wire        S_capture_frame_start_ddr, S_display_frame_start_ddr;
    wire[1:0]   S_write_slot, S_read_slot;
    wire[3:0]   S_lag_frames;
    wire[6:0]   S_latency_ms;
    wire        S_lag_valid;
    wire[6:0]   S_capture_latency_ms;
    wire        S_capture_latency_valid;
    wire[11:0]  S_cam_fps_bcd, S_hdmi_fps_bcd;
    wire        S_fps_valid;
    wire[15:0]  S_width_bcd, S_height_bcd;
    wire        S_size_valid;
    wire        S_metrics_vsync, S_metrics_hsync, S_metrics_de;
    wire[23:0]  S_metrics_data;
    wire        S_shape_osd_vsync, S_shape_osd_hsync, S_shape_osd_de;
    wire[23:0]  S_shape_osd_data;
    wire        S_count_osd_vsync, S_count_osd_hsync, S_count_osd_de;
    wire[23:0]  S_count_osd_data;
    wire        S_motion_osd_vsync, S_motion_osd_hsync, S_motion_osd_de;
    wire[23:0]  S_motion_osd_data;
    wire [7:0]  S_display_frame_id;
    wire        S_display_frame_id_valid;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;


    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status = {
        (|S_ddr_user_rd_data),
        S_ddr_user_rd_valid,
        S_vo_ddr_rd_en,
        S_vi_ddr_wr_en
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
  always @(posedge S_24m_clk or negedge S_rst_n) begin
      if (!S_rst_n) begin
          S_auto_enable_24_meta <= 1'b0;
          S_auto_enable_24 <= 1'b0;
      end else begin
          S_auto_enable_24_meta <= S_auto_enable;
          S_auto_enable_24 <= S_auto_enable_24_meta;
      end
  end
  brightness_key_ctrl u_brightness_key_ctrl (
      .I_clk(S_24m_clk),
      .I_rst_n(S_rst_n),
      .I_key_n(I_brightness_key_n | S_auto_enable_24),
      .O_level(S_brightness_level),
      .O_direction_up(S_brightness_up),
      .O_gain_target(S_brightness_gain)
  );

  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn({I_button,2'b11}),
      .I_gain_target(S_brightness_gain),
      .I_auto_enable(S_auto_enable),
      .I_auto_update_toggle(S_auto_update_toggle),
      .I_auto_exposure(S_auto_exposure),
      .I_auto_gain_boost(S_auto_gain_boost),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );
  
    // SC500CS factory HD mode: 1280x720@60, RAW10, 2-Lane, 480 Mbps/Lane.
    uicfgcs500_720p #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// The sensor already produces a real 1280x720 frame.  Do not pass it through
// the legacy fixed 1024x600 image_correction crop; keep line/frame markers
// aligned with the factory sensor output.
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP算法顶层模块
isp_top #(.EDGE_ENABLE(0)) u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        ()
  );


    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),
        .O_frame_start_ddr    ( S_capture_frame_start_ddr ),
        .O_write_slot        ( S_write_slot          ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
        .O_display_start_ddr ( S_display_frame_start_ddr ),
        .O_read_slot         ( S_read_slot          ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( 1280 ),
        .IMG_HEIGHT ( 720  ),
        .DEBUG_MODE ( 0    )
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );

    mode_key_ctrl u_mode_key_ctrl(
        .I_clk   ( S_hdmi_pixel_clk ),
        .I_rst_n ( S_hdmi_rst_n     ),
        .I_key_n ( I_mode_key_n     ),
        .I_vsync ( S_hdmi_out_vsync ),
        .O_mode  ( S_video_mode     ),
        .O_box_enable ( S_box_enable )
    );

    video_fx_pipeline u_video_fx_pipeline(
        .I_clk   ( S_hdmi_pixel_clk ),
        .I_rst_n ( S_hdmi_rst_n     ),
        .I_vsync ( S_hdmi_out_vsync ),
        .I_hsync ( S_hdmi_out_hsync ),
        .I_de    ( S_hdmi_out_de    ),
        .I_rgb   ( S_hdmi_out_data  ),
        .I_mode  ( S_video_mode     ),
        .I_gamma_enable ( S_gamma_enable ),
        .O_vsync ( S_fx_vsync       ),
        .O_hsync ( S_fx_hsync       ),
        .O_de    ( S_fx_de          ),
        .O_rgb   ( S_fx_data        )
    );

    raw_tone_mode_select u_raw_tone_mode_select(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_fx_vsync), .I_hsync(S_fx_hsync),
        .I_de(S_fx_de), .I_rgb(S_fx_data), .I_mode(S_video_mode),
        .I_brightness_level(S_brightness_level),
        .O_vsync(S_tone_vsync), .O_hsync(S_tone_hsync),
        .O_de(S_tone_de), .O_rgb(S_tone_data)
    );

    // Detect from the original RGB stream, so GRAY/BIN/EDGE display modes
    // cannot change the colour classifier's input.
    color_card_detect u_color_card_detect(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_hdmi_out_vsync), .I_de(S_hdmi_out_de),
        .I_rgb(S_hdmi_out_data),
        .O_valid(S_card_valid), .O_color(S_card_color),
        .O_red_pixels(S_red_pixels), .O_blue_pixels(S_blue_pixels),
        .O_x0(S_card_x0), .O_y0(S_card_y0),
        .O_x1(S_card_x1), .O_y1(S_card_y1),
        .O_shape_mask(S_shape_mask)
    );

    shape_classify u_shape_classify(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_hdmi_out_vsync), .I_de(S_hdmi_out_de),
        .I_mask(S_shape_mask),
        .I_target_valid(S_card_valid), .I_target_color(S_card_color),
        .I_x0(S_card_x0), .I_y0(S_card_y0),
        .I_x1(S_card_x1), .I_y1(S_card_y1),
        .O_valid(S_shape_valid), .O_color(S_shape_color),
        .O_shape(S_shape)
    );

    motion_key_ctrl u_motion_key_ctrl(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_key_n(I_diag_key_n), .I_vsync(S_hdmi_out_vsync),
        .O_enable(S_motion_enable), .O_auto_enable(S_auto_enable)
    );
    auto_exposure_ctrl u_auto_exposure_ctrl(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_hdmi_out_vsync), .I_de(S_hdmi_out_de),
        .I_rgb(S_hdmi_out_data), .I_enable(S_auto_enable),
        .O_exposure(S_auto_exposure),
        .O_gain_boost(S_auto_gain_boost),
        .O_update_toggle(S_auto_update_toggle)
    );
    assign S_gamma_enable = 1'b0;

    three_frame_motion_serial u_three_frame_motion(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_hdmi_out_vsync), .I_de(S_hdmi_out_de),
        .I_rgb(S_hdmi_out_data), .I_enable(S_motion_enable),
        .I_brightness_level(S_brightness_level),
        .I_exposure_epoch(S_auto_update_toggle),
        .I_frame_id(S_display_frame_id),
        .I_frame_id_valid(S_display_frame_id_valid),
        .O_box_count(S_motion_box_count), .O_boxes(S_motion_boxes),
        .O_overflow(S_motion_overflow)
    );

    bbox_overlay u_bbox_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_tone_vsync), .I_hsync(S_tone_hsync),
        .I_de(S_tone_de), .I_rgb(S_tone_data),
        .I_enable(S_box_enable),
        .I_valid(S_card_valid), .I_color(S_card_color),
        .I_x0(S_card_x0), .I_y0(S_card_y0),
        .I_x1(S_card_x1), .I_y1(S_card_y1),
        .O_track_valid(S_track_valid), .O_track_color(S_track_color),
        .O_track_x0(S_track_x0), .O_track_y0(S_track_y0),
        .O_track_x1(S_track_x1), .O_track_y1(S_track_y1),
        .O_vsync(S_box_vsync), .O_hsync(S_box_hsync),
        .O_de(S_box_de), .O_rgb(S_box_data)
    );

    color_diag_overlay u_color_diag_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_box_vsync), .I_hsync(S_box_hsync),
        .I_de(S_box_de), .I_rgb(S_box_data),
        .I_raw_rgb(S_hdmi_out_data),
        .I_mask_enable(1'b0),
        .I_hide_panel(S_count_enable),
        .I_red_pixels(S_red_pixels), .I_blue_pixels(S_blue_pixels),
        .O_vsync(S_diag_vsync), .O_hsync(S_diag_hsync),
        .O_de(S_diag_de), .O_rgb(S_diag_data)
    );

    osd_overlay u_osd_overlay(
        .I_clk   ( S_hdmi_pixel_clk ),
        .I_rst_n ( S_hdmi_rst_n    ),
        .I_vsync ( S_diag_vsync     ),
        .I_hsync ( S_diag_hsync     ),
        .I_de    ( S_diag_de        ),
        .I_data  ( S_diag_data      ),
        .O_vsync ( S_osd_vsync      ),
        .O_hsync ( S_osd_hsync      ),
        .O_de    ( S_osd_de         ),
        .O_data  ( S_osd_data       )
    );

    logo_overlay u_logo_overlay(
        .I_clk   ( S_hdmi_pixel_clk ),
        .I_rst_n ( S_hdmi_rst_n     ),
        .I_vsync ( S_osd_vsync      ),
        .I_hsync ( S_osd_hsync      ),
        .I_de    ( S_osd_de         ),
        .I_rgb   ( S_osd_data       ),
        .O_vsync ( S_logo_vsync     ),
        .O_hsync ( S_logo_hsync     ),
        .O_de    ( S_logo_de        ),
        .O_rgb   ( S_logo_data      )
    );

    mode_status_overlay u_mode_status_overlay(
        .I_clk   ( S_hdmi_pixel_clk ),
        .I_rst_n ( S_hdmi_rst_n     ),
        .I_vsync ( S_logo_vsync     ),
        .I_hsync ( S_logo_hsync     ),
        .I_de    ( S_logo_de        ),
        .I_rgb   ( S_logo_data      ),
        .I_mode  ( S_video_mode     ),
        .I_gamma_enable ( S_gamma_enable ),
        .I_mask_enable ( 1'b0 ),
        .I_box_enable ( S_box_enable ),
        .I_brightness_level ( S_brightness_level ),
        .I_brightness_up ( S_brightness_up ),
        .I_auto_enable ( S_auto_enable ),
        .O_vsync ( S_status_vsync   ),
        .O_hsync ( S_status_hsync   ),
        .O_de    ( S_status_de      ),
        .O_rgb   ( S_status_data    )
    );

    frame_buffer_lag u_frame_buffer_lag(
        .I_cam_clk(S_csi_rx_clk), .I_cam_rst_n(S_rst_n),
        .I_mipi_frame_start(S_csi_frame_start),
        .I_ddr_clk(S_ddr_clk), .I_ddr_rst_n(S_rst_n),
        .I_camera_frame_start(S_capture_frame_start_ddr),
        .I_write_slot(S_write_slot),
        .I_display_frame_start(S_display_frame_start_ddr),
        .I_read_slot(S_read_slot),
        .I_hdmi_de(S_metrics_de),
        .I_pixel_clk(S_hdmi_pixel_clk), .I_pixel_rst_n(S_hdmi_rst_n),
        .O_lag_frames(S_lag_frames), .O_latency_ms(S_latency_ms),
        .O_valid(S_lag_valid),
        .O_capture_latency_ms(S_capture_latency_ms),
        .O_capture_valid(S_capture_latency_valid),
        .O_display_frame_id(S_display_frame_id),
        .O_display_frame_id_valid(S_display_frame_id_valid)
    );

    frame_lag_overlay u_frame_lag_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_status_vsync), .I_hsync(S_status_hsync),
        .I_de(S_status_de), .I_rgb(S_status_data),
        .I_lag_frames(S_lag_frames), .I_latency_ms(S_latency_ms),
        .I_lag_valid(S_lag_valid),
        .I_capture_latency_ms(S_capture_latency_ms),
        .I_capture_valid(S_capture_latency_valid),
        .O_vsync(S_lag_vsync), .O_hsync(S_lag_hsync),
        .O_de(S_lag_de), .O_rgb(S_lag_data)
    );

    video_metrics_counter u_video_metrics_counter(
        .I_sys_clk(I_sys_clk), .I_cam_clk(S_csi_rx_clk),
        .I_pixel_clk(S_hdmi_pixel_clk), .I_rst_n(S_rst_n),
        .I_cam_frame_start(S_csi_frame_start),
        .I_hdmi_vsync(S_hdmi_out_vsync), .I_hdmi_de(S_hdmi_out_de),
        .O_cam_fps_bcd(S_cam_fps_bcd),
        .O_hdmi_fps_bcd(S_hdmi_fps_bcd), .O_fps_valid(S_fps_valid),
        .O_width_bcd(S_width_bcd), .O_height_bcd(S_height_bcd),
        .O_size_valid(S_size_valid)
    );

    video_metrics_overlay u_video_metrics_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_lag_vsync), .I_hsync(S_lag_hsync),
        .I_de(S_lag_de), .I_rgb(S_lag_data),
        .I_cam_fps_bcd(S_cam_fps_bcd),
        .I_hdmi_fps_bcd(S_hdmi_fps_bcd), .I_fps_valid(S_fps_valid),
        .I_width_bcd(S_width_bcd), .I_height_bcd(S_height_bcd),
        .I_size_valid(S_size_valid),
        .O_vsync(S_metrics_vsync), .O_hsync(S_metrics_hsync),
        .O_de(S_metrics_de), .O_rgb(S_metrics_data)
    );

    shape_label_overlay u_shape_label_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_metrics_vsync), .I_hsync(S_metrics_hsync),
        .I_de(S_metrics_de), .I_rgb(S_metrics_data),
        .I_enable(S_box_enable),
        .I_target_valid(S_track_valid), .I_target_color(S_track_color),
        .I_x0(S_track_x0), .I_y0(S_track_y0),
        .I_shape_valid(S_shape_valid), .I_shape_color(S_shape_color),
        .I_shape(S_shape),
        .O_vsync(S_shape_osd_vsync), .O_hsync(S_shape_osd_hsync),
        .O_de(S_shape_osd_de), .O_rgb(S_shape_osd_data)
    );

    conveyor_cross_count #(
        .LINE_X(COUNT_LINE_X), .BELT_Y0(COUNT_BELT_Y0),
        .BELT_Y1(COUNT_BELT_Y1)
    ) u_conveyor_cross_count(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_key_n(I_count_key_n), .I_vsync(S_hdmi_out_vsync),
        .I_detect_enable(S_box_enable),
        .I_target_valid(S_track_valid), .I_color(S_track_color),
        .I_x0(S_track_x0), .I_y0(S_track_y0),
        .I_x1(S_track_x1), .I_y1(S_track_y1),
        .I_shape_valid(S_shape_valid), .I_shape_color(S_shape_color),
        .I_shape(S_shape),
        .O_enable(S_count_enable), .O_counts(S_counts)
    );

    conveyor_count_overlay #(
        .LINE_X(COUNT_LINE_X), .BELT_Y0(COUNT_BELT_Y0),
        .BELT_Y1(COUNT_BELT_Y1)
    ) u_conveyor_count_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_shape_osd_vsync), .I_hsync(S_shape_osd_hsync),
        .I_de(S_shape_osd_de), .I_rgb(S_shape_osd_data),
        .I_enable(S_count_enable), .I_counts(S_counts),
        .O_vsync(S_count_osd_vsync), .O_hsync(S_count_osd_hsync),
        .O_de(S_count_osd_de), .O_rgb(S_count_osd_data)
    );

    motion_overlay u_motion_overlay(
        .I_clk(S_hdmi_pixel_clk), .I_rst_n(S_hdmi_rst_n),
        .I_vsync(S_count_osd_vsync), .I_hsync(S_count_osd_hsync),
        .I_de(S_count_osd_de), .I_rgb(S_count_osd_data),
        .I_enable(S_motion_enable), .I_overflow(S_motion_overflow),
        .I_box_count(S_motion_box_count), .I_boxes(S_motion_boxes),
        .O_vsync(S_motion_osd_vsync), .O_hsync(S_motion_osd_hsync),
        .O_de(S_motion_osd_de), .O_rgb(S_motion_osd_data)
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_motion_osd_vsync   ),
        .I_video_in_de      ( S_motion_osd_de      ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_motion_osd_data    ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


    
endmodule
