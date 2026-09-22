[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$scripts = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-benchmark-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$checks = 0
function Assert-Close([double]$Actual, [double]$Expected) {
    if ([Math]::Abs($Actual - $Expected) -gt 1e-9) { throw "Expected $Expected, got $Actual" }
    $script:checks++
}
function Reject([string]$Name, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Accepted invalid fixture: $Name" }
    $script:checks++
    Write-Host "Rejected as expected: $Name"
}
function Write-Json($Value, [string]$Path) { $Value | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM }
try {
    $csv = Join-Path $work 'sample.csv'; $summaryPath = Join-Path $work 'summary.json'
    Set-Content -LiteralPath $csv -Value "frameTimeMs`n1`n2`n3`n4" -Encoding utf8NoBOM
    & (Join-Path $scripts 'benchmark-summarize.ps1') -InputCsv $csv -PackVersion 1.0.4-dev -Profile Balanced -OutputJson $summaryPath
    $s = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Assert-Close $s.meanFrameTimeMs 2.5
    Assert-Close $s.medianFrameTimeMs 2
    Assert-Close $s.p95FrameTimeMs 4
    Assert-Close $s.p99EquivalentFps 250
    Assert-Close $s.averageFps 400
    Assert-Close $s.frameTimeVarianceMs2 1.25
    Assert-Close $s.frameTimeStdDevMs ([Math]::Sqrt(1.25))
    Assert-Close $s.capturedFrameSeconds 0.01
    foreach ($bad in @('NaN','Infinity','-Infinity','1e999','0','-1','bad','1e-320')) {
        Set-Content -LiteralPath $csv -Value "frameTimeMs`n$bad" -Encoding utf8NoBOM
        Reject "sample $bad" { & (Join-Path $scripts 'benchmark-summarize.ps1') -InputCsv $csv -PackVersion 1.0.4-dev -Profile Balanced -OutputJson $summaryPath }
    }
    Set-Content -LiteralPath $csv -Value 'frameTimeMs' -Encoding utf8NoBOM
    Reject 'empty CSV' { & (Join-Path $scripts 'benchmark-summarize.ps1') -InputCsv $csv -PackVersion 1.0.4-dev -Profile Balanced -OutputJson $summaryPath }

    # Synthetic fixtures exercise inference gates only. They are never runtime evidence.
    $template = Join-Path (Split-Path -Parent $scripts) 'bench/run-manifest-template.json'
    $pairs = @(); $runPaths = @(); $abPairs = @()
    for ($index = 0; $index -lt 28; $index++) {
        $run = Get-Content -LiteralPath $template -Raw | ConvertFrom-Json
        $run.status = 'captured'; $run.runId = "synthetic-$index"
        if ($index -lt 12) { $run.role = 'CONTROL' }
        else {
            $abIndex = [int][Math]::Floor(($index - 12) / 2)
            $isFirst = (($index - 12) % 2) -eq 0
            $run.role = if (($abIndex % 2 -eq 0 -and $isFirst) -or ($abIndex % 2 -ne 0 -and -not $isFirst)) { 'CONTROL' } else { 'TREATMENT' }
        }
        $run.packVersion = if ($run.role -eq 'CONTROL') { '1.0.3-dev' } else { '1.0.4-dev' }
        $run.packSha256 = if ($run.role -eq 'CONTROL') { 'A' * 64 } else { 'B' * 64 }
        $run.sceneId = 'synthetic-scene'; $run.sceneManifestSha256 = 'C' * 64; $run.lockedEnvironmentIdentity = 'synthetic-environment'
        foreach ($object in @($run.world,$run.runtime,$run.settings)) {
            foreach ($property in @($object.PSObject.Properties)) {
                if ($property.Name -like '*Sha256') { $property.Value = 'D' * 64 }
                elseif ([string]$property.Value -match '^record') { $property.Value = 'synthetic' }
            }
        }
        $run.captureTool.name = 'synthetic-test'; $run.captureTool.version = '1'
        $run.captureTool.rawFrameTimeCsv = "run-$index.csv"
        $raw = Join-Path $work $run.captureTool.rawFrameTimeCsv
        $value = 6000.0 + $index * 0.1
        if ($run.role -eq 'TREATMENT') { $value -= 30.0 }
        $values = @(for ($frame = 0; $frame -lt 10; $frame++) { ($value + $frame * 0.01).ToString('R',[Globalization.CultureInfo]::InvariantCulture) })
        Set-Content -LiteralPath $raw -Value (@('frameTimeMs') + $values) -Encoding utf8NoBOM
        $run.captureTool.rawFrameTimeSha256 = (Get-FileHash -LiteralPath $raw).Hash
        $run.timing.startedAtUtc = ([DateTimeOffset]::Parse('2026-01-01T00:00:00Z').AddSeconds($index * 120)).ToString('yyyy-MM-ddTHH:mm:ssZ')
        if ($index -eq 1) { $run.timing.startedAtUtc = $run.timing.startedAtUtc.Replace('Z','+00:00') }
        $runPaths += "run-$index.json"
        Write-Json $run (Join-Path $work $runPaths[-1])
        if ($index % 2 -eq 1) {
            $pair = [ordered]@{kind=if ($index -lt 12) {'AA'} else {'AB'}; runs=@($runPaths[$index-1],$runPaths[$index])}
            $pairs += $pair
            if ($pair.kind -eq 'AB') { $abPairs += $pair }
        }
    }
    $series = [ordered]@{schemaVersion=1; pairs=$pairs}
    $seriesPath = Join-Path $work 'series.json'; $resultPath = Join-Path $work 'result.json'
    Write-Json $series $seriesPath
    $analyze = { & (Join-Path $scripts 'benchmark-series.ps1') -SeriesManifest $seriesPath -OutputJson $resultPath }
    & $analyze
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Assert-Close $result.runs.Count 28
    Assert-Close $result.pairs.Count 14
    Write-Json $result.runs[0].summary (Join-Path $work 'a-summary.json')
    Write-Json $result.runs[1].summary (Join-Path $work 'b-summary.json')
    & (Join-Path $scripts 'benchmark-compare.ps1') -SummaryA (Join-Path $work 'a-summary.json') -RunManifestA (Join-Path $work 'run-0.json') -SummaryB (Join-Path $work 'b-summary.json') -RunManifestB (Join-Path $work 'run-1.json') -OutputJson (Join-Path $work 'legacy-comparison.json')
    $legacy = Get-Content -LiteralPath (Join-Path $work 'legacy-comparison.json') -Raw | ConvertFrom-Json
    Assert-Close $legacy.deltasBMinusA.medianFrameTimeMs 0.1
    foreach ($metric in @('meanFrameTimeMs','medianFrameTimeMs','p95FrameTimeMs','p99FrameTimeMs')) {
        if ($result.metrics.$metric.observation -ne 'candidate-improvement-requires-review') { throw "Wrong paired direction or noise comparison: $metric" }
        $checks++
    }
    $saved = Get-Content -LiteralPath (Join-Path $work 'run-26.json') -Raw
    foreach ($mutation in @('hash','settings','schema','environmentHash','duplicateId','overlap','duration','role','pack')) {
        $run = $saved | ConvertFrom-Json
        switch ($mutation) {
            hash { $run.captureTool.rawFrameTimeSha256 = 'E' * 64 }
            settings { $run.settings.renderDistance = 8 }
            schema { $run.schemaVersion = 0 }
            environmentHash { $run.runtime.modsSha256 = 'invalid' }
            duplicateId { $run.runId = 'synthetic-0' }
            overlap { $run.timing.startedAtUtc = '2026-01-01T00:00:00Z' }
            duration { $run.timing.measurementSeconds = 600 }
            role { $run.role = 'CONTROL' }
            pack { $run.packSha256 = 'E' * 64 }
        }
        Write-Json $run (Join-Path $work 'run-26.json')
        Reject $mutation $analyze
    }
    Set-Content -LiteralPath (Join-Path $work 'run-26.json') -Value $saved -Encoding utf8NoBOM
    foreach ($scenario in @('within-observed-noise','regression-requires-review')) {
        foreach ($pair in $abPairs) {
            $runDocuments = @($pair.runs | ForEach-Object { Get-Content -LiteralPath (Join-Path $work $_) -Raw | ConvertFrom-Json })
            $treatment = $runDocuments | Where-Object role -eq 'TREATMENT'
            $control = $runDocuments | Where-Object role -eq 'CONTROL'
            $treatmentPath = $pair.runs | Where-Object { ((Get-Content -LiteralPath (Join-Path $work $_) -Raw | ConvertFrom-Json).role -eq 'TREATMENT') }
            $path = Join-Path $work $treatmentPath
            $run = $treatment
            $controlIndex = [int]($control.runId -replace 'synthetic-','')
            $value = 6000.0 + $controlIndex * 0.1 + $(if ($scenario -eq 'within-observed-noise') { 0.001 } else { 30.0 })
            $raw = Join-Path $work $run.captureTool.rawFrameTimeCsv
            $values = @(for ($frame = 0; $frame -lt 10; $frame++) { ($value + $frame * 0.01).ToString('R',[Globalization.CultureInfo]::InvariantCulture) })
            Set-Content -LiteralPath $raw -Value (@('frameTimeMs') + $values) -Encoding utf8NoBOM
            $run.captureTool.rawFrameTimeSha256 = (Get-FileHash -LiteralPath $raw).Hash
            Write-Json $run $path
        }
        & $analyze
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        foreach ($metric in @('meanFrameTimeMs','medianFrameTimeMs','p95FrameTimeMs','p99FrameTimeMs')) {
            if ($result.metrics.$metric.observation -ne $scenario) { throw "Wrong $scenario classification for $metric" }
            $checks++
        }
    }
    $series.pairs = @($pairs | Select-Object -Skip 1)
    Write-Json $series $seriesPath
    Reject 'insufficient AA replication' $analyze
    $series.pairs = @($pairs[6],$pairs[0],$pairs[1],$pairs[2],$pairs[3],$pairs[4],$pairs[5]) + @($pairs | Select-Object -Skip 7)
    Write-Json $series $seriesPath
    Reject 'AA after AB' $analyze
    Write-Host "Benchmark regression tests passed: $checks checks; synthetic data only."
} finally {
    $resolved = [IO.Path]::GetFullPath($work)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-benchmark-tests-*') { throw 'Unsafe fixture cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
