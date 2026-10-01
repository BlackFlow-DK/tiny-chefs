# GPU/CPU benchmark of Tiny Chefs: for every preset x map (x stress) runs a solo bot host in a 1920x1080
# borderless window with vsync off for -Seconds of play (after a warm-up), collects the game's one-line
# `bench: {json}` report (game/scripts/dev/bench.gd) and prints a markdown table.
# Usage: tools/bench.ps1 [-Presets low,medium,high] [-Maps diner,picnic] [-Stress both|on|off] [-Seconds 20]
#   [-Port 7971] [-Extra "--rendering-method mobile"] (engine args, before --) [-UserExtra "..."] [-Out build\bench\<ts>]
# Exit non-zero when a run produced no report or printed ERROR lines.
param(
    [string[]]$Presets = @('low', 'medium', 'high'),
    [string[]]$Maps = @('diner', 'picnic'),
    [ValidateSet('both', 'on', 'off')][string]$Stress = 'both',
    [double]$Seconds = 20,
    [int]$Port = 7971,
    [string]$Extra = '',
    [string]$UserExtra = '',
    [string]$Out = '',
    [int]$TimeoutSec = 120
)
. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotBin
if ($Out -eq '') { $Out = Join-Path $RepoRoot ("build\bench\" + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
elseif (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $RepoRoot $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Presets = @($Presets | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$Maps = @($Maps | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$stressModes = @{ both = @($false, $true); on = @($true); off = @($false) }[$Stress]

$rows = New-Object System.Collections.Generic.List[object]
$failed = 0
foreach ($map in $Maps) {
    foreach ($preset in $Presets) {
        foreach ($st in $stressModes) {
            $tag = "$map-$preset" + $(if ($st) { '-stress' } else { '' })
            $a = @('--path', $GameDir, '--windowed', '--resolution', '1920x1080', '--position', '0,0')
            $a += @($Extra -split '\s+' | Where-Object { $_ -ne '' })
            $a += @('--', '--host', '--name=Bench', '--bot', '--autostart', '--players=1', '--mode=endless', "--map=$map",
                '--shift-seconds=90', '--bind=127.0.0.1', "--port=$Port", "--bench=$preset", "--quality=$preset",
                "--bench-seconds=$Seconds", "--quit-after=$([int]($Seconds + 60))")
            if ($st) { $a += '--bench-stress' }
            $a += @($UserExtra -split '\s+' | Where-Object { $_ -ne '' })
            $r = Invoke-Tool -Exe $godot -ArgList $a -TimeoutSec $TimeoutSec
            $r.Output | Set-Content -LiteralPath (Join-Path $Out "$tag.log")
            $line = $r.Output | Where-Object { $_ -match '^bench: ' } | Select-Object -Last 1
            $errs = Get-GodotErrors $r.Output
            if (-not $line -or $errs.Count -gt 0) {
                Write-Host "!! $tag : no bench report or $($errs.Count) error line(s)"
                $failed++
                continue
            }
            $j = ($line -replace '^bench: ', '') | ConvertFrom-Json
            $j | Add-Member -NotePropertyName tag -NotePropertyValue $tag
            $rows.Add($j)
            ($line -replace '^bench: ', '') | Add-Content -LiteralPath (Join-Path $Out 'results.jsonl')
        }
    }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add('| map | preset | stress | renderer | scale | fps | avg ms | 1% low ms | GPU ms | GPU 1% low ms | CPU render ms |')
$md.Add('|---|---|---|---|---|---|---|---|---|---|---|')
foreach ($j in $rows) {
    $md.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |" -f $j.map, $j.preset, $(if ($j.stress) { 'x2' } else { '-' }),
        $j.renderer, $j.render_scale, $j.fps, $j.avg_ms, $j.low1_ms, $j.gpu_ms, $j.gpu_low1_ms, $j.cpu_render_ms))
}
$md | Set-Content -LiteralPath (Join-Path $Out 'table.md')
$md | ForEach-Object { Write-Host $_ }
Write-Host "bench: results in $Out"
if ($failed -gt 0) { Write-Host "bench: $failed run(s) failed"; exit 1 }
exit 0
