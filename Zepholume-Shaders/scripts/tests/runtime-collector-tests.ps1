[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$collector = Join-Path (Split-Path -Parent $PSScriptRoot) 'collect-v106-runtime.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-collector-tests-' + [guid]::NewGuid().ToString('N'))
$fixtureScripts = Join-Path $work 'scripts'
$lane = Join-Path $work 'runtime/v106-phase2/iris-1.20.1'
$fixtureCollector = Join-Path $fixtureScripts 'collect-v106-runtime.ps1'
$sessionStart = [DateTime]::UtcNow.AddMinutes(-1)

try {
    New-Item -ItemType Directory -Path $fixtureScripts,(Join-Path $lane 'logs'),(Join-Path $lane 'crash-reports'),(Join-Path $lane 'patched_shaders'),(Join-Path $lane 'screenshots') | Out-Null
    Copy-Item -LiteralPath $collector -Destination $fixtureCollector
    # Synthetic diagnostic fixtures contain no real account or session material.
    $diagnostic = @('Shader compilation fixture failure', 'accessToken=TEST_SENTINEL', 'At C:\Users\fixture-person\instance https://example.invalid/server 192.0.2.1 fixture@example.invalid')
    $latestLog = Join-Path $lane 'logs/latest.log'
    $crash = Join-Path $lane 'crash-reports/crash-fixture.txt'
    [IO.File]::WriteAllLines($latestLog, $diagnostic)
    [IO.File]::WriteAllLines($crash, $diagnostic)
    $originalHashes = @((Get-FileHash -LiteralPath $latestLog).Hash, (Get-FileHash -LiteralPath $crash).Hash)
    $patch = Join-Path $lane 'patched_shaders/fixture.fsh'
    [IO.File]::WriteAllText($patch, 'void main() {}')
    $stale = Join-Path $lane 'patched_shaders/stale.fsh'
    [IO.File]::WriteAllText($stale, 'stale fixture')
    (Get-Item -LiteralPath $stale).LastWriteTimeUtc = $sessionStart.AddMinutes(-1)
    $unexpected = Join-Path $lane 'patched_shaders/unexpected.bin'
    [IO.File]::WriteAllText($unexpected, 'unexpected fixture')
    $screenshot = Join-Path $lane 'screenshots/fixture.png'
    [IO.File]::WriteAllBytes($screenshot, [byte[]]@(137,80,78,71,13,10,26,10))

    # Validate the bad basename before creating evidence. A second invocation
    # in the same UTC second otherwise hits the no-overwrite guard first.
    $rejectedName = $false
    try { & $fixtureCollector -SessionStartedUtc $sessionStart -ScreenshotNames '../escape.png' -DryRun | Out-Null }
    catch { if ($_.Exception.Message -notlike '*PNG basenames only*') { throw }; $rejectedName = $true }
    if (-not $rejectedName) { throw 'Collector accepted screenshot traversal' }

    $result = (& $fixtureCollector -SessionStartedUtc $sessionStart -ScreenshotNames 'fixture.png' | Out-String) | ConvertFrom-Json
    $evidenceDirectories = @(Get-ChildItem -LiteralPath (Join-Path $work 'artifacts/v106-runtime-evidence') -Directory)
    if ($evidenceDirectories.Count -ne 1) { throw 'Expected exactly one evidence directory' }
    $output = $evidenceDirectories[0].FullName
    foreach ($relative in @('logs/latest.log','crash-reports/crash-fixture.txt')) {
        $record = @($result.files | Where-Object path -eq $relative)
        if ($record.Count -ne 1 -or -not $record[0].redacted) { throw "Diagnostic file was not classified for redaction: $relative" }
        $copied = Get-Content -LiteralPath (Join-Path $output $relative) -Raw
        if ($copied -match 'TEST_SENTINEL|fixture-person|example.invalid|192\.0\.2\.1') { throw "Diagnostic fixture escaped redaction: $relative" }
        if ($copied -notmatch 'Shader compilation fixture failure') { throw 'Useful shader diagnostic was removed' }
        if ($record[0].copiedSha256 -cne (Get-FileHash -LiteralPath (Join-Path $output $relative)).Hash) { throw 'Copied diagnostic hash mismatch' }
    }
    if ((Get-FileHash -LiteralPath $latestLog).Hash -cne $originalHashes[0] -or (Get-FileHash -LiteralPath $crash).Hash -cne $originalHashes[1]) { throw 'Collector modified source diagnostics' }
    foreach ($relative in @('patched_shaders/fixture.fsh','screenshots/fixture.png')) {
        if ((Get-FileHash -LiteralPath (Join-Path $lane $relative)).Hash -cne (Get-FileHash -LiteralPath (Join-Path $output $relative)).Hash) { throw "Binary/source evidence changed: $relative" }
    }
    if ($result.rejected -notcontains 'patched_shaders/stale.fsh (older than session start)' -or $result.rejected -notcontains 'patched_shaders/unexpected.bin (unexpected extension)') { throw 'Collector did not reject stale/unexpected evidence' }
    if (Test-Path -LiteralPath (Join-Path $output 'patched_shaders/stale.fsh')) { throw 'Stale evidence was copied' }
    Write-Host 'Runtime collector fixture tests PASS: diagnostic redaction, source preservation, hashes, freshness, extension and basename checks. These fixtures are not Minecraft runtime evidence.'
} finally {
    $resolvedWork = [IO.Path]::GetFullPath($work)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedWork.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedWork) -notlike 'zepholume-collector-tests-*') { throw 'Unsafe fixture cleanup path' }
    if (Test-Path -LiteralPath $resolvedWork) { Remove-Item -LiteralPath $resolvedWork -Recurse -Force }
}
