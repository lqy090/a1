/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2023/03/23
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/
/*********ae_set �ֶ��������AE ***********
--�汾��1.0
*********************************************************************/

module ae_set
(
input wire I_clk,
input wire I_rst,
input wire [3:0]I_btn,
input wire [15:0] I_gain_target,
input wire I_auto_enable,
input wire I_auto_update_toggle,
input wire [15:0] I_auto_exposure,
input wire I_auto_gain_boost,
input wire I_ae_cfg_done,
input wire I_cam_cfg_done,
output wire O_ae_req,
output wire [15:0] O_ae,
output wire [15:0] O_ag
);
	

reg 	[19:0] 	rc_ae_tick = 0; 
reg 			r_ae_tick = 0; 
reg 	[4:0] 	rc_ag_tick = 0; 
reg 			r_ag_tick = 0; 
	
always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		rc_ae_tick <= 0; 
		r_ae_tick <= 0; 
		rc_ag_tick <= 0; 
		r_ag_tick <= 0; 
	end else begin
	//	Trigger AE Inc / Dec per 1 ms. 
		rc_ae_tick <= rc_ae_tick + 1; 
		r_ae_tick <= 0; 
		if(rc_ae_tick >= 99999) begin
			rc_ae_tick <= 0; 
			r_ae_tick <= 1; 
		end 
	//	Trigger AG Inc / Dec per 32 ms. 
		rc_ag_tick <= rc_ag_tick + r_ae_tick; 
		r_ag_tick <= (&rc_ag_tick) && r_ae_tick; 
	end
end
	
//	Use button to add / sub idelay values. I_button[0]:IncDatDly, [1]DecDatDly, [2]IncI_clkDly, [3]DecI_clkDly
reg 	[3:0] 	r_button_0 = 0, r_button_1 = 0; 
// Update data remains unchanged for at least eight video frames. Synchronize
// its toggle and sample the bus only after the toggle has crossed this domain.
reg auto_meta=0, auto_sync=0;
reg auto_sync_d=0;
reg update_meta=0, update_sync=0, update_d=0;
reg [15:0] auto_exposure_latched=16'd1990;
reg auto_gain_boost_latched=0;
always @(posedge I_clk or posedge I_rst) begin
    if (I_rst) begin
        auto_meta<=0; auto_sync<=0; auto_sync_d<=0;
        update_meta<=0; update_sync<=0; update_d<=0;
        auto_exposure_latched<=16'd1990;
        auto_gain_boost_latched<=0;
    end else begin
        auto_meta<=I_auto_enable;
        auto_sync<=auto_meta;
        auto_sync_d<=auto_sync;
        update_meta<=I_auto_update_toggle;
        update_sync<=update_meta;
        update_d<=update_sync;
        if (update_sync != update_d) begin
            auto_exposure_latched<=I_auto_exposure;
            auto_gain_boost_latched<=I_auto_gain_boost;
        end
    end
end
// 720p60 uses VTS=1000. Exposure is expressed in half-line units, so 1990
// is the legal maximum. AG=96 maps to 0x0f30 (6x analog gain).
reg 	[15:0] 	r_ae_set = 1990, r_ag_set = 96; 
always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_button_0 <= 0; 
		r_button_1 <= 0; 
		r_ae_set <= 1990; 
		r_ag_set <= 96; 
	end else begin
	//	When button pressed, r_button_1 bit is 1. 
		r_button_0 <= ~I_btn; 
		r_button_1 <= r_button_0; 
	
		if (auto_sync) begin
			r_ae_set <= auto_exposure_latched;
		end else if (auto_sync_d) begin
			// Restore the validated manual baseline after AUTO is switched off.
			r_ae_set <= 16'd1990;
		end
		if (!auto_sync && !auto_sync_d && r_button_1[0]) begin
			r_ae_set <= (r_ae_set > 2) ? r_ae_set - r_ae_tick : r_ae_set; 
		end else if(!auto_sync && !auto_sync_d && r_button_1[1]) begin
			r_ae_set <= (r_ae_set < 1990) ? r_ae_set + r_ae_tick : r_ae_set; 
		end 
		// KEY1 selects one of three validated sensor gain settings. The old
		// extension-port gain buttons no longer override the selected level.
		r_ag_set <= (auto_sync && auto_gain_boost_latched &&
		             I_gain_target < 16'd104) ? 16'd104 : I_gain_target;
		end
	end
	
//	Update AG / AE when changed. 
reg 	[15:0] 	r_ae ; 
reg 	[15:0] 	r_ag ; 
reg 			r_ae_req = 0; //synthesis keep
assign O_ae = r_ae;
assign O_ag = r_ag;
assign O_ae_req = r_ae_req;

always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_ae_req <= 0; 
		r_ae     <= 1990; 
		r_ag     <= 96; 
	end else if(r_ae_req) begin
		r_ae_req <= 0; 
	end else if(((r_ae != r_ae_set) || (r_ag != r_ag_set))&&(I_cam_cfg_done==1'b1)&&(I_ae_cfg_done==1'b1)) begin
		r_ae     <= r_ae_set; 
		r_ag     <= r_ag_set; 
		r_ae_req <= 1; 
	end
end


endmodule


	
