$ErrorActionPreference = 'Stop'
$scripts = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-candidate-test-' + [guid]::NewGuid().ToString('N'))
try {
    $mods = Join-Path $work 'mods'; New-Item -ItemType Directory -Path $mods | Out-Null
    foreach ($name in @('iris-1.7.6+mc1.20.1.jar','sodium-fabric-0.5.13+mc1.20.1.jar')) { [IO.File]::WriteAllText((Join-Path $mods $name), 'synthetic fixture') }
    $zip = Join-Path $work 'candidate.zip'; [IO.File]::WriteAllText($zip, 'synthetic fixture')
    $hash = (Get-FileHash -LiteralPath $zip).Hash; $commit = 'a' * 40
    $game = Join-Path $work 'game'
    & (Join-Path $scripts 'stage-v107-candidate.ps1') -CandidateZip $zip -ExpectedSha256 $hash -SourceCommit $commit -ModSourceDirectory $mods -GameDirectory $game | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $game 'logs') | Out-Null
    [IO.File]::WriteAllText((Join-Path $game 'logs/latest.log'), 'synthetic test log')
    $metadata = @{}; foreach ($field in @('minecraftVersion','loader','iris','sodium','java','gpu','driver','shaderProfile','shaderOptions','resolution','renderScale','renderDistance','simulationDistance','vsync','fpsCap','world','viewpoint','timeAndWeather')) { $metadata[$field] = 'fixture' }
    $metadataPath = Join-Path $work 'metadata.json'; $metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath
    $args = @{ RuntimeDirectory = $game; EvidenceDirectory = (Join-Path $work 'evidence'); SessionStartedUtc = [datetime]::UtcNow.AddMinutes(-1); CandidateName = 'candidate.zip'; ExpectedSha256 = $hash; SourceCommit = $commit; RunMetadataPath = $metadataPath }
    $first = (& (Join-Path $scripts 'collect-v107-runtime.ps1') @args | Out-String) | ConvertFrom-Json
    $second = (& (Join-Path $scripts 'collect-v107-runtime.ps1') @args | Out-String) | ConvertFrom-Json
    if ($first.runId -eq $second.runId -or $first.activation -ne 'UNVERIFIED' -or -not $first.candidate.matches -or $first.sourceCommit -ne $commit) { throw 'Incorrect identity or classification.' }
    if (-not (Test-Path -LiteralPath (Join-Path $args.EvidenceDirectory "$($first.runId)/session-manifest.json"))) { throw 'Run-ID evidence directory missing.' }
    [IO.File]::WriteAllText((Join-Path $game 'shaderpacks/candidate.zip'), 'tampered')
    $failed = $false
    try { & (Join-Path $scripts 'collect-v107-runtime.ps1') @args | Out-Null } catch { if ($_.Exception.Message -notlike '*SHA-256*') { throw }; $failed = $true }
    if (-not $failed -or @(Get-ChildItem -LiteralPath $args.EvidenceDirectory -Directory).Count -ne 2) { throw 'Hash mismatch did not reject collection.' }
    Write-Host 'PASS: synthetic candidate staging, hash rejection, unique run IDs, metadata, and unverified activation. No Minecraft execution was tested.'
} finally {
    $resolved = [IO.Path]::GetFullPath($work); $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-candidate-test-*') { throw 'Unsafe fixture cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
