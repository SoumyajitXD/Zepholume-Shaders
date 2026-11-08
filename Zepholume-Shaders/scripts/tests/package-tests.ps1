[CmdletBinding()]
param([string]$Packager = (Join-Path (Split-Path -Parent $PSScriptRoot) 'package.ps1'))
$ErrorActionPreference = 'Stop'
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-package-tests-' + [guid]::NewGuid().ToString('N'))
$originalLocation = Get-Location
$originalDirectory = [Environment]::CurrentDirectory
$failures = [System.Collections.Generic.List[string]]::new()
$checks = 0
function Assert-Package([string]$Name, [bool]$Condition) {
    $script:checks++
    if (-not $Condition) { $failures.Add($Name) }
}
try {
    $fixture = Join-Path $work 'fixture'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts'),(Join-Path $fixture 'shaders') | Out-Null
    Copy-Item -LiteralPath $Packager -Destination (Join-Path $fixture 'scripts/package.ps1')
    # This isolated validator deliberately accepts tiny payloads and injects
    # promotion conflicts. Real source/ZIP validation remains validate-tests' job.
    @'
param([string]$Package)
if ($Package -and $env:ZEPH_PACKAGE_FIXTURE_CONFLICT) {
    $destination = Join-Path (Split-Path -Parent $Package) ('fixture.zip' + $env:ZEPH_PACKAGE_FIXTURE_CONFLICT)
    [IO.File]::WriteAllText($destination, 'preserve-concurrent-output')
}
'@ | Set-Content -LiteralPath (Join-Path $fixture 'scripts/validate.ps1') -Encoding utf8NoBOM
    foreach ($name in @('README.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md','shaders/z.glsl','shaders/A.glsl')) {
        [IO.File]::WriteAllText((Join-Path $fixture $name), $name)
    }
    $builder = Join-Path $fixture 'scripts/package.ps1'
    $output = Join-Path $work 'ordered'
    & $builder -OutputDirectory $output -OutputName 'fixture.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $output 'fixture.zip'))
    try { $actual = @($archive.Entries | ForEach-Object FullName) } finally { $archive.Dispose() }
    [string[]]$expected = $actual.Clone()
    [Array]::Sort($expected, [StringComparer]::Ordinal)
    Assert-Package 'ZIP entries must use advertised ordinal path ordering' (($actual -join '|') -ceq ($expected -join '|'))
    $sum = (Get-FileHash -LiteralPath (Join-Path $output 'fixture.zip')).Hash
    $second = Join-Path $work 'second'
    & $builder -OutputDirectory $second -OutputName 'fixture.zip'
    Assert-Package 'identical payloads must produce identical ZIPs' ($sum -ceq (Get-FileHash -LiteralPath (Join-Path $second 'fixture.zip')).Hash)
    $rejected = $false
    try { & $builder -OutputDirectory $output -OutputName 'fixture.zip' } catch { $rejected = $true }
    Assert-Package 'existing package must be rejected and preserved' ($rejected -and $sum -ceq (Get-FileHash -LiteralPath (Join-Path $output 'fixture.zip')).Hash)

    [Environment]::CurrentDirectory = $work
    Set-Location -LiteralPath $fixture
    & $builder -OutputDirectory 'relative-output' -OutputName 'fixture.zip'
    Assert-Package 'relative output must follow PowerShell location' (Test-Path -LiteralPath (Join-Path $fixture 'relative-output/fixture.zip'))
    Set-Location -LiteralPath $originalLocation.Path
    [Environment]::CurrentDirectory = $originalDirectory

    foreach ($conflict in @('.sha256','.manifest.json')) {
        $target = Join-Path $work ('conflict-' + $conflict.Substring(1))
        $env:ZEPH_PACKAGE_FIXTURE_CONFLICT = $conflict
        $rejected = $false
        try { & $builder -OutputDirectory $target -OutputName 'fixture.zip' } catch { $rejected = $true }
        finally { Remove-Item Env:ZEPH_PACKAGE_FIXTURE_CONFLICT }
        $sentinel = Join-Path $target ('fixture.zip' + $conflict)
        Assert-Package "promotion conflict $conflict must fail" $rejected
        Assert-Package "promotion conflict $conflict must preserve competing output" ((Test-Path -LiteralPath $sentinel) -and [IO.File]::ReadAllText($sentinel) -ceq 'preserve-concurrent-output')
        $remaining = @(Get-ChildItem -LiteralPath $target -File)
        Assert-Package "promotion conflict $conflict must leave no owned partial output" ($remaining.Count -eq 1 -and $remaining[0].FullName -eq $sentinel)
    }
    if ($failures.Count) { throw "Package regression failures ($($failures.Count)/$checks): $($failures -join '; ')" }
    Write-Host "Package regression tests passed: $checks checks; isolated payload/validator fixtures."
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    [Environment]::CurrentDirectory = $originalDirectory
    Remove-Item Env:ZEPH_PACKAGE_FIXTURE_CONFLICT -ErrorAction SilentlyContinue
    $resolved = [IO.Path]::GetFullPath($work)
    $relative = [IO.Path]::GetRelativePath([IO.Path]::GetTempPath(), $resolved)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.([\\/]|$)' -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-package-tests-*') { throw 'Unsafe fixture cleanup target.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
