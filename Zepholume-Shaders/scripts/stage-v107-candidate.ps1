[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateZip,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][string]$ModSourceDirectory,
    [Parameter(Mandatory)][string]$GameDirectory
)
$ErrorActionPreference = 'Stop'
$zip = (Resolve-Path -LiteralPath $CandidateZip).ProviderPath
$mods = (Resolve-Path -LiteralPath $ModSourceDirectory).ProviderPath
$destination = [IO.Path]::GetFullPath($GameDirectory)
if (Test-Path -LiteralPath $destination) { throw 'GameDirectory already exists; choose a new isolated directory.' }
$ancestor = Split-Path -Parent $destination
while ($ancestor) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'GameDirectory must not traverse a reparse point.' }
    $parent = Split-Path -Parent $ancestor
    if (-not $parent -or $parent -eq $ancestor) { break }
    $ancestor = $parent
}
if ([IO.Path]::GetExtension($zip) -ine '.zip' -or (Get-Item -LiteralPath $zip -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Candidate must be a regular ZIP file.' }
if ((Get-Item -LiteralPath $mods -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Mod source must not be a reparse point.' }
$expected = $ExpectedSha256.ToUpperInvariant()
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -cne $expected) { throw 'Candidate SHA-256 mismatch; nothing staged.' }
$names = @('iris-1.7.6+mc1.20.1.jar','sodium-fabric-0.5.13+mc1.20.1.jar')
foreach ($name in $names) {
    $source = Join-Path $mods $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or ((Get-Item -LiteralPath $source -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Missing or unsafe mod: $name" }
}
New-Item -ItemType Directory -Path $destination,(Join-Path $destination 'mods'),(Join-Path $destination 'shaderpacks') | Out-Null
$files = @()
foreach ($source in @($zip) + @($names | ForEach-Object { Join-Path $mods $_ })) {
    $subdir = if ($source -eq $zip) { 'shaderpacks' } else { 'mods' }
    $target = Join-Path (Join-Path $destination $subdir) ([IO.Path]::GetFileName($source))
    Copy-Item -LiteralPath $source -Destination $target
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $hash) { throw "Staged copy hash mismatch: $target" }
    if ($source -eq $zip -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $expected) { throw 'Staged candidate SHA-256 does not match the supplied expected hash.' }
    $files += [ordered]@{ name = [IO.Path]::GetFileName($target); sha256 = $hash }
}
$manifest = [ordered]@{ classification = 'STAGED_NOT_LAUNCHED'; activation = 'UNVERIFIED'; createdUtc = [datetime]::UtcNow.ToString('o'); sourceCommit = $SourceCommit.ToLowerInvariant(); minecraftTarget = '1.20.1'; files = $files }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'staging-manifest.json') -Encoding utf8NoBOM
$manifest | ConvertTo-Json -Depth 5
