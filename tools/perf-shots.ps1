# Screenshots of a solo bot shift per quality preset x map (for judging how each preset looks).
# Usage: tools/perf-shots.ps1 [-Presets low,medium,high] [-Maps diner,picnic] [-At 14] [-Resolution 1280x720]
#   [-Port 7971] [-Extra "--rendering-method mobile"] [-Suffix "-mobile"] [-UserExtra "..."] [-OutDir build\screenshots\perf]
# Writes <OutDir>\<map>-<preset><suffix>.png. Exit non-zero on a missing PNG or ERROR lines.
param(
    [string[]]$Presets = @('low', 'medium', 'high'),
    [string[]]$Maps = @('diner', 'picnic'),
    [double]$At = 14,
    [string]$Resolution = '1280x720',
    [int]$Port = 7971,
    [string]$Extra = '',
    [string]$Suffix = '',
    [string]$UserExtra = '',
    [string]$OutDir = 'build\screenshots\perf'
)
. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotBin
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $RepoRoot $OutDir }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Presets = @($Presets | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$Maps = @($Maps | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$failed = 0
foreach ($map in $Maps) {
    foreach ($preset in $Presets) {
        $png = Join-Path $OutDir "$map-$preset$Suffix.png"
        Remove-Item -LiteralPath $png -Force -ErrorAction SilentlyContinue
        $a = @('--path', $GameDir, '--windowed', '--resolution', $Resolution, '--position', '0,0')
        $a += @($Extra -split '\s+' | Where-Object { $_ -ne '' })
        $a += @('--', '--host', '--name=Shot', '--bot', '--autostart', '--players=1', '--mode=endless', "--map=$map",
            '--shift-seconds=90', '--bind=127.0.0.1', "--port=$Port", "--quality=$preset", "--shot=$At@$png", "--quit-after=$($At + 2)")
        $a += @($UserExtra -split '\s+' | Where-Object { $_ -ne '' })
        $r = Invoke-Tool -Exe $godot -ArgList $a -TimeoutSec ([int]($At + 60))
        $errs = Get-GodotErrors $r.Output
        if (-not (Test-Path -LiteralPath $png) -or $errs.Count -gt 0) {
            Write-Host "!! $map-$preset : PNG missing or $($errs.Count) error line(s)"
            $failed++
        } else { Write-Host "perf-shots: $png" }
    }
}
if ($failed -gt 0) { exit 1 }
exit 0
