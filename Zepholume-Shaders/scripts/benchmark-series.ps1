[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$SeriesManifest,
    [Parameter(Mandatory)] [string]$OutputJson
)
$ErrorActionPreference = 'Stop'
# Recompute summaries from hash-bound raw captures; never trust imported summary metrics.
$seriesPath = (Resolve-Path -LiteralPath $SeriesManifest).Path
$base = Split-Path -Parent $seriesPath
$series = Get-Content -LiteralPath $seriesPath -Raw | ConvertFrom-Json
if ($series.schemaVersion -ne 1) { throw 'Unsupported series schema.' }
$aa = @($series.pairs | Where-Object kind -eq 'AA')
$ab = @($series.pairs | Where-Object kind -eq 'AB')
if ($aa.Count -lt 6 -or $ab.Count -lt 8 -or ($aa.Count + $ab.Count) -ne @($series.pairs).Count) { throw 'Require at least six AA pairs and eight AB pairs, with no other pair kinds.' }
$runIds = @{}; $rawHashes = @{}; $packHashes = @{}; $packVersions = @{}
$reference = $null; $previousEnd = [DateTimeOffset]::MinValue; $seenAB = $false; $lastOrder = ''
$metrics = @('meanFrameTimeMs','medianFrameTimeMs','p95FrameTimeMs','p99FrameTimeMs')
$pairs = @(); $runs = @()
function Require-Captured($Object, [string[]]$Fields) {
    foreach ($field in $Fields) {
        $value = $Object.$field
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value) -or [string]$value -match '^(record|replace|copy-|relative-|unavailable)') { throw "Missing captured field: $field" }
    }
}
foreach ($pair in $series.pairs) {
    if ($pair.kind -eq 'AB') { $seenAB = $true } elseif ($seenAB) { throw 'Complete AA before AB.' }
    if (@($pair.runs).Count -ne 2) { throw 'Each pair requires exactly two chronological run manifest paths.' }
    $loaded = @()
    foreach ($relative in $pair.runs) {
        $manifestPath = (Resolve-Path -LiteralPath (Join-Path $base $relative)).Path
        $runJson = Get-Content -LiteralPath $manifestPath -Raw
        $run = $runJson | ConvertFrom-Json
        if ($run.schemaVersion -ne 2) { throw 'Require run manifest schemaVersion 2.' }
        Require-Captured $run @('runId','packVersion','packSha256','profile','sceneId','sceneManifestSha256','lockedEnvironmentIdentity','role')
        if ($run.status -ne 'captured' -or $run.role -notin @('CONTROL','TREATMENT')) { throw 'Require captured status and CONTROL/TREATMENT role.' }
        foreach ($hash in @($run.packSha256,$run.sceneManifestSha256,$run.captureTool.rawFrameTimeSha256)) { if ($hash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid SHA-256.' } }
        if ($runIds.ContainsKey($run.runId)) { throw 'A run cannot be reused.' }; $runIds[$run.runId] = $true
        Require-Captured $run.world @('seed','dimension','coordinates','yaw','pitch','time','weather','cameraPathSha256','worldSnapshotSha256')
        Require-Captured $run.runtime @('minecraft','loader','shaderLoader','java','gpu','driver','graphicsApi','modsSha256','jvmArgumentsSha256')
        Require-Captured $run.settings @('resolution','renderScale','renderDistance','simulationDistance','fov','vsync','fpsCap','resourcePackSha256','shaderOptionsSha256')
        Require-Captured $run.captureTool @('name','version','rawFrameTimeCsv','rawFrameTimeSha256')
        foreach ($hash in @($run.world.cameraPathSha256,$run.world.worldSnapshotSha256,$run.runtime.modsSha256,$run.runtime.jvmArgumentsSha256,$run.settings.resourcePackSha256,$run.settings.shaderOptionsSha256)) {
            if ($hash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid captured environment SHA-256.' }
        }
        foreach ($key in @('warmupSeconds','measurementSeconds')) {
            $number = 0.0
            if (-not [double]::TryParse([string]$run.timing.$key, [ref]$number) -or -not [double]::IsFinite($number) -or $number -le 0) { throw "Invalid timing: $key" }
        }
        # Preserve the literal offset: ConvertFrom-Json may coerce timestamps
        # to local DateTime values, with behaviour differing across PS 7 versions.
        $document = [System.Text.Json.JsonDocument]::Parse([string]$runJson)
        try { $timestamp = $document.RootElement.GetProperty('timing').GetProperty('startedAtUtc').GetString() }
        finally { $document.Dispose() }
        if ([string]$timestamp -notmatch '(Z|\+00:00)$') { throw 'Capture start must be UTC.' }
        $start = [DateTimeOffset]::Parse($timestamp, [Globalization.CultureInfo]::InvariantCulture)
        if ($start.AddSeconds(-[double]$run.timing.warmupSeconds) -lt $previousEnd) { throw 'Capture/warmup intervals overlap or are out of order.' }
        $previousEnd = $start.AddSeconds([double]$run.timing.measurementSeconds)
        # Exact object equality is intentionally conservative: preserve template key order.
        $conditions = [ordered]@{}
        foreach ($key in @('profile','sceneId','sceneManifestSha256','lockedEnvironmentIdentity','world','runtime','settings')) { $conditions[$key] = $run.$key }
        $conditions.captureName = $run.captureTool.name; $conditions.captureVersion = $run.captureTool.version
        $conditions.warmupSeconds = $run.timing.warmupSeconds; $conditions.measurementSeconds = $run.timing.measurementSeconds
        $identity = $conditions | ConvertTo-Json -Depth 15 -Compress
        if ($null -eq $reference) { $reference = $identity } elseif ($identity -cne $reference) { throw 'Captured scene/environment/settings/tool/timing differ.' }
        if ($packHashes.ContainsKey($run.role) -and ($packHashes[$run.role] -ne $run.packSha256 -or $packVersions[$run.role] -ne $run.packVersion)) { throw 'Pack identity changed within a role.' }
        $packHashes[$run.role] = $run.packSha256; $packVersions[$run.role] = $run.packVersion
        $csv = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $manifestPath) $run.captureTool.rawFrameTimeCsv)).Path
        $hash = (Get-FileHash -LiteralPath $csv -Algorithm SHA256).Hash
        if ($hash -ne $run.captureTool.rawFrameTimeSha256) { throw 'Raw CSV hash mismatch.' }
        if ($rawHashes.ContainsKey($hash)) { throw 'Duplicate raw capture content; investigate capture reuse.' }; $rawHashes[$hash] = $true
        $temporary = [IO.Path]::GetTempFileName()
        try {
            & (Join-Path $PSScriptRoot 'benchmark-summarize.ps1') -InputCsv $csv -PackVersion $run.packVersion -Profile $run.profile -OutputJson $temporary
            $summary = Get-Content -LiteralPath $temporary -Raw | ConvertFrom-Json
        } finally { Remove-Item -LiteralPath $temporary -Force }
        if ([Math]::Abs($summary.capturedFrameSeconds - [double]$run.timing.measurementSeconds) -gt [Math]::Max(0.1, [double]$run.timing.measurementSeconds * 0.02)) { throw 'Frame interval total differs from declared capture duration by more than 2% (minimum tolerance 0.1 s).' }
        $loaded += [pscustomobject]@{runId=$run.runId; role=$run.role; packSha256=$run.packSha256; summary=$summary}
    }
    $order = ($loaded.role -join ',')
    if ($pair.kind -eq 'AA') {
        if ($order -ne 'CONTROL,CONTROL') { throw 'AA requires two CONTROL runs.' }
        $control = $loaded[0]; $treatment = $loaded[1]
    } else {
        if ($order -notin @('CONTROL,TREATMENT','TREATMENT,CONTROL') -or $order -eq $lastOrder) { throw 'AB requires opposite roles and alternating pair order.' }
        $lastOrder = $order
        $control = $loaded | Where-Object role -eq 'CONTROL'; $treatment = $loaded | Where-Object role -eq 'TREATMENT'
    }
    $delta = [ordered]@{}
    foreach ($metric in $metrics) {
        $delta[$metric] = 100.0 * ($treatment.summary.$metric / $control.summary.$metric - 1.0)
        if (-not [double]::IsFinite($delta[$metric])) { throw 'Non-finite relative delta.' }
    }
    $pairs += [pscustomobject]@{kind=$pair.kind; order=$order; runIds=@($loaded.runId); relativeDeltaPercent=$delta}
    $runs += $loaded
}
if ($packHashes.CONTROL -eq $packHashes.TREATMENT) { throw 'AB requires distinct pack hashes.' }
$assessment = [ordered]@{}
foreach ($metric in $metrics) {
    $noise = @($pairs | Where-Object kind -eq 'AA' | ForEach-Object { [Math]::Abs($_.relativeDeltaPercent[$metric]) } | Sort-Object)[-1]
    $deltas = @($pairs | Where-Object kind -eq 'AB' | ForEach-Object { $_.relativeDeltaPercent[$metric] } | Sort-Object)
    $middle = [int][Math]::Floor($deltas.Count / 2)
    $median = if ($deltas.Count % 2) { $deltas[$middle] } else { ($deltas[$middle-1] + $deltas[$middle]) / 2 }
    $assessment[$metric] = [ordered]@{aaMaxAbsoluteDeltaPercent=$noise; abMedianDeltaPercent=$median; observation=if ($median -lt -$noise) {'candidate-improvement-requires-review'} elseif ($median -gt $noise) {'regression-requires-review'} else {'within-observed-noise'}}
}
[ordered]@{
    schemaVersion=1; status='descriptive-series-not-performance-proof'; packs=$packHashes; metrics=$assessment; pairs=$pairs; runs=$runs
    note='A/A envelope is descriptive, not a confidence interval. Review all pairs, drift, GPU/CPU bottlenecks, telemetry and visual correctness. A median gain cannot override tail regressions. Manifest declarations are operator evidence; this tool cannot prove real gameplay or GPU attribution.'
} | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $OutputJson -Encoding utf8NoBOM
Write-Host "Wrote descriptive benchmark series: $OutputJson"
