[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameDirectory,
    [Parameter(Mandatory)][datetime]$SessionStartedUtc,
    [Parameter(Mandatory)][ValidateSet('phase7','phase8','off')][string]$Build,
    [Parameter(Mandatory)][ValidateSet('Potato','Low','Balanced','High','Ultra','Off')][string]$Profile,
    [string[]]$ScreenshotNames = @()
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $gameRoot -PathType Container)) { throw 'GameDirectory must be a directory.' }
$sessionUtc = $SessionStartedUtc.ToUniversalTime()
if ($sessionUtc -gt [datetime]::UtcNow) { throw 'SessionStartedUtc is in the future.' }
if (($Build -eq 'off') -ne ($Profile -eq 'Off')) { throw 'Build off requires Profile Off; enabled builds require a shader profile.' }
if (@($ScreenshotNames | Select-Object -Unique).Count -ne $ScreenshotNames.Count) { throw 'Duplicate screenshot names are rejected.' }

function Assert-SafePath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not ($full -eq $gameRoot -or $full.StartsWith($gameRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) { throw 'Path escapes GameDirectory.' }
    $cursor = $full
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point rejected: $cursor" }
        $cursor = Split-Path -Parent $cursor
    }
}
Assert-SafePath $gameRoot
$logPath = Join-Path $gameRoot 'logs/latest.log'
Assert-SafePath $logPath
if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { throw 'Missing fresh logs/latest.log; no evidence collected.' }
if ((Get-Item -LiteralPath $logPath).LastWriteTimeUtc -lt $sessionUtc) { throw 'Log is older than session start; no evidence collected.' }

$candidate = $null
if ($Build -ne 'off') {
    $name = "Zepholume-Shaders-1.0.6-dev-$Build.zip"
    $expected = if ($Build -eq 'phase8') { 'CBCEAF7BE8CD50B6C7DC4141F27CE05D4C4735DA69EC6B8096C82D21A92C880B' } else { '6297A14940298B4DA964DE7E9BEDCF17E9A7007D53DF86BEA298C2DC169748B6' }
    $packPath = Join-Path $gameRoot "shaderpacks/$name"
    Assert-SafePath $packPath
    $actual = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash
    if ($actual -cne $expected) { throw 'Candidate hash mismatch; no evidence collected.' }
    $candidate = [ordered]@{file=$name;sha256=$actual;identityVerified=$true;selectionInGame='OPERATOR_ASSERTED_NOT_VERIFIED'}
}

$sources = [Collections.Generic.List[object]]::new()
$sources.Add([pscustomobject]@{relative='logs/latest.log';diagnostic=$true})
$patchedRoot = Join-Path $gameRoot 'patched_shaders'
Assert-SafePath $patchedRoot
if (Test-Path -LiteralPath $patchedRoot -PathType Container) {
    foreach ($item in Get-ChildItem -LiteralPath $patchedRoot -Recurse -Force) {
        Assert-SafePath $item.FullName
        if (-not $item.PSIsContainer) {
            if ($item.Extension -notin @('.vsh','.fsh','.glsl','.txt','.log')) { throw "Unexpected patched extension: $($item.Name)" }
            if ($item.LastWriteTimeUtc -lt $sessionUtc) { throw "Patched file older than session: $($item.Name)" }
            $sources.Add([pscustomobject]@{relative=[IO.Path]::GetRelativePath($gameRoot,$item.FullName).Replace('\','/');diagnostic=($item.Extension -in @('.txt','.log'))})
        }
    }
}
foreach ($name in $ScreenshotNames) {
    if ($name -ne [IO.Path]::GetFileName($name) -or $name -notmatch '(?i)\.png$') { throw 'ScreenshotNames requires PNG basenames.' }
    $path = Join-Path $gameRoot "screenshots/$name"
    Assert-SafePath $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LastWriteTimeUtc -lt $sessionUtc) { throw "Missing or old screenshot: $name" }
    $sources.Add([pscustomobject]@{relative="screenshots/$name";diagnostic=$false})
}

$destination = Join-Path $projectRoot ('artifacts/phase9/runtime-evidence/{0}-{1}-{2}-{3}' -f [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'),$Build,$Profile,[guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $destination) { throw 'Evidence destination already exists.' }
New-Item -ItemType Directory -Path $destination | Out-Null
$records = @()
foreach ($source in $sources) {
    $path = Join-Path $gameRoot $source.relative
    Assert-SafePath $path
    $info = Get-Item -LiteralPath $path
    if ($info.LastWriteTimeUtc -lt $sessionUtc) { throw 'Source timestamp became stale during collection.' }
    $sourceHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $target = Join-Path $destination $source.relative
    if (Test-Path -LiteralPath $target) { throw 'Evidence target exists; no overwrite permitted.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    if ($source.diagnostic) {
        $safe = foreach ($line in Get-Content -LiteralPath $path) {
            if ($line -match '(?i)access.?token|authorization:|bearer\s+|password|client.?secret|account|authentication|user.?name|profile.?id|session.?id|\buuid\b|\[CHAT\]|<[^>]+>|Setting user:') { continue }
            $line -replace '(?i)[A-Z]:\\Users\\[^\\\s]+','[USER_HOME]' -replace 'https?://\S+','[URL]' -replace '\b(?:\d{1,3}\.){3}\d{1,3}\b','[IP]' -replace '[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[EMAIL]'
        }
        [IO.File]::WriteAllLines($target,[string[]]@($safe),[Text.UTF8Encoding]::new($false))
    } else { Copy-Item -LiteralPath $path -Destination $target -ErrorAction Stop }
    $copiedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if (-not $source.diagnostic -and $sourceHash -cne $copiedHash) { throw 'Copy hash mismatch; evidence incomplete.' }
    if ($sourceHash -cne (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash) { throw 'Source changed during collection; retry after pausing game.' }
    $records += [ordered]@{path=$source.relative;sourceBytes=$info.Length;sourceModifiedUtc=$info.LastWriteTimeUtc.ToString('o');sourceSha256=$sourceHash;copiedSha256=$copiedHash;redacted=$source.diagnostic}
}
$manifest = [ordered]@{
    schemaVersion=1;classification='COLLECTED_UNVERIFIED_OPERATOR_ASSERTIONS';sessionStartedUtc=$sessionUtc.ToString('o');collectedAtUtc=[datetime]::UtcNow.ToString('o')
    build=$Build;profile=$Profile;candidate=$candidate;gameDirectory=$gameRoot;files=$records
    patchedOutputState=if (@($records | Where-Object path -like 'patched_shaders/*').Count) {'OBSERVED_NOT_INSPECTED'} else {'BLOCKED_NO_PATCHED_OUTPUT'}
    runtimeResult='NOT_INFERRED';boundary='Fresh timestamps and installed ZIP identity do not establish selected build, successful loading, rendering, scene correctness, compatibility or performance. Inspect log and screenshots. Operator must record scene/settings and versions separately.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destination 'session-manifest.json') -Encoding utf8NoBOM
Write-Output $destination
