[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$validator = Join-Path (Split-Path -Parent $PSScriptRoot) 'validate-glsl.ps1'
$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not $IsWindows) { $pwsh = (Get-Command pwsh -ErrorAction Stop).Source }
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-glsl-warning-tests-' + [guid]::NewGuid().ToString('N'))
try {
    $scripts = Join-Path $work 'scripts'
    $source = Join-Path $work 'shaders'
    $variants = Join-Path $work 'variants'
    New-Item -ItemType Directory -Path $scripts,$source,(Join-Path $variants 'unique') | Out-Null
    Copy-Item -LiteralPath $validator -Destination (Join-Path $scripts 'validate-glsl.ps1')
    # A fake backend isolates the caller's exit/report policy from any installed
    # compiler. It emits only a link warning, while every stage exits cleanly.
    @'
function Resolve-ZephValidatorBackend { param($ValidatorMode,$Validator,$WslDistribution) return @{ Version='fixture backend' } }
function Invoke-ZephValidatorBackend {
    param($Backend,$Arguments)
    $global:LASTEXITCODE = 0
    if ($Arguments[0] -eq '-l') { return 'WARNING: synthetic linker fixture' }
    return ''
}
'@ | Set-Content -LiteralPath (Join-Path $scripts 'validator-backend.ps1') -Encoding utf8NoBOM
    $sourceManifest = @()
    $index = @()
    foreach ($stage in @('vsh','fsh')) {
        $file = Join-Path $source "fixture.$stage"
        [IO.File]::WriteAllText($file, "fixture $stage")
        $hash = (Get-FileHash -LiteralPath $file).Hash
        Copy-Item -LiteralPath $file -Destination (Join-Path $variants "unique/$hash.$stage")
        $sourceManifest += @{ path="fixture.$stage"; sha256=$hash }
        $index += @{ Profile='Balanced'; Dimension='Overworld'; LoaderModel='Iris'; Program='fixture'; Stage=$stage; ContentHash=$hash; Artifact="unique/$hash.$stage"; OriginalSource="fixture.$stage" }
    }
    @{files=$sourceManifest} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $variants 'source-manifest.json') -Encoding utf8NoBOM
    $index | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $variants 'index.json') -Encoding utf8NoBOM
    $arguments = @('-NoLogo','-NoProfile','-File',(Join-Path $scripts 'validate-glsl.ps1'),'-VariantRoot',$variants,'-SourceRoot',$source)
    & $pwsh @arguments -ReportRoot (Join-Path $work 'advisory') *> (Join-Path $work 'advisory.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Link warning should remain advisory without -WarningsAsErrors' }
    & $pwsh @arguments -ReportRoot (Join-Path $work 'strict') -WarningsAsErrors *> (Join-Path $work 'strict.txt')
    if ($LASTEXITCODE -eq 0) { throw 'Link warning was accepted with -WarningsAsErrors' }
    $stageRows = Get-Content -LiteralPath (Join-Path $work 'strict/glslang-report.json') -Raw | ConvertFrom-Json
    $linkRows = Get-Content -LiteralPath (Join-Path $work 'strict/glslang-link-report.json') -Raw | ConvertFrom-Json
    if (@($stageRows | Where-Object WarningCount -gt 0).Count -ne 0 -or @($linkRows | Where-Object WarningCount -gt 0).Count -ne 1) { throw 'Fixture did not isolate a linker warning' }
    if ((Get-Content -LiteralPath (Join-Path $work 'strict.txt') -Raw) -notmatch 'compilation/linking emitted warning') { throw 'Strict run failed for an unexpected reason' }
    Write-Host 'GLSL warning policy fixtures PASS: clean stages plus linker warning rejected only with -WarningsAsErrors. No real compiler or Minecraft execution is simulated.'
} finally {
    $resolvedWork = [IO.Path]::GetFullPath($work)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedWork.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedWork) -notlike 'zepholume-glsl-warning-tests-*') { throw 'Unsafe fixture cleanup path' }
    if (Test-Path -LiteralPath $resolvedWork) { Remove-Item -LiteralPath $resolvedWork -Recurse -Force }
}
