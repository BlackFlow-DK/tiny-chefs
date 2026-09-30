# Launches a Tiny Chefs host and a joining client on 127.0.0.1, both driven by --bot, runs one
# shortened shift and checks the JSON reports the game writes (--test-report).
# Passes (exit 0) only if: the client connected, both chefs existed on both instances, at least one
# order was served (coins went up on host and client), a two-chef patty carry happened and was faster
# than a solo patty carry, both processes exited 0 on their own, and no ERROR lines were printed.
# -Solo: host only; passes if the bot serves a Cheeseburger alone.
# Usage: tools/test-multiplayer.ps1 [-ShiftSeconds 100] [-TimeoutSec 220] [-Solo] [-Windowed] [-ShotDir build\screenshots] [-ShotAt 45] [-BotLog] [-Port 7777]
# Logs (and bot decisions with -BotLog) land in build\test-mp\ (build\test-mp-<port>\ when -Port is not 7777).
param(
    [int]$ShiftSeconds = 100,
    [int]$TimeoutSec = 220,
    [switch]$Solo,
    [switch]$Windowed,
    [string]$ShotDir = '',
    [double]$ShotAt = 45,
    [switch]$BotLog,
    [int]$Port = 7777
)
. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotBin
$workName = 'test-mp'
if ($Port -ne 7777) { $workName = "test-mp-$Port" }
$work = Join-Path $RepoRoot "build\$workName"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Get-ChildItem -LiteralPath $work -File | Remove-Item -Force -ErrorAction SilentlyContinue
if ($ShotDir -ne '' -and -not [System.IO.Path]::IsPathRooted($ShotDir)) { $ShotDir = Join-Path $RepoRoot $ShotDir }
if ($ShotDir -ne '') { $Windowed = $true; New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null }

function Start-Godot {
    param([string]$Tag, [string[]]$UserArgs, [string]$Pos)
    $a = @('--path', $GameDir)
    if ($Windowed) { $a += @('--windowed', '--resolution', '1280x720', '--position', $Pos) } else { $a += '--headless' }
    $a += @('--max-fps', '60', '--')
    $a += $UserArgs
    if ($BotLog) { $a += '--bot-log' }
    $spArgs = @{
        FilePath               = $godot
        ArgumentList           = (ConvertTo-ArgString $a)
        NoNewWindow            = $true
        PassThru               = $true
        WorkingDirectory       = $RepoRoot
        RedirectStandardOutput = (Join-Path $work "$Tag.out")
        RedirectStandardError  = (Join-Path $work "$Tag.err")
    }
    Write-Host ">> [$Tag] $godot $($spArgs.ArgumentList)"
    $p = Start-Process @spArgs
    $null = $p.Handle  # PS 5.1: needed for ExitCode
    return $p
}

$quitAfter = $ShiftSeconds + 90
$players = 2
if ($Solo) { $players = 1 }
$hostArgs = @('--host', '--name=HostBot', '--bot', '--autostart', "--players=$players", "--shift-seconds=$ShiftSeconds",
    '--bind=127.0.0.1', "--port=$Port", '--quit-after-shift', "--test-report=$(Join-Path $work 'host.json')", "--quit-after=$quitAfter")
if ($ShotDir -ne '') { $hostArgs += "--shot=$ShotAt@$(Join-Path $ShotDir 'host-midshift.png')" }
$procs = [ordered]@{}
$procs['host'] = Start-Godot -Tag 'host' -UserArgs $hostArgs -Pos '0,0'
if (-not $Solo) {
    Start-Sleep -Milliseconds 1500
    $clientArgs = @('--join=127.0.0.1', "--port=$Port", '--name=ClientBot', '--bot', "--test-report=$(Join-Path $work 'client.json')", "--quit-after=$($quitAfter + 5)")
    if ($ShotDir -ne '') { $clientArgs += "--shot=$($ShotAt + 0.5)@$(Join-Path $ShotDir 'client-midshift.png')" }
    $procs['client'] = Start-Godot -Tag 'client' -UserArgs $clientArgs -Pos '640,60'
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$timedOut = $false
while ($true) {
    $running = @($procs.Values | Where-Object { -not $_.HasExited })
    if ($running.Count -eq 0) { break }
    if ((Get-Date) -gt $deadline) { $timedOut = $true; break }
    Start-Sleep -Milliseconds 500
}
foreach ($k in $procs.Keys) {
    $p = $procs[$k]
    if (-not $p.HasExited) {
        Write-Host "!! [$k] still running at the hard timeout ($TimeoutSec s); killing the process tree"
        & taskkill.exe /PID $p.Id /T /F | Out-Null
        $null = $p.WaitForExit(10000)
    }
}

$failures = New-Object System.Collections.Generic.List[string]
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "  PASS  $what" } else { Write-Host "  FAIL  $what"; $failures.Add($what) }
}

