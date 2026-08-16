[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')]
    [string]$OutputName = 'Zepholume-Shaders-1.0.1.zip'
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
$stage = Join-Path $dist '.zepholume-package-staging'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($item in @('shaders','docs','bench','README.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $stage -Recurse -Force
}
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $stage -Force | Select-Object -ExpandProperty FullName) -DestinationPath $zip -CompressionLevel Optimal -Force
Remove-Item -LiteralPath $stage -Recurse -Force
$sum = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
Set-Content -LiteralPath $hash -Value "$sum  $OutputName" -Encoding utf8NoBOM
& (Join-Path $PSScriptRoot 'validate.ps1') -Package $zip
if (-not $?) { throw 'Created ZIP did not pass package validation.' }
Write-Host "Created: $zip"
Write-Host "SHA-256: $sum"
Write-Host 'ZIP entries:'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try { $archive.Entries | ForEach-Object FullName } finally { $archive.Dispose() }
