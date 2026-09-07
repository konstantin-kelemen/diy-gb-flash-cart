param([string]$DiamondRoot = 'C:/lscc/diamond/3.14')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../../..").Path.Replace('\','/')
$build = "$repo/fpga/diamond/programmer"
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
-use_io_insertion 1
-top top
-ver "$repo/fpga/targets/programmer/top.v"
-ver "$repo/fpga/rtl/programmer_block.v"
-ver "$repo/fpga/rtl/mx29_programmer.v"
-ver "$repo/fpga/rtl/mx29_bus.v"
-ngd RomEmu_programmer.ngd
"@ | Set-Content -Encoding ASCII build.synproj
    Invoke-Checked 'synthesis.exe' @('-f','build.synproj')
    Invoke-Checked 'map.exe' @('-a','MachXO2','-p','LCMXO2-1200HC','-t','TQFP100','-s','4','-oc','Commercial','RomEmu_programmer.ngd','-o','RomEmu_programmer_map.ncd','-pr','RomEmu_programmer.prf','-mp','RomEmu_programmer.mrp','-lpf',"$repo/fpga/constraints/programmer.lpf",'-c','0')
    Invoke-Checked 'par.exe' @('-w','RomEmu_programmer_map.ncd','RomEmu_programmer.ncd','RomEmu_programmer.prf')
    Invoke-Checked 'trce.exe' @('-v','10','-gt','-sethld','-sp','4','-sphld','m','-o','RomEmu_programmer.twr','RomEmu_programmer.ncd','RomEmu_programmer.prf')
    Invoke-Checked 'bitgen.exe' @('-g','RamCfg:Reset','-w','-jedec','RomEmu_programmer.ncd','RomEmu_programmer.prf')
} finally {
    Pop-Location
    $env:PATH = $oldPath
    $env:FOUNDRY = $oldFoundry
}
