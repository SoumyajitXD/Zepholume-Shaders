[CmdletBinding()]
param(
    [ValidateSet('iris-1.20.1','oculus-1.20.1')][string]$Lane = 'iris-1.20.1',
    [Parameter(Mandatory)][datetime]$SessionStartedUtc,
    [string[]]$ScreenshotNames = @(),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$laneRoot = Join-Path $sourceRoot "runtime/v106-phase2/$Lane"
$evidenceRoot = Join-Path $sourceRoot 'artifacts/v106-runtime-evidence'
$candidateName = 'Zepholume-Shaders-1.0.6-dev-phase3.zip'
$expectedCandidateHash = '8BC997B1CDBCB17ABF5D583E76B09B2E427873B2A24CA1B30D593EEBF5CB85B5'
if (-not (Test-Path -LiteralPath $laneRoot -PathType Container)) { throw "Missing isolated lane: $laneRoot" }
$laneRoot = (Resolve-Path -LiteralPath $laneRoot).Path
$sessionUtc = $SessionStartedUtc.ToUniversalTime()
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$destination = Join-Path $evidenceRoot "$stamp-$Lane"
if (Test-Path -LiteralPath $destination) { throw "Evidence directory exists: $destination" }

$manifest = [ordered]@{
    schemaVersion=1; classification=if ($DryRun) { 'DRY_RUN_NO_MINECRAFT_EVIDENCE' } else { 'COLLECTED_UNVERIFIED_RUNTIME_EVIDENCE' }
    lane=$Lane; sessionStartedUtc=$sessionUtc.ToString('o'); collectedAtUtc=[DateTime]::UtcNow.ToString('o')
    sourceDirectory=$laneRoot; candidate=[ordered]@{file=$candidateName; expectedSha256=$expectedCandidateHash; actualSha256=$null; matches=$false}
    loaderVersions='unverified; inspect collected game log'; gameVersion='unverified; inspect collected game log'
    environment=[ordered]@{ os=[Environment]::OSVersion.VersionString; powershell=$PSVersionTable.PSVersion.ToString(); architecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() }
    stagedMods=@()
    files=@(); missing=@(); rejected=@()
}
$modsRoot = Join-Path $laneRoot 'mods'
if (Test-Path -LiteralPath $modsRoot -PathType Container) {
    $manifest.stagedMods = @(Get-ChildItem -LiteralPath $modsRoot -File -Filter '*.jar' | ForEach-Object {
        [ordered]@{ file=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
}
$candidate = Join-Path $laneRoot "shaderpacks/$candidateName"
if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    $manifest.candidate.actualSha256 = $actual
    $manifest.candidate.matches = $actual -ceq $expectedCandidateHash
} else { $manifest.missing += "shaderpacks/$candidateName" }

function Add-EvidenceFile([string]$relative) {
    # GetRelativePath returns backslashes on Windows. Normalize before matching
    # diagnostic directories so crash reports receive the same redaction as logs.
    $relative = $relative.Replace('\','/')
    $source = Join-Path $laneRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { $manifest.missing += $relative; return }
    $item = Get-Item -LiteralPath $source
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $manifest.rejected += "$relative (reparse point)"; return }
    if ($item.LastWriteTimeUtc -lt $sessionUtc) { $manifest.rejected += "$relative (older than session start)"; return }
    $isDiagnosticText = $relative -like 'logs/*' -or $relative -like 'crash-reports/*'
    $record = [ordered]@{ path=$relative.Replace('\','/'); sourceBytes=$item.Length; modifiedUtc=$item.LastWriteTimeUtc.ToString('o'); sourceSha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash; copiedSha256=$null; redacted=$isDiagnosticText }
    $manifest.files += $record
    if (-not $DryRun) {
        $target = Join-Path $destination $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        if ($isDiagnosticText) {
            $safeLines = foreach ($line in (Get-Content -LiteralPath $source)) {
                if ($line -match '(?i)access.?token|authorization:|bearer\s+|password|client.?secret|account|authentication|user.?name|profile.?id|session.?id|\buuid\b|\[CHAT\]|<[^>]+>') { continue }
                $line -replace '(?i)[A-Z]:\\Users\\[^\\\s]+', '[USER_HOME]' -replace 'https?://\S+', '[URL]' -replace '\b(?:\d{1,3}\.){3}\d{1,3}\b', '[IP]' -replace '[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[EMAIL]'
            }
            [IO.File]::WriteAllLines($target, [string[]]@($safeLines), [Text.UTF8Encoding]::new($false))
        } else {
            Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop
        }
        $record.copiedSha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if (-not $isDiagnosticText -and $record.copiedSha256 -cne $record.sourceSha256) { throw "Evidence copy hash mismatch: $relative" }
    }
}

Add-EvidenceFile 'logs/latest.log'
foreach ($folder in @('patched_shaders','crash-reports')) {
    $root = Join-Path $laneRoot $folder
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { $manifest.missing += "$folder/"; continue }
    $files = @(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
    if ($files.Count -eq 0) { $manifest.missing += "$folder/ (no files)" }
    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($laneRoot, $file.FullName).Replace('\','/')
        if ($folder -eq 'patched_shaders' -and $file.Extension -notin @('.vsh','.fsh','.glsl','.txt','.log')) { $manifest.rejected += "$relative (unexpected extension)"; continue }
        Add-EvidenceFile $relative
    }
}
foreach ($name in $ScreenshotNames) {
    if ($name -ne [IO.Path]::GetFileName($name) -or $name -notmatch '\.png$') { throw "ScreenshotNames must contain PNG basenames only: $name" }
    Add-EvidenceFile "screenshots/$name"
}
if (-not $DryRun -and -not @($manifest.files | Where-Object path -eq 'logs/latest.log').Count) {
    $manifest.classification = 'MISSING_FRESH_SESSION_LOG_NO_RUNTIME_PROOF'
}
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destination 'session-manifest.json') -Encoding utf8NoBOM
}
$manifest | ConvertTo-Json -Depth 8
if (-not $DryRun) { Write-Host "Evidence copied to: $destination" }
