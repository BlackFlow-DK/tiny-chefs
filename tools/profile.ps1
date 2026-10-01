# CPU profile of a Tiny Chefs host with bots: a windowed host (60 fps cap, like a vsync'd laptop) plus
# (Players-1) headless client bots on 127.0.0.1, one endless shift. The host runs with --profile and prints
# `profile: {json}` every -Every seconds (sections in ms per frame, slowest first; game/scripts/dev/prof.gd).
# Usage: tools/profile.ps1 [-Players 4] [-Seconds 60] [-Every 20] [-Map diner] [-Quality high] [-Port 7971]
# Logs + profile.jsonl in build\profile\<ts>\. Exit non-zero on a missing report or ERROR lines.
param(
    [int]$Players = 4,
    [int]$Seconds = 60,
    [int]$Every = 20,
    [string]$Map = 'diner',
    [string]$Quality = 'high',
    [int]$Port = 7971,
    [string]$Out = ''
)
. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotBin
if ($Out -eq '') { $Out = Join-Path $RepoRoot ("build\profile\" + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
elseif (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $RepoRoot $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

function Start-Godot([string]$Tag, [string[]]$A) {
    $sp = @{ FilePath = $godot; ArgumentList = (ConvertTo-ArgString $A); NoNewWindow = $true; PassThru = $true; WorkingDirectory = $RepoRoot
        RedirectStandardOutput = (Join-Path $Out "$Tag.out"); RedirectStandardError = (Join-Path $Out "$Tag.err") }
    Write-Host ">> [$Tag] $godot $($sp.ArgumentList)"
    $p = Start-Process @sp
    $null = $p.Handle
    return $p
}

$quit = $Seconds + 15
$procs = [ordered]@{}
$procs['host'] = Start-Godot 'host' @('--path', $GameDir, '--windowed', '--resolution', '1280x720', '--position', '0,0', '--max-fps', '60', '--',
    '--host', '--name=HostBot', '--bot', '--autostart', "--players=$Players", '--mode=endless', "--map=$Map", '--shift-seconds=300',
    '--bind=127.0.0.1', "--port=$Port", "--quality=$Quality", '--profile', "--profile-every=$Every", "--quit-after=$quit")
Start-Sleep -Milliseconds 1500
for ($i = 1; $i -lt $Players; $i++) {
    $procs["client$i"] = Start-Godot "client$i" @('--path', $GameDir, '--headless', '--max-fps', '60', '--',
        '--join=127.0.0.1', "--port=$Port", "--name=Bot$i", '--bot', "--quit-after=$($quit + 5)")
}
$deadline = (Get-Date).AddSeconds($quit + 60)
while (@($procs.Values | Where-Object { -not $_.HasExited }).Count -gt 0 -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
foreach ($k in $procs.Keys) {
    if (-not $procs[$k].HasExited) { Write-Host "!! [$k] killed at the timeout"; & taskkill.exe /PID $procs[$k].Id /T /F | Out-Null }
}
$lines = @(Get-Content -LiteralPath (Join-Path $Out 'host.out') | ForEach-Object { $_ -replace "\x1b\[[0-9;]*[A-Za-z]", '' })
$lines += @(Get-Content -LiteralPath (Join-Path $Out 'host.err') -ErrorAction SilentlyContinue | ForEach-Object { $_ -replace "\x1b\[[0-9;]*[A-Za-z]", '' })
$errs = Get-GodotErrors $lines
$reports = @($lines | Where-Object { $_ -match '^profile: ' } | ForEach-Object { $_ -replace '^profile: ', '' })
$reports | Set-Content -LiteralPath (Join-Path $Out 'profile.jsonl')
foreach ($r in $reports) {
    $j = $r | ConvertFrom-Json
    Write-Host ("--- {0}: {1} frames, frame {2} ms, chefs {3}, items {4}" -f $j.kind, $j.frames, $j.frame_ms, $j.chefs, $j.items)
    $j.sections | Select-Object -First 12 | ForEach-Object { Write-Host ("  {0,-34} {1,7:N3} ms/frame  {2,6:N2} calls  max {3,6:N2} ms" -f $_.name, $_.ms_per_frame, $_.calls_per_frame, $_.max_ms) }
}
$errs | Select-Object -First 10 | ForEach-Object { Write-Host "ERR $_" }
Write-Host "profile: logs in $Out"
if ($reports.Count -eq 0 -or $errs.Count -gt 0) { exit 1 }
exit 0
