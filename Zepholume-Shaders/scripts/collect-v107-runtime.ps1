[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [Parameter(Mandatory)][datetime]$SessionStartedUtc,
    [Parameter(Mandatory)][string]$CandidateName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][string]$RunMetadataPath,
    [string[]]$ScreenshotNames = @()
)

$ErrorActionPreference = 'Stop'
$runtime = (Resolve-Path -LiteralPath $RuntimeDirectory).ProviderPath
if (-not (Test-Path -LiteralPath $runtime -PathType Container)) { throw 'RuntimeDirectory must be a directory.' }
if ((Get-Item -LiteralPath $runtime -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'RuntimeDirectory must not be a reparse point.' }
$runId = [guid]::NewGuid().ToString('N')
$evidence = Join-Path ([IO.Path]::GetFullPath($EvidenceDirectory)) $runId
if (Test-Path -LiteralPath $evidence) { throw 'EvidenceDirectory already exists; choose a new versioned directory.' }
$ancestor = Split-Path -Parent $evidence
while ($ancestor) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'EvidenceDirectory must not traverse a reparse point.' }
    $parent = Split-Path -Parent $ancestor
    if (-not $parent -or $parent -eq $ancestor) { break }
    $ancestor = $parent
}
$runtimePrefix = $runtime.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($evidence.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'EvidenceDirectory must be outside the runtime directory.' }
foreach ($name in $ScreenshotNames) {
    if ($name -ne [IO.Path]::GetFileName($name) -or $name -notmatch '(?i)\.png$') { throw "ScreenshotNames must contain PNG basenames only: $name" }
}
$session = $SessionStartedUtc.ToUniversalTime()
if ($CandidateName -ne [IO.Path]::GetFileName($CandidateName) -or $CandidateName -notmatch '(?i)\.zip$') { throw 'CandidateName must be a ZIP basename.' }
$expectedHash = $ExpectedSha256.ToUpperInvariant()
$metadata = Get-Content -LiteralPath $RunMetadataPath -Raw | ConvertFrom-Json
$requiredFields = @('minecraftVersion','loader','iris','sodium','java','gpu','driver','shaderProfile','shaderOptions','resolution','renderScale','renderDistance','simulationDistance','vsync','fpsCap','world','viewpoint','timeAndWeather')
foreach ($field in $requiredFields) {
    if (-not $metadata.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$metadata.$field)) { throw "Run metadata missing: $field (use NOT RECORDED when unknown)." }
}
$manifest = [ordered]@{
    schemaVersion = 2; runId = $runId; classification = 'COLLECTED_UNVERIFIED_RUNTIME_EVIDENCE'; activation = 'UNVERIFIED'
    capturedUtc = [datetime]::UtcNow.ToString('o'); sessionStartedUtc = $session.ToString('o')
    runtimeDirectory = $runtime; sourceCommit = $SourceCommit.ToLowerInvariant(); settings = $metadata
    candidate = [ordered]@{ path = (Join-Path $runtime "shaderpacks/$candidateName"); expectedSha256 = $expectedHash; actualSha256 = $null; matches = $false }
    files = @(); missing = @(); rejected = @()
}
function Safe-Source([string]$relative) {
    $current = $runtime
    foreach ($part in ($relative -split '[/\\]')) {
        if (-not $part -or $part -eq '.' -or $part -eq '..') { throw "Invalid evidence path: $relative" }
        $current = Join-Path $current $part
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return $null }
        }
    }
    return $current
}
function Add-File([string]$relative, [bool]$redact = $false, [bool]$requireFresh = $true) {
    $relative = $relative.Replace('\','/')
    $source = Safe-Source $relative
    if (-not $source) { $manifest.rejected += "$relative (reparse point)"; return }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { $manifest.missing += $relative; return }
    $item = Get-Item -LiteralPath $source
    if ($requireFresh -and $item.LastWriteTimeUtc -lt $session) { $manifest.rejected += "$relative (older than session start)"; return }
    $target = Join-Path $evidence $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    if ($redact) {
        $safeLines = foreach ($line in (Get-Content -LiteralPath $source)) {
            if ($line -match '(?i)access.?token|authorization:|bearer\s+|password|client.?secret|account|authentication|user.?name|profile.?id|session.?id|\buuid\b|\[CHAT\]|<[^>]+>') { continue }
            $line -replace '(?i)[A-Z]:\\Users\\[^\\\s]+', '[USER_HOME]' -replace 'https?://\S+', '[URL]' -replace '\b(?:\d{1,3}\.){3}\d{1,3}\b', '[IP]' -replace '[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[EMAIL]'
        }
        [IO.File]::WriteAllLines($target, [string[]]@($safeLines), [Text.UTF8Encoding]::new($false))
    } else { Copy-Item -LiteralPath $source -Destination $target }
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $copiedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if (-not $redact -and $sourceHash -cne $copiedHash) { throw "Evidence copy hash mismatch: $relative" }
    $manifest.files += [ordered]@{ origin = $source; path = $relative; modifiedUtc = $item.LastWriteTimeUtc.ToString('o'); sourceSha256 = $sourceHash; copiedSha256 = $copiedHash; redacted = $redact; predatesSession = ($item.LastWriteTimeUtc -lt $session) }
}
$candidate = Safe-Source "shaderpacks/$candidateName"
if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    $manifest.candidate.actualSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    $manifest.candidate.matches = $manifest.candidate.actualSha256 -ceq $expectedHash
} else { throw "Staged candidate missing: shaderpacks/$candidateName" }
if (-not $manifest.candidate.matches) { throw 'Staged candidate SHA-256 does not match the supplied expected hash; no evidence collected.' }
Add-File 'logs/latest.log' $true
foreach ($relative in @('options.txt', 'optionsshaders.txt', 'config/iris.properties', "shaderpacks/$candidateName.txt")) { Add-File $relative $false $false }
$patched = Safe-Source 'patched_shaders'
if ($patched -and (Test-Path -LiteralPath $patched -PathType Container)) {
    # Do not follow links while traversing loader output.
    $queue = [Collections.Generic.Queue[string]]::new(); $queue.Enqueue($patched); $count = 0
    while ($queue.Count) {
        $directory = $queue.Dequeue()
        foreach ($entry in (Get-ChildItem -LiteralPath $directory -Force)) {
            $relative = [IO.Path]::GetRelativePath($runtime, $entry.FullName)
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { $manifest.rejected += "$relative (reparse point)"; continue }
            if ($entry.PSIsContainer) { $queue.Enqueue($entry.FullName); continue }
            if ($entry.Extension -notin @('.vsh','.fsh','.gsh','.csh','.glsl','.txt','.log')) { $manifest.rejected += "$relative (unexpected extension)"; continue }
            Add-File $relative ($entry.Extension -eq '.log'); $count++
        }
    }
    if (-not $count) { $manifest.missing += 'patched_shaders/ (no supported files)' }
} else { $manifest.missing += 'patched_shaders/' }
foreach ($name in $ScreenshotNames) {
    Add-File "screenshots/$name"
}
if (-not @($manifest.files | Where-Object { $_.path -eq 'logs/latest.log' }).Count) { $manifest.classification = 'MISSING_FRESH_SESSION_LOG_NO_RUNTIME_PROOF' }
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'session-manifest.json') -Encoding utf8NoBOM
$manifest | ConvertTo-Json -Depth 8
