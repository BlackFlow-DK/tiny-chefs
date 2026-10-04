# Regenerates the lobby map-card pictures (game/assets/ui/maps/<map_id>_<n>.webp) from scenes/dev/postcard.tscn.
# Usage: tools/map-thumbs.ps1 [-Maps diner,food_truck,picnic,twin_islands]   (needs a real window and Pillow)
param([string[]]$Maps = @('diner','food_truck','picnic','twin_islands'))
. "$PSScriptRoot\_common.ps1"
$godot = Get-GodotBin
$raw = Join-Path $RepoRoot 'build\map-thumbs'
New-Item -ItemType Directory -Force -Path $raw | Out-Null
foreach ($m in $Maps) {
    $r = Invoke-Tool -Exe $godot -ArgList @('--path', $GameDir, '--windowed', '--resolution', '1280x720', 'res://scenes/dev/postcard.tscn', '--', '--quality=high', "--pc-map=$m", "--pc-dir=$raw") -TimeoutSec 240
    if ($r.ExitCode -ne 0) { Write-Host "map-thumbs: $m FAILED"; exit 1 }
}
python (Join-Path $PSScriptRoot 'map_thumbs.py') $raw @Maps
exit $LASTEXITCODE
