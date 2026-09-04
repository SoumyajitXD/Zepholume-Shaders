[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$SummaryA,
    [Parameter(Mandatory)] [string]$RunManifestA,
    [Parameter(Mandatory)] [string]$SummaryB,
    [Parameter(Mandatory)] [string]$RunManifestB,
    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
function Read-Json([string]$Path) { Get-Content -LiteralPath (Resolve-Path -LiteralPath $Path) -Raw | ConvertFrom-Json }
$a = Read-Json $SummaryA; $b = Read-Json $SummaryB
$runA = Read-Json $RunManifestA; $runB = Read-Json $RunManifestB
foreach ($run in @($runA, $runB)) {
    foreach ($property in @('packVersion','packSha256','profile','sceneId','sceneManifestSha256','lockedEnvironmentIdentity')) {
        if ([string]::IsNullOrWhiteSpace([string]$run.$property) -or [string]$run.$property -match '^record|^replace') { throw "Run manifest has no captured $property." }
    }
}
foreach ($property in @('profile','sceneId','sceneManifestSha256','lockedEnvironmentIdentity')) {
    if ([string]$runA.$property -ne [string]$runB.$property) { throw "Runs are not comparable: $property differs." }
}
if ($a.packVersion -ne $runA.packVersion -or $b.packVersion -ne $runB.packVersion) { throw 'Summary packVersion does not match its run manifest.' }
if ($a.profile -ne $runA.profile -or $b.profile -ne $runB.profile) { throw 'Summary profile does not match its run manifest.' }
$result = [ordered]@{
    schemaVersion = 1; status = 'measured-input-comparison'; sceneId = $runA.sceneId; profile = $runA.profile
    runA = [ordered]@{ packVersion=$runA.packVersion; packSha256=$runA.packSha256; samples=$a.samples; medianFrameTimeMs=$a.medianFrameTimeMs; p95FrameTimeMs=$a.p95FrameTimeMs; p99FrameTimeMs=$a.p99FrameTimeMs }
    runB = [ordered]@{ packVersion=$runB.packVersion; packSha256=$runB.packSha256; samples=$b.samples; medianFrameTimeMs=$b.medianFrameTimeMs; p95FrameTimeMs=$b.p95FrameTimeMs; p99FrameTimeMs=$b.p99FrameTimeMs }
    deltasBMinusA = [ordered]@{ medianFrameTimeMs=([double]$b.medianFrameTimeMs - [double]$a.medianFrameTimeMs); p95FrameTimeMs=([double]$b.p95FrameTimeMs - [double]$a.p95FrameTimeMs); p99FrameTimeMs=([double]$b.p99FrameTimeMs - [double]$a.p99FrameTimeMs) }
    note = 'Observed delta from two individually summarized inputs. Do not infer a general performance result without replicated A/B/A/B runs and review of capture conditions.'
}
if (-not $OutputJson) { $OutputJson = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $SummaryB)) 'benchmark-comparison.json' }
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputJson -Encoding utf8NoBOM
Write-Host "Wrote benchmark comparison: $OutputJson"
