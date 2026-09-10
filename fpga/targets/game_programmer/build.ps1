param([switch]$MapOnly, [string]$DiamondRoot = 'C:/lscc/diamond/3.14')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../../..").Path.Replace('\','/')
$build = "$repo/fpga/diamond/game_programmer"
New-Item -ItemType Directory -Force $build | Out-Null
$oldPath = $env:PATH
$oldFoundry = $env:FOUNDRY
function Invoke-Checked([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed: $LASTEXITCODE" }
}
try {
    $env:FOUNDRY = "$DiamondRoot/ispfpga"
    $env:PATH = "$DiamondRoot/ispfpga/bin/nt64;$DiamondRoot/bin/nt64;$oldPath"
    Push-Location $build
    @"
-a MachXO2
-d LCMXO2-1200HC
-t TQFP100
-s 4
-optimization_goal Area
-frequency 53.20
-resource_sharing 1
-fsm_encoding_style Auto
-force_gsr no
-use_carry_chain 1
-romstyle auto
-use_io_insertion 1
-top top
-ver "$repo/fpga/targets/game_programmer/top.v"
-ver "$repo/fpga/rtl/programmer_block.v"
-ver "$repo/fpga/rtl/mx29_programmer.v"
-ver "$repo/fpga/rtl/mx29_bus.v"
-ver "$repo/fpga/rtl/game_multi_core.v"
-ver "$repo/fpga/rtl/cart_header.v"
-ver "$repo/fpga/rtl/cart_mapper.v"
-ver "$repo/fpga/rtl/mbc_rtc.v"
-ver "$repo/fpga/rtl/cart_mode.v"
-ngd RomEmu_game_programmer.ngd
"@ | Set-Content -Encoding ASCII build.synproj
    Invoke-Checked 'synthesis.exe' @('-f','build.synproj')
    Invoke-Checked 'map.exe' @('-noinferGSR','-a','MachXO2','-p','LCMXO2-1200HC','-t','TQFP100','-s','4','-oc','Commercial','RomEmu_game_programmer.ngd','-o','RomEmu_game_programmer_map.ncd','-pr','RomEmu_game_programmer.prf','-mp','RomEmu_game_programmer.mrp','-lpf',"$repo/fpga/constraints/game_programmer.lpf",'-c','0')
    if ($MapOnly) { return }
    Invoke-Checked 'par.exe' @('-w','RomEmu_game_programmer_map.ncd','RomEmu_game_programmer.ncd','RomEmu_game_programmer.prf')
    Invoke-Checked 'trce.exe' @('-v','10','-gt','-sethld','-sp','4','-sphld','m','-o','RomEmu_game_programmer.twr','RomEmu_game_programmer.ncd','RomEmu_game_programmer.prf')
    $timing = Get-Content 'RomEmu_game_programmer.twr' -Raw
    if ($timing -notmatch 'Timing errors: 0 \(setup\), 0 \(hold\)') {
        throw 'Timing did not pass; inspect RomEmu_game_programmer.twr before exporting firmware.'
    }
    Invoke-Checked 'bitgen.exe' @('-g','RamCfg:Reset','-w','-jedec','RomEmu_game_programmer.ncd','RomEmu_game_programmer.prf')
} finally {
    Pop-Location
    $env:PATH = $oldPath
    $env:FOUNDRY = $oldFoundry
}
