# Builds the two itch.io upload files in build/itch/:
#   tiny-chefs-windows.zip  TinyChefs.exe (PCK embedded, nothing else needed beside it)
#   tiny-chefs-mac.zip      Godot's own macOS export zip ("Tiny Chefs.app"), copied byte for byte
# Exports both platforms first (tools/export-windows.ps1, tools/export-macos.ps1) unless -SkipExport.
# The Mac zip is never re-zipped: Windows zip tools drop the Unix mode bits, and an .app whose binary lost
# its executable bit will not start on macOS. A check below fails the run if the bit is missing.
# Usage: tools/package-itch.ps1 [-SkipExport]
param([switch]$SkipExport)
. "$PSScriptRoot\_common.ps1"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$name = Split-Path -Leaf $RepoRoot
$winExe = Join-Path $RepoRoot "build\windows\$name.exe"   # export-windows.ps1 names it after the repo folder
$macZip = Join-Path $RepoRoot 'build\macos\TinyChefs.zip'
$outDir = Join-Path $RepoRoot 'build\itch'
$winOut = Join-Path $outDir 'tiny-chefs-windows.zip'
$macOut = Join-Path $outDir 'tiny-chefs-mac.zip'

if (-not $SkipExport) {
    foreach ($tool in @('export-windows.ps1', 'export-macos.ps1')) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $tool)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "package-itch: FAILED ($tool exit $LASTEXITCODE)"
            exit 1
        }
    }
}
foreach ($f in @($winExe, $macZip)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "package-itch: FAILED (missing $f; run without -SkipExport)"
        exit 1
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
foreach ($f in @($winOut, $macOut)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

# Windows: one entry, the exe under a friendly name.
$zip = [System.IO.Compression.ZipFile]::Open($winOut, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $winExe, 'TinyChefs.exe',
        [System.IO.Compression.CompressionLevel]::Optimal)
} finally {
    $zip.Dispose()
}

# macOS: Godot's zip as is. Check the binary in Contents/MacOS keeps its Unix executable bit.
Copy-Item -LiteralPath $macZip -Destination $macOut
$zip = [System.IO.Compression.ZipFile]::OpenRead($macOut)
try {
    $bins = @($zip.Entries | Where-Object { $_.FullName -match '^[^/]+\.app/Contents/MacOS/[^/]+$' })
    $bad = @($bins | Where-Object { ((($_.ExternalAttributes -shr 16) -band 0x49) -eq 0) })
} finally {
    $zip.Dispose()
}
if ($bins.Count -eq 0 -or $bad.Count -gt 0) {
    Write-Host "package-itch: FAILED (mac zip: $($bins.Count) binary entries, $($bad.Count) without the executable bit)"
    exit 1
}

foreach ($f in @($winOut, $macOut)) {
    $size = [Math]::Round((Get-Item -LiteralPath $f).Length / 1MB, 1)
    Write-Host "package-itch: $f ($size MB)"
}
Write-Host 'package-itch: OK'
exit 0
