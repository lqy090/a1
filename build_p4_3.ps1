# Rebuild the existing TD 6.2.1 project on this Windows workstation.
# The project file list is in td_project/camera_to_dsi_display.al; if new HDL
# files are added, add them to both the .al and generated run .prj files.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$td = 'D:\software\TD_6.2.1_Engineer\bin\td_commands_prompt.exe'
$flow = 'D:/software/TD_6.2.1_Engineer/doc/scripts/DefaultFlow.tcl'
$runs = Join-Path $root 'td_project\camera_to_dsi_display_Runs'

if (!(Test-Path -LiteralPath $td)) { throw "TD 6.2.1 not found: $td" }
foreach ($stage in @('syn_1', 'phy_1')) {
    $runDir = Join-Path $runs $stage
    $cfg = Join-Path $runDir 'settings.cfg'
    $project = Join-Path $runDir 'camera_to_dsi_display.prj'
    if (!(Test-Path -LiteralPath $project)) { throw "Missing generated TD project: $project" }
    if (!(Test-Path -LiteralPath $cfg)) {
        $template = Join-Path $root ("td_project\" + $stage + '_settings.cfg.template')
        if (!(Test-Path -LiteralPath $template)) { throw "Missing TD settings and template: $cfg" }
        Copy-Item -LiteralPath $template -Destination $cfg
    }
    $content = Get-Content -LiteralPath $cfg -Raw
    $content = [regex]::Replace($content, '(?m)^set device_name\s*$', 'set device_name ph1_35p.db')
    $content = [regex]::Replace($content, '(?m)^set package_name\s*$', 'set package_name PH1P35MDG324')
    [System.IO.File]::WriteAllText($cfg, $content, (New-Object System.Text.UTF8Encoding($false)))

    $started = Get-Date
    $log = Join-Path $runDir 'p4_3_rebuild.log'
    Push-Location $runDir
    try {
        & $td $flow *> $log
        if ($LASTEXITCODE -ne 0) { throw "TD $stage failed; inspect $log" }
    } finally { Pop-Location }
    $marker = Join-Path $runDir $(if ($stage -eq 'syn_1') { '.opt_gate.end.f' } else { '.bitgen.end.f' })
    if (!(Test-Path -LiteralPath $marker) -or (Get-Item -LiteralPath $marker).LastWriteTime -lt $started.AddSeconds(-2)) {
        throw "TD $stage did not finish; inspect $log"
    }
    Write-Host "$stage completed. Log: $log"
}

$bit = Join-Path $runs 'phy_1\camera_to_dsi_display.bit'
$compressed = Join-Path $runs 'phy_1\camera_to_dsi_display_compress.bit'
$release = Join-Path $root 'release'
New-Item -ItemType Directory -Path $release -Force | Out-Null
Copy-Item -LiteralPath $bit -Destination (Join-Path $release 'FPGA_END.bit') -Force
Copy-Item -LiteralPath $bit -Destination (Join-Path $runs 'best_result\camera_to_dsi_display.bit') -Force
Copy-Item -LiteralPath $compressed -Destination (Join-Path $runs 'best_result\camera_to_dsi_display_compress.bit') -Force
$hash = (Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash
Write-Host "FPGA_END.bit SHA-256: $hash"
