[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('Iris','Oculus')] [string]$Target,
    [Parameter(Mandatory)] [ValidateSet('CONTROL','TREATMENT')] [string]$Role,
    [Parameter(Mandatory)] [ValidateSet('Benchmark','Visual')] [string]$Phase,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{2,80}$')] [string]$RunId,
    [Parameter(Mandatory)] [ValidateSet('Prepare','Collect')] [string]$Action,
    [string]$RawFrameTimeCsv
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $projectRoot 'runtime'
$captureRoot = Join-Path $projectRoot 'artifacts/v104-runtime-capture'
$control = [ordered]@{ role='CONTROL'; version='1.0.3-dev'; filename='Zepholume-Shaders-1.0.3-dev.zip'; sha256='C8C654607AF3A7A6E42966EDB75DA7ED17AA99A2CF8FBD94BF81A5899D7448A4' }
$treatment = [ordered]@{ role='TREATMENT'; version='1.0.4'; filename='Zepholume-Shaders-1.0.4.zip'; sha256='4E0B66EA99B43EF46AFB26394D68C18D34CAB38DE25255F03E97489A66E1B099' }
$packages = @($control, $treatment)
$selected = $packages | Where-Object role -eq $Role
$environmentManifest = Join-Path $runtimeRoot 'manifests/runtime-environments.json'
$environment = (Get-Content -LiteralPath $environmentManifest -Raw | ConvertFrom-Json).environments.$($Target.ToLowerInvariant())
if ($null -eq $environment) { throw "No runtime environment for $Target." }
$gameDir = [IO.Path]::GetFullPath($environment.gameDirectory)
$allowedRoot = [IO.Path]::GetFullPath($runtimeRoot) + [IO.Path]::DirectorySeparatorChar
if (-not $gameDir.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe game directory: $gameDir" }
$artifactDir = Join-Path $captureRoot (Join-Path $Target.ToLowerInvariant() $RunId)

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-NoGameProcess {
    $active = @(Get-Process -Name java,javaw,MinecraftLauncher -ErrorAction SilentlyContinue)
    if ($active.Count -gt 0) { throw 'Minecraft/Java/launcher process is active. Close it before staging or collecting this run.' }
}
function Copy-FileEvidence([string]$Source, [string]$DestinationRoot, [System.Collections.Generic.List[object]]$Items) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    $relative = [IO.Path]::GetRelativePath($gameDir, $Source)
    $destination = Join-Path $DestinationRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination
    $Items.Add([ordered]@{path=$relative; sha256=(Get-Sha256 $destination); bytes=(Get-Item -LiteralPath $destination).Length})
}
function Copy-TreeEvidence([string]$Source, [string]$DestinationRoot, [System.Collections.Generic.List[object]]$Items) {
    if (Test-Path -LiteralPath $Source -PathType Container) {
        Get-ChildItem -LiteralPath $Source -File -Recurse -Force | ForEach-Object { Copy-FileEvidence $_.FullName $DestinationRoot $Items }
    }
}
function Get-ExistingGeneratedEvidence {
    return @(Get-ChildItem -LiteralPath $gameDir -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\(logs|crash-reports|patched_shaders|screenshots)\\' -and $_.Length -gt 0 })
}
function Get-SelectedPackText {
    $paths = @('optionsshaders.txt','config/iris.properties','config/oculus.properties') | ForEach-Object { Join-Path $gameDir $_ }
    return (($paths | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n")
}

if ($Action -eq 'Prepare') {
    Assert-NoGameProcess
    if (Test-Path -LiteralPath $artifactDir) { throw "Run ID already has artifacts: $artifactDir. Use a new run ID; never overwrite a run." }
    & (Join-Path $PSScriptRoot 'runtime-test.ps1') -Target $Target -Action Verify
    $leftovers = Get-ExistingGeneratedEvidence
    if ($leftovers.Count -gt 0) {
        throw "Generated evidence already exists in the isolated instance ($($leftovers.Count) file(s)). Review/collect it, then run runtime-test.ps1 -Target $Target -Action Reset before preparing a new run."
    }
    foreach ($package in $packages) {
        $source = Join-Path $projectRoot ('dist/' + $package.filename)
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing source package: $source" }
        if ((Get-Sha256 $source) -cne $package.sha256) { throw "Source package hash mismatch: $($package.filename)" }
        $destination = Join-Path $gameDir ('shaderpacks/' + $package.filename)
        if (Test-Path -LiteralPath $destination) {
            if ((Get-Sha256 $destination) -cne $package.sha256) { throw "Refusing to overwrite a different staged package: $destination" }
        } else {
            Copy-Item -LiteralPath $source -Destination $destination
        }
    }
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    $scenePath = Join-Path $projectRoot 'bench/scene-manifest.json'
    $templatePath = Join-Path $projectRoot 'bench/run-manifest-template.json'
    $run = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
    $run.status = 'prepared-not-captured'; $run.runId = $RunId; $run.role = $Role; $run.packVersion = $selected.version; $run.packSha256 = $selected.sha256
    $run.sceneManifestSha256 = Get-Sha256 $scenePath
    $run | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $artifactDir 'run-manifest.json') -Encoding utf8NoBOM
    Copy-Item -LiteralPath $scenePath,$environmentManifest,$templatePath -Destination $artifactDir
    [ordered]@{runId=$RunId; target=$Target; role=$Role; phase=$Phase; preparedAtUtc=[DateTime]::UtcNow.ToString('o'); package=$selected; sceneManifestSha256=(Get-Sha256 $scenePath)} |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactDir 'prepare-manifest.json') -Encoding utf8NoBOM
    $debugInstruction = if ($Target -eq 'Iris') { 'In Iris shader-pack selection, enable debug output with Ctrl+D, then restart before the run; do not change any benchmark setting afterward.' } else { 'Enable Oculus debug/patched-shader output only if its installed UI exposes it; record unavailable debug output rather than inventing it.' }
    $collectCommand = ".\\scripts\\v104-runtime-capture.ps1 -Target $Target -Role $Role -Phase $Phase -RunId $RunId -Action Collect"
    if ($Phase -eq 'Benchmark') { $collectCommand += ' -RawFrameTimeCsv <absolute-path-to-csv>' }
    @(
        "Run ID: $RunId", "Role/package: $Role / $($selected.filename)", "Phase: $Phase", 'Use the disposable isolated instance named in runtime/manifests/runtime-environments.json.',
        'Select exactly the named package above. Use Balanced, 1920x1080, FOV 70, VSync off, FPS Unlimited, render distance 16, simulation distance 12.',
        'Primary benchmark scene is forest-overlook. Its current manifest lacks fixed camera/seed values: record and freeze those values before the first A/A run. Do not start a comparable series until they are present.',
        $debugInstruction,
        'Warm up 30 seconds. Capture a 60-second raw per-frame CSV with frameTimeMs in milliseconds; no menus, reloads, loading, or settings changes during the interval.',
        'For visual phase, take a lossless screenshot and match the requested scene conditions. Close Minecraft normally when complete.',
        "Then run this exact collection command: $collectCommand"
    ) | Set-Content -LiteralPath (Join-Path $artifactDir 'OPERATOR-INSTRUCTIONS.txt') -Encoding utf8NoBOM
    Write-Host "Prepared protected run: $artifactDir"
    Write-Host "Read OPERATOR-INSTRUCTIONS.txt; no game was launched and no credentials were accessed."
    return
}

Assert-NoGameProcess
if (-not (Test-Path -LiteralPath $artifactDir -PathType Container)) { throw "Unknown run ID: $RunId. Prepare it first." }
if (Test-Path -LiteralPath (Join-Path $artifactDir 'collection-manifest.json')) { throw "Run already collected: $RunId. Never overwrite collected evidence." }
if ($Phase -eq 'Benchmark' -and [string]::IsNullOrWhiteSpace($RawFrameTimeCsv)) { throw 'Benchmark collection requires -RawFrameTimeCsv.' }
if ($Phase -eq 'Benchmark' -and -not (Test-Path -LiteralPath $RawFrameTimeCsv -PathType Leaf)) { throw "Missing raw frame-time CSV: $RawFrameTimeCsv" }
$selectedText = Get-SelectedPackText
if ($selectedText -notmatch [regex]::Escape($selected.filename)) { throw "Selected package cannot be confirmed from isolated shader configuration: $($selected.filename)" }
$items = [System.Collections.Generic.List[object]]::new()
$evidenceDir = Join-Path $artifactDir 'evidence'
foreach ($relative in @('logs/latest.log','logs/debug.log','options.txt','optionsshaders.txt','config/iris.properties','config/oculus.properties')) { Copy-FileEvidence (Join-Path $gameDir $relative) $evidenceDir $items }
foreach ($relative in @('patched_shaders','screenshots','crash-reports')) { Copy-TreeEvidence (Join-Path $gameDir $relative) $evidenceDir $items }
if ($Phase -eq 'Benchmark') {
    $csvDestination = Join-Path $artifactDir 'raw-frametime.csv'
    Copy-Item -LiteralPath $RawFrameTimeCsv -Destination $csvDestination
    $items.Add([ordered]@{path='raw-frametime.csv';sha256=(Get-Sha256 $csvDestination);bytes=(Get-Item -LiteralPath $csvDestination).Length})
}
$logs = @($items | Where-Object path -like 'logs/*') | ForEach-Object { Get-Content -LiteralPath (Join-Path $evidenceDir $_.path) -Raw }
$warnings = @([regex]::Matches(($logs -join "`n"), '(?im)^.*(?:shader|iris|oculus).*(?:warn|error|failed|fallback|link).*$') | ForEach-Object Value)
[ordered]@{runId=$RunId;target=$Target;role=$Role;phase=$Phase;collectedAtUtc=[DateTime]::UtcNow.ToString('o');selectedPackage=$selected;selectedPackageConfirmed=$true;patchedShadersCollected=@($items | Where-Object path -like 'patched_shaders/*').Count;screenshotsCollected=@($items | Where-Object path -like 'screenshots/*').Count;rawFrameTimeSha256=if ($Phase -eq 'Benchmark') {(Get-Sha256 (Join-Path $artifactDir 'raw-frametime.csv'))} else {$null};loaderRelevantLogLines=$warnings;files=@($items)} |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $artifactDir 'collection-manifest.json') -Encoding utf8NoBOM
Write-Host "Collected immutable run evidence: $artifactDir"
Write-Host 'Review collection-manifest.json. Logged warnings/errors and absent patched shaders are evidence to investigate, not automatic proof of a valid run.'
