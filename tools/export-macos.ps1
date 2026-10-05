# Exports a release macOS build to build/macos/TinyChefs.zip: a zip holding "Tiny Chefs.app" (universal
# arm64 + x86_64, ad-hoc signed by Godot's built-in codesign, PCK in Contents/Resources).
# Uses the "macOS" preset in game/export_presets.cfg. Needs Godot export templates (macos.zip) installed.
# Exporting as .zip (not a bare .app folder) matters on Windows: Godot's zip writer records the Unix mode
# bits (executable flag on Contents/MacOS/*); a .app folder written to NTFS loses them. Never re-zip it.
# Usage: tools/export-macos.ps1 [-DebugBuild]
param([switch]$DebugBuild, [int]$TimeoutSec = 900)
. "$PSScriptRoot\_common.ps1"

$outDir = Join-Path $RepoRoot 'build\macos'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$zip = Join-Path $outDir 'TinyChefs.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

$mode = '--export-release'
if ($DebugBuild) { $mode = '--export-debug' }
$godot = Get-GodotBin
$r = Invoke-Tool -Exe $godot -ArgList @('--headless', '--path', $GameDir, $mode, 'macOS', $zip) -TimeoutSec $TimeoutSec
$errors = Get-GodotErrors $r.Output
if ($r.ExitCode -ne 0 -or $errors.Count -gt 0 -or -not (Test-Path -LiteralPath $zip)) {
    Write-Host "export-macos: FAILED (exit $($r.ExitCode), $($errors.Count) error line(s))"
    exit 1
}
$size = [Math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
Write-Host "export-macos: OK -> $zip ($size MB)"
exit 0
