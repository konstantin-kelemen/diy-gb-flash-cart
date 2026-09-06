param([string]$DiamondRoot = 'C:/lscc/diamond/3.14')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../../..").Path.Replace('\','/')
$build = "$repo/fpga/diamond/spi_bringup"
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
-ver "$repo/fpga/targets/spi_bringup/top.v"
-ngd RomEmu_spi_bringup.ngd
"@ | Set-Content -Encoding ASCII build.synproj
    Invoke-Checked 'synthesis.exe' @('-f','build.synproj')
    Invoke-Checked 'map.exe' @('-a','MachXO2','-p','LCMXO2-1200HC','-t','TQFP100','-s','4','-oc','Commercial','RomEmu_spi_bringup.ngd','-o','RomEmu_spi_bringup_map.ncd','-pr','RomEmu_spi_bringup.prf','-mp','RomEmu_spi_bringup.mrp','-lpf',"$repo/fpga/constraints/spi_bringup.lpf",'-c','0')
    Invoke-Checked 'par.exe' @('-w','RomEmu_spi_bringup_map.ncd','RomEmu_spi_bringup.ncd','RomEmu_spi_bringup.prf')
    Invoke-Checked 'trce.exe' @('-v','10','-gt','-sethld','-sp','4','-sphld','m','-o','RomEmu_spi_bringup.twr','RomEmu_spi_bringup.ncd','RomEmu_spi_bringup.prf')
    Invoke-Checked 'bitgen.exe' @('-g','RamCfg:Reset','-w','-jedec','RomEmu_spi_bringup.ncd','RomEmu_spi_bringup.prf')
} finally {
    Pop-Location
    $env:PATH = $oldPath
    $env:FOUNDRY = $oldFoundry
}
