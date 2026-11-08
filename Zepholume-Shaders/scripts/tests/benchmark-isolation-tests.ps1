[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-benchmark-isolation-' + [guid]::NewGuid().ToString('N'))
$pwsh = (Get-Process -Id $PID).Path
$watched = @('bench/run-manifest-template.json','bench/v103-control.json','docs/BENCHMARK_PROTOCOL.md')
$sources = $watched + @('scripts/benchmark-summarize.ps1','scripts/benchmark-series.ps1','scripts/benchmark-compare.ps1','scripts/tests/benchmark-tests.ps1')
function Get-FixtureHashes([string]$Root) {
    $hashes = [ordered]@{}
    foreach ($path in $watched) { $hashes[$path] = (Get-FileHash -LiteralPath (Join-Path $Root $path)).Hash }
    return $hashes
}
function Assert-FixturesUnchanged($Before, [string]$Root) {
    $after = Get-FixtureHashes $Root
    foreach ($path in $watched) { if ($Before[$path] -cne $after[$path]) { throw "Benchmark test changed fixture bytes: $path" } }
}
$original = Get-FixtureHashes $project
try {
    New-Item -ItemType Directory -Path $work | Out-Null
    foreach ($ending in @('LF','CRLF')) {
        $fixture = Join-Path $work $ending
        foreach ($path in $sources) {
            $target = Join-Path $fixture $path
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            $text = [IO.File]::ReadAllText((Join-Path $project $path)).Replace("`r`n", "`n")
            if ($ending -eq 'CRLF') { $text = $text.Replace("`n", "`r`n") }
            [IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
        }
        $before = Get-FixtureHashes $fixture
        $log = Join-Path $fixture 'test-output.txt'
        & $pwsh -NoLogo -NoProfile -File (Join-Path $fixture 'scripts/tests/benchmark-tests.ps1') *> $log
        if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $log -Tail 20 | Out-Host; throw "Benchmark fixtures failed with $ending input" }
        Assert-FixturesUnchanged $before $fixture
        # Prove the byte guard rejects a mutation that Git's line-ending
        # normalization can hide, without touching repository inputs.
        $sentinel = Join-Path $fixture $watched[0]
        [IO.File]::AppendAllText($sentinel, "`n")
        $rejected = $false
        try { Assert-FixturesUnchanged $before $fixture } catch { $rejected = $true }
        if (-not $rejected) { throw 'Fixture hash guard accepted a changed template' }
        Write-Host "Benchmark isolation $ending PASS: 43 synthetic checks, three exact-byte fixture guards, mutation control rejected."
    }
    Assert-FixturesUnchanged $original $project
    Write-Host 'Benchmark isolation tests passed: LF and CRLF fixture trees; repository inputs preserved.'
} finally {
    $resolved = [IO.Path]::GetFullPath($work)
    $relative = [IO.Path]::GetRelativePath([IO.Path]::GetTempPath(), $resolved)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.([\\/]|$)' -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-benchmark-isolation-*') { throw 'Unsafe fixture cleanup target.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
