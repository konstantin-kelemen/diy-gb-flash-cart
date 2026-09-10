param([string]$QuestaRoot = 'C:/lscc/diamond/3.14/questasim')
$ErrorActionPreference = 'Stop'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$game = @('../../rtl/game_multi_core.v', '../../rtl/cart_header.v', '../../rtl/cart_mapper.v', '../../rtl/mbc_rtc.v')
$programmer = @('../../rtl/mx29_bus.v', '../../rtl/mx29_programmer.v', '../../rtl/programmer_block.v')
$combined = @('../../targets/game_programmer/top.v') + $game + @('../../rtl/mx29_bus.v', '../../rtl/mx29_programmer.v', '../../rtl/programmer_v5.v', '../../rtl/cart_mode.v', '../game_programmer_tb.sv')
$cases = @(
    @{Name='cart_header'; Top='cart_header_tb'; Files=@('../../rtl/cart_header.v', '../cart_header_tb.sv'); Options=''},
    @{Name='game_multi'; Top='game_multi_tb'; Files=@('../../targets/game_multi/top.v') + $game + @('../game_multi_tb.sv'); Options=''},
    @{Name='programmer_block'; Top='programmer_block_tb'; Files=$programmer + @('../programmer_block_tb.sv'); Options=''},
    @{Name='game_programmer'; Top='game_programmer_tb'; Files=$combined; Options=''},
    @{Name='v5_slow'; Top='game_programmer_tb'; Files=$combined; Options='-gCLOCK_HALF=11.75'},
    @{Name='v5_fast'; Top='game_programmer_tb'; Files=$combined; Options='-gCLOCK_HALF=7.8125'}
)
Push-Location $build
try {
    foreach ($case in $cases) {
        $library = $case.Name + '_regression_work'
        $script = @(
            'onerror {quit -code 1 -force}',
            'onbreak {quit -code 1 -force}',
            "vlib $library",
            "vlog -sv -work $library $($case.Files -join ' ')",
            "vsim -c $($case.Options) $library.$($case.Top)",
            'run -all',
            'quit -code 0 -force'
        )
        $script | Set-Content -Encoding ASCII ($case.Name + '_regression.do')
        $log = $case.Name + '_regression.log'
        & "$QuestaRoot/win64/vsim.exe" -c -do ($case.Name + '_regression.do') *> $log
        $result = Get-Content $log -Raw
        # Questa can return zero after $fatal; require the test's PASS marker too.
        if ($LASTEXITCODE -ne 0 -or $result -notmatch '# PASS ' -or $result -match '# Errors: [1-9]') {
            throw "Simulation failed: $build/$log"
        }
        ($result -split "`n" | Where-Object { $_ -match '^# PASS ' }) | Write-Output
    }
} finally { Pop-Location }
