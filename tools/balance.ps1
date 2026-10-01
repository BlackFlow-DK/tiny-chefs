# Balance harness for Tiny Chefs: runs bot teams (1-4 players) through full shifts and tabulates the results.
# For every combination of players x shift x map it launches a headless host bot plus (players-1) client bots
# on 127.0.0.1, waits for --quit-after-shift, collects the JSON reports, then runs tools\balance_summary.py
# (Markdown table + CSV). Hard timeout per run; every Godot process tree is killed on every exit path.
# Exit 0 only if every run produced a host report with a shift result and no run timed out.
# Usage: tools\balance.ps1 [-Players 1,2,3,4] [-Shifts 0,1,2] [-Maps diner] [-Difficulty normal] [-ShiftSeconds 210]
#                          [-Runs 1] [-Port 7905] [-Out build\balance\<timestamp>] [-TimeoutSec <ShiftSeconds+120>]
#                          [-HostExtra '--mode=campaign --mission=4'] [-Tag m4]
# -Maps / -Difficulty are passed as --map= / --difficulty= (omit them to pass nothing).
# Shift N is started directly with --start-shift=N (the team starts that shift with 0 coins and no upgrades).
param(
    [string[]]$Players = @('1', '2', '3', '4'),   # comma lists work both in-session and via -File
    [string[]]$Shifts = @('0', '1', '2'),
    [string[]]$Maps = @(),
    [string]$Difficulty = '',
    [int]$ShiftSeconds = 210,
    [int]$Runs = 1,
    [int]$Port = 7905,
    [string]$Out = '',
    [int]$TimeoutSec = 0,
    [string]$HostExtra = '',   # extra host user args, space-separated, e.g. '--mode=campaign --mission=4'
    [string]$Tag = ''      # added to every run folder name (p1_s0_<map>_<tag>_r1)
)
. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotBin
$Players = @($Players | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
$Shifts = @($Shifts | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
$Maps = @($Maps | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
if ($TimeoutSec -le 0) { $TimeoutSec = $ShiftSeconds + 120 }
if ($Out -eq '') { $Out = Join-Path 'build\balance' (Get-Date -Format 'yyyyMMdd-HHmmss') }
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $RepoRoot $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$mapList = @($Maps)
if ($mapList.Count -eq 0) { $mapList = @('') }

$script:live = New-Object System.Collections.Generic.List[object]
function Stop-All {
    foreach ($p in $script:live) {
        try { if (-not $p.HasExited) { & taskkill.exe /PID $p.Id /T /F 2>$null | Out-Null; $null = $p.WaitForExit(10000) } } catch {}
    }
    $script:live.Clear()
}
function Start-Bot {
    param([string]$Dir, [string]$Tag, [string[]]$UserArgs)
    $a = @('--path', $GameDir, '--headless', '--max-fps', '60', '--') + $UserArgs
    $p = Start-Process -FilePath $godot -ArgumentList (ConvertTo-ArgString $a) -NoNewWindow -PassThru -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput (Join-Path $Dir "$Tag.out") -RedirectStandardError (Join-Path $Dir "$Tag.err")
    $null = $p.Handle
    $script:live.Add($p)
    return $p
}

$failed = 0
$total = 0
try {
    foreach ($n in $Players) { foreach ($s in $Shifts) { foreach ($m in $mapList) { foreach ($r in 1..$Runs) {
        $total++
        $mapName = $m; if ($mapName -eq '') { $mapName = 'default' }
        $diffName = $Difficulty; if ($diffName -eq '') { $diffName = 'default' }
        $name = "p$($n)_s$($s)_$($mapName)_r$r"
        if ($Tag -ne '') { $name = "p$($n)_s$($s)_$($mapName)_$($Tag)_r$r" }
        $dir = Join-Path $Out $name
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        @{ players = $n; shift = $s; map = $mapName; difficulty = $diffName; run = $r; shift_seconds = $ShiftSeconds; port = $Port; extra = $HostExtra; tag = $Tag } |
            ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $dir 'meta.json')
        Write-Host ">> run $name (timeout ${TimeoutSec}s)"

        $extra = @()
        if ($m -ne '') { $extra += "--map=$m" }
        if ($Difficulty -ne '') { $extra += "--difficulty=$Difficulty" }
        $quitAfter = $ShiftSeconds + 90
        $procs = @()
        $hostArgs = @('--host', '--name=HostBot', '--bot', '--autostart', "--players=$n", "--shift-seconds=$ShiftSeconds", "--start-shift=$s",
            '--bind=127.0.0.1', "--port=$Port", '--quit-after-shift', "--test-report=$(Join-Path $dir 'host.json')", "--quit-after=$quitAfter") + $extra +
            @($HostExtra -split '\s+' | Where-Object { $_ -ne '' })
        $procs += Start-Bot $dir 'host' $hostArgs
        for ($i = 1; $i -lt $n; $i++) {
            Start-Sleep -Milliseconds 1500
            $ca = @('--join=127.0.0.1', "--port=$Port", "--name=Bot$i", '--bot', "--test-report=$(Join-Path $dir "client$i.json")", "--quit-after=$($quitAfter + 5)") + $extra
            $procs += Start-Bot $dir "client$i" $ca
        }

        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        $timedOut = $false
        while (@($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
            if ((Get-Date) -gt $deadline) { $timedOut = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if ($timedOut) { Write-Host "!! $name timed out after ${TimeoutSec}s; killing" }
        Stop-All

        $ok = (-not $timedOut) -and (Test-Path -LiteralPath (Join-Path $dir 'host.json'))
        if ($ok) {
            $h = Get-Content -Raw -LiteralPath (Join-Path $dir 'host.json') | ConvertFrom-Json
            if ($null -eq $h.result) { $ok = $false; Write-Host "!! $name host report has no shift result" }
            else { Write-Host ("   served {0} failed {1} earned {2} / target {3}" -f $h.result.served, $h.result.failed, $h.result.earned, $h.result.target) }
        } elseif (-not $timedOut) { Write-Host "!! $name wrote no host report" }
        if (-not $ok) { $failed++; 'FAILED' | Set-Content -LiteralPath (Join-Path $dir 'FAILED') }
    } } } }
}
finally {
    Stop-All
}

$py = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($py) { & $py.Source (Join-Path $PSScriptRoot 'balance_summary.py') $Out } else { Write-Host 'python not found; skipping summary' }
Write-Host "balance: $total run(s), $failed failed; output in $Out"
if ($failed -gt 0) { exit 1 }
exit 0