$reports = @{}
foreach ($k in $procs.Keys) {
    $lines = @()
    foreach ($ext in @('out', 'err')) {
        $f = Join-Path $work "$k.$ext"
        if (Test-Path -LiteralPath $f) { $lines += @(Get-Content -LiteralPath $f | ForEach-Object { $_ -replace "\x1b\[[0-9;]*[A-Za-z]", '' }) }
    }
    $errs = Get-GodotErrors $lines
    Write-Host "---- [$k] exit $($procs[$k].ExitCode), $($lines.Count) log lines, $($errs.Count) error lines"
    $errs | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" }
    Check ($errs.Count -eq 0) "$k printed no ERROR / SCRIPT ERROR lines"
    Check ((-not $timedOut) -and $procs[$k].ExitCode -eq 0) "$k exited cleanly on its own (exit 0)"
    $rf = Join-Path $work "$k.json"
    if (Test-Path -LiteralPath $rf) { $reports[$k] = Get-Content -Raw -LiteralPath $rf | ConvertFrom-Json }
    Check ($reports.ContainsKey($k)) "$k wrote its test report"
}

$h = $reports['host']
if ($h) {
    Write-Host ("host: chefs seen {0}, served {1} {2}, coins {3} -> max {4}, patty solo {5:N2} m/s, duo {6:N2} m/s for {7:N1} s" -f `
        $h.max_chefs_seen, $h.orders_served, (($h.served_recipes) -join ','), $h.coins_start, $h.coins_max, $h.patty_solo_speed, $h.patty_duo_speed, $h.patty_duo_seconds)
    Check ($h.shifts_finished -ge 1) 'host finished the shift'
    Check ($h.orders_served -ge 1 -and $h.coins_max -gt $h.coins_start) 'at least one order served, coins went up (host)'
}
if ($Solo) {
    if ($h) {
        Check ($h.max_chefs_seen -ge 1) 'host chef existed'
        Check (@($h.served_recipes) -contains 'Cheeseburger') 'solo bot served a Cheeseburger'
    }
} else {
    $c = $reports['client']
    if ($c) {
        Write-Host ("client: connected {0}, snapshots {1}, chefs seen {2}, served {3}, coins {4} -> max {5}" -f `
            $c.connected, $c.snapshots, $c.max_chefs_seen, $c.orders_served, $c.coins_start, $c.coins_max)
        Check ($c.connected -eq $true -and $c.snapshots -gt 0) 'client connected and received snapshots'
        Check ($c.max_chefs_seen -ge 2) 'both chefs existed on the client'
        Check ($c.coins_max -gt $c.coins_start) 'coins went up on the client (replicated)'
    }
    if ($h) {
        Check ($h.max_chefs_seen -ge 2) 'both chefs existed on the host'
        Check ($h.patty_duo_seconds -ge 0.5) 'a two-chef patty carry happened'
        Check ($h.patty_solo_speed -gt 0 -and $h.patty_duo_speed -gt $h.patty_solo_speed) 'two-chef patty carry was faster than solo'
    }
}

if ($failures.Count -gt 0) {
    Write-Host "test-multiplayer: FAILED ($($failures.Count) check(s)); logs in $work"
    exit 1
}
Write-Host "test-multiplayer: OK (logs in $work)"
exit 0
