[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')]
    [string]$OutputName = 'Zepholume-Shaders-1.0.4.zip'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate.ps1')
if (-not $?) { throw 'Validation failed; package was not created.' }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist $OutputName
$hash = "$zip.sha256"
foreach ($generated in @($zip, $hash)) { if (Test-Path -LiteralPath $generated) { Remove-Item -LiteralPath $generated -Force } }

# Build the public pack from an explicit allow-list. Development reports,
# benchmarks, artifacts and runtime material are deliberately absent.
$files = @(
    @(Get-ChildItem -LiteralPath (Join-Path $root 'shaders') -File -Recurse) +
    @(Get-Item -LiteralPath (Join-Path $root 'README.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'CHANGELOG.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md'))
) | Sort-Object @{ Expression = { $_.FullName.Substring($root.Length + 1).Replace('\','/') }; Ascending = $true }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $entryName = $file.FullName.Substring($root.Length + 1).Replace('\','/')
        $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
        # Fixed epoch and sorted entries make identical source trees yield an
        # identical archive rather than inheriting filesystem timestamps.
        $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $input = [IO.File]::OpenRead($file.FullName)
        try { $output = $entry.Open(); try { $input.CopyTo($output) } finally { $output.Dispose() } }
        finally { $input.Dispose() }
    }
} finally { $archive.Dispose() }

$sum = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
Set-Content -LiteralPath $hash -Value "$sum  $OutputName" -Encoding utf8NoBOM
& (Join-Path $PSScriptRoot 'validate.ps1') -Package $zip
if (-not $?) { throw 'Created ZIP did not pass package validation.' }
Write-Host "Created: $zip"
Write-Host "SHA-256: $sum"
Write-Host "ZIP entries: $($files.Count)"
