[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')]
    [string]$OutputName = 'Zepholume-Shaders-1.0.6.zip',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate.ps1')
if (-not $?) { throw 'Validation failed; package was not created.' }

$dist = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $root 'dist' }
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist $OutputName
$hash = "$zip.sha256"
$manifest = "$zip.manifest.json"
if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $hash) -or (Test-Path -LiteralPath $manifest)) {
    throw "Refusing to overwrite an existing package or sidecar: $zip"
}
$stagingZip = Join-Path $dist ('.' + [IO.Path]::GetFileNameWithoutExtension($OutputName) + '.staging-' + [guid]::NewGuid().ToString('N') + '.zip')
$stagingHash = "$stagingZip.sha256"

# Build the public pack from an explicit allow-list. Development reports,
# benchmarks, artifacts and runtime material are deliberately absent.
$files = @(
    @(Get-ChildItem -LiteralPath (Join-Path $root 'shaders') -File -Recurse) +
    @(Get-Item -LiteralPath (Join-Path $root 'README.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'CHANGELOG.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md'))
) | Sort-Object @{ Expression = { $_.FullName.Substring($root.Length + 1).Replace('\','/') }; Ascending = $true }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($stagingZip, [IO.Compression.ZipArchiveMode]::Create)
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

$sum = (Get-FileHash -LiteralPath $stagingZip -Algorithm SHA256).Hash
Set-Content -LiteralPath $stagingHash -Value "$sum  $OutputName" -Encoding utf8NoBOM
try {
    & (Join-Path $PSScriptRoot 'validate.ps1') -Package $stagingZip
    if (-not $?) { throw 'Created ZIP did not pass package validation.' }
    $gitRoot = Split-Path -Parent $root
    $revision = (& git -C $gitRoot rev-parse HEAD 2>$null)
    $sourceState = if ($LASTEXITCODE -eq 0) { if (@(& git -C $gitRoot status --porcelain).Count -eq 0) { 'clean' } else { 'dirty' } } else { 'git-unavailable' }
    $entryHashes = @($files | ForEach-Object {
        [ordered]@{ path=$_.FullName.Substring($root.Length + 1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    $buildManifest = [ordered]@{
        schemaVersion=1; archive=$OutputName; archiveSha256=$sum; commit=if ($revision) { "$revision".Trim() } else { $null }
        sourceState=$sourceState; validator='scripts/validate.ps1 and scripts/validate.ps1 -Package passed'
        buildConfiguration=[ordered]@{ compression='Optimal'; entryTimestampUtc='1980-01-01T00:00:00Z'; ordering='ordinal source path' }
        entries=$entryHashes
    }
    $buildManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding utf8NoBOM
    [IO.File]::Move($stagingZip, $zip)
    [IO.File]::Move($stagingHash, $hash)
} finally {
    Remove-Item -LiteralPath $stagingZip,$stagingHash -Force -ErrorAction SilentlyContinue
}
Write-Host "Created: $zip"
Write-Host "SHA-256: $sum"
Write-Host "ZIP entries: $($files.Count)"
