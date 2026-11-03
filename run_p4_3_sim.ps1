$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sim = Join-Path $root 'sim'
$vlib = 'D:\software\Modelsim\win64\vlib.exe'
$vlog = 'D:\software\Modelsim\win64\vlog.exe'
$vsim = 'D:\software\Modelsim\win64\vsim.exe'
foreach ($exe in @($vlib,$vlog,$vsim)) {
    if (!(Test-Path -LiteralPath $exe)) { throw "Missing simulator: $exe" }
}
Push-Location $sim
try {
    if (!(Test-Path -LiteralPath 'work_p43_sensor')) { & $vlib work_p43_sensor | Out-Null }
    & $vlog -work work_p43_sensor `
        '../user_source/hdl_source/app_video/rgb_to_gray.v' `
        '../user_source/hdl_source/app_video/edge_gradient.v' `
        '../user_source/hdl_source/app_video/video_fx_pipeline.v' `
        '../user_source/hdl_source/app_video/raw_tone_display.v' `
        '../user_source/hdl_source/app_video/raw_tone_mode_select.v' `
        '../user_source/hdl_source/app_video/mode_key_ctrl.v' `
        '../user_source/hdl_source/app_video/brightness_key_ctrl.v' `
        '../user_source/hdl_source/app_video/auto_exposure_ctrl.v' `
        '../user_source/hdl_source/app_detect/color_card_detect.v' `
        '../user_source/hdl_source/app_detect/shape_classify.v' `
        '../user_source/hdl_source/app_detect/conveyor_cross_count.v' `
        '../user_source/hdl_source/app_detect/diag_key_ctrl.v' `
        '../user_source/hdl_source/app_detect/motion_key_ctrl.v' `
        '../user_source/hdl_source/app_detect/three_frame_motion_serial.v' `
        '../user_source/hdl_source/app_osd/motion_overlay.v' `
        '../user_source/hdl_source/app_osd/bbox_overlay.v' `
        '../user_source/hdl_source/app_osd/shape_label_overlay.v' `
        '../user_source/hdl_source/app_osd/conveyor_count_overlay.v' `
        '../user_source/hdl_source/app_osd/color_diag_overlay.v' `
        '../user_source/hdl_source/osd_overlay.v' `
        '../user_source/hdl_source/app_osd/logo_rom.v' `
        '../user_source/hdl_source/app_osd/logo_overlay.v' `
        '../user_source/hdl_source/app_osd/mode_status_overlay.v' `
        '../user_source/hdl_source/app_osd/frame_buffer_lag.v' `
        '../user_source/hdl_source/app_osd/frame_lag_overlay.v' `
        '../user_source/hdl_source/app_osd/video_metrics_counter.v' `
        '../user_source/hdl_source/app_osd/video_metrics_overlay.v' `
        '../user_source/hdl_source/uics500_cfg/uics500reg_720p60.v' `
        '../user_source/hdl_source/uics500_cfg/SC500GainTbl.v' `
        '../user_source/hdl_source/uiisp_beta/ae_set.v' `
        'tb_color_card_detect.v' 'tb_color_card_6x_noise.v' 'tb_shape_classify.v' 'tb_shape_label_overlay.v' 'tb_conveyor_cross_count.v' 'tb_conveyor_count_overlay.v' 'tb_bbox_overlay.v' 'tb_track_coordinates.v' 'tb_color_diag_overlay.v' 'tb_diag_key_ctrl.v' 'tb_motion_key_ctrl.v' 'tb_auto_exposure_ctrl.v' 'tb_auto_exposure_apply.v' 'tb_sensor_gain_regs.v' 'tb_brightness_key_ctrl.v' 'tb_p3_osd.v' 'tb_p3_video.v' 'tb_mode_box_key.v' 'tb_raw_tone_display.v' 'tb_raw_tone_mode_select.v' 'tb_brightplus3.v' 'tb_frame_buffer_lag.v' 'tb_frame_lag_overlay.v' 'tb_video_metrics_counter.v' 'tb_video_metrics_overlay.v' 'tb_three_frame_motion.v' 'tb_motion_components.v' 'tb_motion_blank_budget.v' 'tb_motion_overlay.v'
    if ($LASTEXITCODE -ne 0) { throw 'ModelSim vlog failed' }
    foreach ($test in @('tb_color_card_detect','tb_color_card_6x_noise','tb_shape_classify','tb_shape_label_overlay','tb_conveyor_cross_count','tb_bbox_overlay','tb_track_coordinates','tb_color_diag_overlay','tb_motion_key_ctrl','tb_auto_exposure_ctrl','tb_auto_exposure_apply','tb_sensor_gain_regs','tb_brightness_key_ctrl','tb_p3_osd','tb_p3_video','tb_mode_box_key','tb_raw_tone_display','tb_raw_tone_mode_select','tb_brightplus3','tb_frame_buffer_lag','tb_frame_lag_overlay','tb_video_metrics_counter','tb_video_metrics_overlay','tb_three_frame_motion','tb_motion_components','tb_motion_blank_budget','tb_motion_overlay','tb_diag_key_ctrl')) {
        $log = & $vsim -c -lib work_p43_sensor $test -do 'run -all; quit -f' 2>&1
        if ($LASTEXITCODE -ne 0 -or !(($log | Out-String) -match "PASS $test")) {
            $log | Out-Host
            throw "ModelSim $test failed"
        }
        Write-Host "PASS $test"
    }
} finally {
    Pop-Location
}
