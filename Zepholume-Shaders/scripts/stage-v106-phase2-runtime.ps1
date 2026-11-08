[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$gitRoot = Split-Path -Parent $sourceRoot
$workspaceRoot = Split-Path -Parent $gitRoot
$runtimeRoot = Join-Path $sourceRoot 'runtime/v106-phase2'
$historicalRuntime = Join-Path $workspaceRoot 'runtime'
$java = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot\bin\java.exe'
$phase1 = Join-Path $sourceRoot 'dist/Zepholume-Shaders-1.0.6-dev-phase1.zip'
$baseline = Join-Path $gitRoot 'Releases/Zepholume-Shaders-1.0.5.zip'
$phase1Hash = '3B422B68CCAFF5B2C06420DA3A571909AF4860F828141A86D56777EB6A462F85'
$baselineHash = '4B3803CF87AF43952CF91D145BB634C3346DEF6FC8C7008C37368058DC75DC91'

function Assert-Hash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -cne $Expected) { throw "SHA-256 mismatch: $Path" }
}

Assert-Hash $phase1 $phase1Hash
Assert-Hash $baseline $baselineHash
if (-not (Test-Path -LiteralPath $java -PathType Leaf)) { throw "Missing Java 17: $java" }
$javaVersion = & $java -version 2>&1 | Select-Object -First 1
if ($javaVersion -notmatch '"17\.') { throw "Expected Java 17; found $javaVersion" }
$revision = (& git -C $gitRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read Git revision.' }
$worktreeDirty = @(& git -C $gitRoot status --porcelain).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Could not read Git status.' }

$lanes = @(
    [ordered]@{ name='iris-1.20.1'; loader='Fabric Loader 0.19.3'; renderer='Iris 1.7.6 / Sodium 0.5.13'; sourceLane='v105-phase10-iris-treatment'; mods=@(
        [ordered]@{ file='iris-1.7.6+mc1.20.1.jar'; sha256='9EB15E563E0C9AE6EFF15B7863F8432DD290CF9F724C7373E9B15B14AA829ED5' },
        [ordered]@{ file='sodium-fabric-0.5.13+mc1.20.1.jar'; sha256='688C26029CE69F0B1F7CF936866656CA6723228AC46C4AEF5B5F793B1E6ABD22' }
    ) },
    [ordered]@{ name='oculus-1.20.1'; loader='Forge 47.4.22'; renderer='Oculus 1.8.0 / Embeddium 0.3.31'; sourceLane='v105-phase10-oculus-treatment'; mods=@(
        [ordered]@{ file='oculus-mc1.20.1-1.8.0.jar'; sha256='0945DF0CBA0F62B3901DD80C3268E5311B770ECE78C78037A45DB12AC0425FEF' },
        [ordered]@{ file='embeddium-0.3.31+mc1.20.1.jar'; sha256='EED3D1325F2ACC2FD4E69BB495E5CCB91D962126AC5330F0582EBC2A3DAF47FB' }
    ) }
)

# Validate every input and every destination before creating either lane.
foreach ($lane in $lanes) {
    $destination = Join-Path $runtimeRoot $lane.name
    $resolved = [IO.Path]::GetFullPath($destination)
    $parent = [IO.Path]::GetFullPath($runtimeRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe destination: $destination" }
    if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite lane: $destination" }
    foreach ($mod in $lane.mods) {
        Assert-Hash (Join-Path (Join-Path $historicalRuntime $lane.sourceLane) ('mods/' + $mod.file)) $mod.sha256
    }
}

foreach ($lane in $lanes) {
    $destination = Join-Path $runtimeRoot $lane.name
    New-Item -ItemType Directory -Path $destination | Out-Null
    foreach ($subdir in @('mods','shaderpacks','logs','patched_shaders','screenshots','crash-reports','config')) {
        New-Item -ItemType Directory -Path (Join-Path $destination $subdir) | Out-Null
    }
    foreach ($mod in $lane.mods) {
        $source = Join-Path (Join-Path $historicalRuntime $lane.sourceLane) ('mods/' + $mod.file)
        $target = Join-Path $destination ('mods/' + $mod.file)
        Copy-Item -LiteralPath $source -Destination $target
        Assert-Hash $target $mod.sha256
    }
    foreach ($package in @(@{ path=$phase1; sha256=$phase1Hash }, @{ path=$baseline; sha256=$baselineHash })) {
        $target = Join-Path $destination ('shaderpacks/' + [IO.Path]::GetFileName($package.path))
        Copy-Item -LiteralPath $package.path -Destination $target
        Assert-Hash $target $package.sha256
    }
    [ordered]@{
        schemaVersion=1; createdAtUtc=[DateTime]::UtcNow.ToString('o'); state='STAGED_NO_LAUNCH'
        sourceRevision=$revision; sourceWorktreeDirty=$worktreeDirty; minecraft='1.20.1'
        javaExecutable=$java; javaVersion=[string]$javaVersion
        loader=$lane.loader; renderer=$lane.renderer
        phase1Package=[ordered]@{ file=[IO.Path]::GetFileName($phase1); sha256=$phase1Hash }
        baselinePackage=[ordered]@{ file=[IO.Path]::GetFileName($baseline); sha256=$baselineHash }
        mods=$lane.mods
        observations=[ordered]@{ launch=$false; shaderMenu=$false; patchedCompilation=$false; worldRendering=$false; profileUI=$false; benchmark=$false }
        excluded=@('saves','account files','launcher profiles','resource packs','server lists')
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destination 'phase2-staging-manifest.json') -Encoding utf8NoBOM
    Write-Host "Staged $($lane.name): $destination"
}
