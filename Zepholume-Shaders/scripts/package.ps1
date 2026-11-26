[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')]
    [string]$OutputName = 'Zepholume-Shaders-1.0.8.zip',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$gitRoot = Split-Path -Parent $root
. (Join-Path $PSScriptRoot 'package-metadata.ps1')
& (Join-Path $PSScriptRoot 'validate.ps1')
if (-not $?) { throw 'Validation failed; package was not created.' }

$dist = if ($OutputDirectory) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory) } else { Join-Path $root 'dist' }
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist $OutputName
$hash = "$zip.sha256"
$manifest = "$zip.manifest.json"
if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $hash) -or (Test-Path -LiteralPath $manifest)) {
    throw "Refusing to overwrite an existing package or sidecar: $zip"
}
$stagingZip = Join-Path $dist ('.' + [IO.Path]::GetFileNameWithoutExtension($OutputName) + '.staging-' + [guid]::NewGuid().ToString('N') + '.zip')
$stagingHash = "$stagingZip.sha256"
$stagingManifest = "$stagingZip.manifest.json"
$promoted = [System.Collections.Generic.List[string]]::new()

# Build the public pack from an explicit allow-list. Development reports,
# benchmarks, artifacts and runtime material are deliberately absent.
$inputs = @(
    @(Get-ChildItem -LiteralPath (Join-Path $root 'shaders') -File -Recurse) +
    @(Get-Item -LiteralPath (Join-Path $root 'README.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'CHANGELOG.md')) +
    @(Get-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md'))
)
# Sort-Object uses culture-sensitive ordering, even when its input is a path.
# Use an ordinal comparer to match the manifest and every host culture.
$byPath = [System.Collections.Generic.SortedDictionary[string,IO.FileInfo]]::new([StringComparer]::Ordinal)
foreach ($file in $inputs) { $byPath.Add($file.FullName.Substring($root.Length + 1).Replace('\','/'), $file) }
foreach ($name in @('LICENSE','NOTICE')) { $byPath.Add($name, (Get-Item -LiteralPath (Join-Path $gitRoot $name))) }

try {
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($stagingZip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $byPath.GetEnumerator()) {
        $entry = $archive.CreateEntry($file.Key, [IO.Compression.CompressionLevel]::Optimal)
        # Fixed epoch and sorted entries make identical source trees yield an
        # identical archive rather than inheriting filesystem timestamps.
        $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $output = $entry.Open()
        try {
            if ($file.Key -cin @('LICENSE','NOTICE')) {
                $bytes = Get-ZephPackageMetadataBytes $file.Value.FullName
                $output.Write($bytes, 0, $bytes.Length)
            } else {
                $input = [IO.File]::OpenRead($file.Value.FullName)
                try { $input.CopyTo($output) } finally { $input.Dispose() }
            }
        } finally { $output.Dispose() }
    }
} finally { $archive.Dispose() }

$sum = (Get-FileHash -LiteralPath $stagingZip -Algorithm SHA256).Hash
Set-Content -LiteralPath $stagingHash -Value "$sum  $OutputName" -Encoding utf8NoBOM
    & (Join-Path $PSScriptRoot 'validate.ps1') -Package $stagingZip
    if (-not $?) { throw 'Created ZIP did not pass package validation.' }
    $revision = (& git -C $gitRoot rev-parse HEAD 2>$null)
    $sourceState = if ($LASTEXITCODE -eq 0) { if (@(& git -C $gitRoot status --porcelain).Count -eq 0) { 'clean' } else { 'dirty' } } else { 'git-unavailable' }
    $entryHashes = @($byPath.GetEnumerator() | ForEach-Object {
        $entryHash = if ($_.Key -cin @('LICENSE','NOTICE')) {
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData((Get-ZephPackageMetadataBytes $_.Value.FullName)))
        } else { (Get-FileHash -LiteralPath $_.Value.FullName -Algorithm SHA256).Hash }
        [ordered]@{ path=$_.Key; sha256=$entryHash }
    })
    $buildManifest = [ordered]@{
        schemaVersion=1; archive=$OutputName; archiveSha256=$sum; commit=if ($revision) { "$revision".Trim() } else { $null }
        sourceState=$sourceState; validator='scripts/validate.ps1 and scripts/validate.ps1 -Package passed'
        buildConfiguration=[ordered]@{ compression='Optimal'; entryTimestampUtc='1980-01-01T00:00:00Z'; ordering='ordinal source path'; rootLicenseAndNoticeLineEnding='CRLF' }
        entries=$entryHashes
    }
    $buildManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stagingManifest -Encoding utf8NoBOM
    # Move without overwrite and publish the manifest last as the completion
    # marker. Roll back only files successfully promoted by this invocation.
    [IO.File]::Move($stagingZip, $zip)
    $promoted.Add($zip)
    [IO.File]::Move($stagingHash, $hash)
    $promoted.Add($hash)
    [IO.File]::Move($stagingManifest, $manifest)
    $promoted.Add($manifest)
} catch {
    foreach ($owned in $promoted) { Remove-Item -LiteralPath $owned -Force -ErrorAction SilentlyContinue }
    throw
} finally {
    Remove-Item -LiteralPath $stagingZip,$stagingHash,$stagingManifest -Force -ErrorAction SilentlyContinue
}
Write-Host "Created: $zip"
Write-Host "SHA-256: $sum"
Write-Host "ZIP entries: $($byPath.Count)"
