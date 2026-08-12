[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Iris','Oculus')]
    [string]$Target,
    [Parameter(Mandatory)]
    [ValidateSet('Verify','Collect','Reset')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $projectRoot 'runtime'
$manifestPath = Join-Path $runtimeRoot 'manifests/runtime-environments.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing runtime manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$key = $Target.ToLowerInvariant()
$environment = $manifest.environments.$key
if ($null -eq $environment) { throw "No manifest environment for target: $Target" }
$gameDir = [IO.Path]::GetFullPath($environment.gameDirectory)
$expectedDir = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $environment.directoryName))
if ($gameDir -ne $expectedDir -or -not $gameDir.StartsWith(([IO.Path]::GetFullPath($runtimeRoot) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe runtime directory from manifest: $gameDir"
}

function Get-Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Hash([string]$Path, [string]$Expected, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing ${Label}: $Path" }
    $actual = Get-Hash $Path
    if ($actual -ne $Expected) { throw "Hash mismatch for ${Label}: expected $Expected, got $actual" }
}
function Test-PackageRoot([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entries = @($zip.Entries | ForEach-Object FullName)
        if ($entries | Where-Object { $_ -match '\\' }) { throw "Shader ZIP contains backslash paths: $Path" }
        if ($entries -notcontains 'shaders/shaders.properties') { throw "Shader ZIP does not contain shaders/ at ZIP root: $Path" }
    } finally { $zip.Dispose() }
}
function Copy-EvidenceFile([string]$Source, [string]$DestinationRoot, [System.Collections.Generic.List[object]]$Items) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    $relative = [IO.Path]::GetRelativePath($gameDir, $Source)
    $destination = Join-Path $DestinationRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    $file = Get-Item -LiteralPath $destination
    $Items.Add([ordered]@{ path = $relative; size = $file.Length; lastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o'); sha256 = Get-Hash $destination })
}
function Copy-EvidenceTree([string]$Source, [string]$DestinationRoot, [System.Collections.Generic.List[object]]$Items) {
    if (-not (Test-Path -LiteralPath $Source)) { return }
    Get-ChildItem -LiteralPath $Source -Recurse -File -Force | ForEach-Object { Copy-EvidenceFile $_.FullName $DestinationRoot $Items }
}

switch ($Action) {
    'Verify' {
        if (-not (Test-Path -LiteralPath $gameDir -PathType Container)) { throw "Missing game directory: $gameDir" }
        foreach ($mod in $environment.mods) { Assert-Hash (Join-Path $gameDir ('mods/' + $mod.filename)) $mod.sha256 ("mod JAR " + $mod.filename) }
        $package = Join-Path $gameDir ('shaderpacks/' + $environment.zepholumePackage.filename)
        Assert-Hash $package $environment.zepholumePackage.sha256 'Zepholume shader package'
        Test-PackageRoot $package
        if (-not (Test-Path -LiteralPath $environment.java.executable -PathType Leaf)) { throw "Java executable is unavailable: $($environment.java.executable)" }
        $javaVersion = (& $environment.java.executable -version 2>&1 | Out-String)
        if ($javaVersion -notmatch 'version "17(?:\.|"|_)') { throw "Java 17 is required; detected: $($javaVersion.Trim())" }
        foreach ($sensitive in @('usercache.json','usernamecache.json','TLauncherAdditional.json','launcher_accounts.json','launcher_profiles.json')) {
            if (Test-Path -LiteralPath (Join-Path $gameDir $sensitive)) { throw "Unexpected normal-instance or account file in isolated directory: $sensitive" }
        }
        if (-not $environment.isolation.noNormalWorldsCopied) { throw 'Manifest does not attest that normal worlds were excluded.' }
        Write-Host "$Target runtime verification passed."
        Write-Host "Launcher version ID: $($environment.launcherVersionId)"
        Write-Host "Game directory: $gameDir"
        Write-Host "Java: $($environment.java.executable)"
    }
    'Collect' {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $evidenceRoot = Join-Path $runtimeRoot ('evidence/' + $key + '/' + $stamp)
        New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($relative in @('logs/latest.log','logs/debug.log','options.txt','optionsshaders.txt','config/iris.properties','config/oculus.properties')) { Copy-EvidenceFile (Join-Path $gameDir $relative) $evidenceRoot $items }
        foreach ($relative in @('crash-reports','patched_shaders','screenshots')) { Copy-EvidenceTree (Join-Path $gameDir $relative) $evidenceRoot $items }
        Get-ChildItem -LiteralPath $gameDir -File -Filter 'hs_err_pid*.log' -ErrorAction SilentlyContinue | ForEach-Object { Copy-EvidenceFile $_.FullName $evidenceRoot $items }
        $collection = [ordered]@{ target=$Target; collectedAt=(Get-Date).ToUniversalTime().ToString('o'); gameDirectory=$gameDir; sourceManifest='runtime/manifests/runtime-environments.json'; files=@($items) }
        $collection | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'collection-manifest.json') -Encoding utf8NoBOM
        Write-Host "Evidence collected: $evidenceRoot"
    }
    'Reset' {
        foreach ($relative in @('logs','crash-reports','patched_shaders','screenshots')) {
            $path = Join-Path $gameDir $relative
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }
        Get-ChildItem -LiteralPath $gameDir -File -Filter 'hs_err_pid*.log' -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
        Write-Host "Reset generated test artifacts only. Preserved mods, shaderpacks, config, options, and saves: $gameDir"
    }
}
