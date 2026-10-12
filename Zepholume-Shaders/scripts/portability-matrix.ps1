[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$Detailed,
    [string[]]$SelectedProfiles,
    [string]$OutputRoot,
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 900,
    [switch]$Worker,
    [ValidateRange(1, 756)]
    [int]$ProgressEvery = 36
)
function Invoke-PortabilityMatrixWorker {
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$shaderRoot = Join-Path $Root 'shaders'
. (Join-Path $PSScriptRoot 'profile-config.ps1')
$output = if ($OutputRoot) { $OutputRoot } else { Join-Path $Root 'artifacts/portability-matrix' }
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Path $output | Out-Null
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

function Expand-ZephInclude([string]$Path, [System.Collections.Generic.List[string]]$Stack, [ref]$Count) {
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    if ($Stack.Contains($fullPath)) { throw "Include cycle: $($Stack -join ' -> ') -> $fullPath" }
    $Stack.Add($fullPath)
    $source = Get-Content -LiteralPath $fullPath -Raw
    $source = [regex]::Replace($source, '#include\s+"([^"]+)"', {
        param($match)
        $candidate = Join-Path $shaderRoot $match.Groups[1].Value.TrimStart('/')
        if (-not (Test-Path -LiteralPath $candidate)) { throw "Unresolved include: $candidate" }
        $Count.Value++
        Expand-ZephInclude $candidate $Stack ([ref]$Count.Value)
    })
    $Stack.RemoveAt($Stack.Count - 1)
    return $source
}

$vendors = @(
    @{ name='nvidia-geforce'; macros=@('MC_GL_VENDOR_NVIDIA','MC_GL_RENDERER_GEFORCE') },
    @{ name='nvidia-quadro'; macros=@('MC_GL_VENDOR_NVIDIA','MC_GL_RENDERER_QUADRO') },
    @{ name='amd-radeon'; macros=@('MC_GL_VENDOR_AMD','MC_GL_RENDERER_RADEON') },
    @{ name='intel'; macros=@('MC_GL_VENDOR_INTEL','MC_GL_RENDERER_INTEL') },
    @{ name='mesa-radeon'; macros=@('MC_GL_VENDOR_MESA','MC_GL_RENDERER_GALLIUM','MC_GL_RENDERER_RADEON') },
    @{ name='mesa-intel'; macros=@('MC_GL_VENDOR_MESA','MC_GL_RENDERER_MESA','MC_GL_RENDERER_INTEL') },
    @{ name='unknown'; macros=@('MC_GL_VENDOR_OTHER','MC_GL_RENDERER_OTHER') }
)
$loaders = @(
    @{ name='iris'; macros=@('IRIS_FEATURES 1') },
    @{ name='oculus-conservative'; macros=@() },
    @{ name='unknown-loader'; macros=@() }
)
$profiles = @(Get-ZephProfiles -ShaderRoot $shaderRoot | ForEach-Object { @{ name=$_.Name.ToLowerInvariant().Replace('_','-'); values=$_.Values } })
if ($SelectedProfiles) {
    $profiles = @($profiles | Where-Object { $_.name -in $SelectedProfiles })
    if ($profiles.Count -ne $SelectedProfiles.Count) { throw "Unknown profile selection: $($SelectedProfiles -join ', ')" }
}
$dimensions = [ordered]@{ overworld='world0'; nether='world-1'; end='world1' }
$capabilities = @(
    @{ name='gl33-no-optional-extensions'; macros=@('MC_GL_VERSION 330','MC_GLSL_VERSION 330') },
    @{ name='higher-gl-retaining-glsl330'; macros=@('MC_GL_VERSION 460','MC_GLSL_VERSION 330') }
)
$stagesByDimension = @{}
foreach ($dimension in $dimensions.GetEnumerator()) {
    $stagesByDimension[$dimension.Key] = @(Get-ChildItem -LiteralPath (Join-Path $shaderRoot $dimension.Value) -File | Where-Object { $_.Extension -in '.vsh','.fsh' } | Sort-Object Name)
}
$stages = @($stagesByDimension.Values | ForEach-Object { $_ })
$expandedStages = @{}
foreach ($stage in $stages) {
    $includeCount = 0
    $expanded = Expand-ZephInclude $stage.FullName ([System.Collections.Generic.List[string]]::new()) ([ref]$includeCount)
    if ($expanded -match '#include\s+"') { throw "Unexpanded include in $($stage.FullName)" }
    $expandedStages[$stage.FullName] = [ordered]@{ source=$expanded; includeCount=$includeCount }
}
$manifest = [System.Collections.Generic.List[object]]::new()
$totalCases = $vendors.Count * $loaders.Count * $profiles.Count * $dimensions.Count * $capabilities.Count
$completedCases = 0
foreach ($vendor in $vendors) { foreach ($loader in $loaders) { foreach ($profile in $profiles) { foreach ($dimension in $dimensions.Keys) { foreach ($capability in $capabilities) {
    $caseName = "$($vendor.name)--$($loader.name)--$($profile.name)--$dimension--$($capability.name)"
    $caseRows = [System.Collections.Generic.List[object]]::new()
    $caseMacros = @($vendor.macros + $loader.macros + $capability.macros)
    $macroPrefix = ($caseMacros | ForEach-Object { "#define $_" }) -join "`n"
    foreach ($stage in $stagesByDimension[$dimension]) {
        $expanded = $expandedStages[$stage.FullName].source
        foreach ($option in $profile.values.Keys) { $expanded = [regex]::Replace($expanded, "(?m)^#define $option \d+", "#define $option $($profile.values[$option])") }
        $expanded = "$macroPrefix`n$expanded"
        $bytes = [Text.Encoding]::UTF8.GetBytes($expanded)
        $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
        $caseRows.Add([ordered]@{ stage=[IO.Path]::GetRelativePath($shaderRoot,$stage.FullName).Replace('\','/'); expandedBytes=$bytes.Length; includeCount=$expandedStages[$stage.FullName].includeCount; sha256=$sha })
    }
    $case = [ordered]@{ name=$caseName; vendor=$vendor.name; loader=$loader.name; profile=$profile.name; dimension=$dimension; capability=$capability.name; macros=$caseMacros; stages=@($caseRows) }
    if ($Detailed) { $case | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output ($caseName + '.json')) -Encoding utf8NoBOM }
    $manifest.Add($case)
    $completedCases++
    if (($completedCases % $ProgressEvery -eq 0) -or ($completedCases -eq $totalCases)) {
        Write-Host "Portability matrix progress: $completedCases/$totalCases cases; elapsed $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) s."
    }
} } } } }
$temporaryManifest = Join-Path $output 'manifest.json.tmp'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporaryManifest -Encoding utf8NoBOM
Move-Item -LiteralPath $temporaryManifest -Destination (Join-Path $output 'manifest.json')
$stopwatch.Stop()
[ordered]@{
    schemaVersion = 2
    status = 'completed'
    completed = $true
    cases = $manifest.Count
    expectedCases = $totalCases
    stagesPerCase = @($stagesByDimension['overworld']).Count
    elapsedSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    detailed = [bool]$Detailed
    evidenceScope = 'Mocked include/profile corpus with explicit macro prefixes and dimension wrapper selection; not loader-patched, driver, GPU, or runtime execution.'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'completion.json.tmp') -Encoding utf8NoBOM
Move-Item -LiteralPath (Join-Path $output 'completion.json.tmp') -Destination (Join-Path $output 'completion.json')
Write-Host "Portability matrix passed: $($manifest.Count) mocked cases; $(@($stagesByDimension['overworld']).Count) stages per case; elapsed $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) s. Detailed case files: $Detailed. Output: $output"
}

if ($Worker) {
    Invoke-PortabilityMatrixWorker
    exit 0
}

# Run the CPU-bound corpus in a child process so timeout handling can terminate
# the complete worker tree.  The worker writes only to a sibling staging path;
# the previous published result is left untouched until its completion contract
# and manifest have both been parsed and checked below.
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$publishedOutput = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $Root 'artifacts/portability-matrix' }
$stagingOutput = "$publishedOutput.staging-$([guid]::NewGuid().ToString('N'))"
$stdout = "$stagingOutput.stdout.txt"
$stderr = "$stagingOutput.stderr.txt"
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $pwsh
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in @('-NoLogo','-NoProfile','-File',$PSCommandPath,'-Root',$Root,'-OutputRoot',$stagingOutput,'-TimeoutSeconds',$TimeoutSeconds,'-ProgressEvery',$ProgressEvery,'-Worker')) { [void]$startInfo.ArgumentList.Add([string]$argument) }
if ($Detailed) { [void]$startInfo.ArgumentList.Add('-Detailed') }
foreach ($profile in @($SelectedProfiles)) { [void]$startInfo.ArgumentList.Add('-SelectedProfiles'); [void]$startInfo.ArgumentList.Add($profile) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
if (-not $process.Start()) { throw 'Failed to start portability-matrix worker.' }
$outputTask = $process.StandardOutput.ReadToEndAsync()
$errorTask = $process.StandardError.ReadToEndAsync()
$timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
if ($timedOut) {
    try { $process.Kill($true) } catch { if (-not $process.HasExited) { throw } }
    $process.WaitForExit()
}
$workerOutput = $outputTask.GetAwaiter().GetResult()
$workerError = $errorTask.GetAwaiter().GetResult()
Set-Content -LiteralPath $stdout -Value $workerOutput -Encoding utf8NoBOM
Set-Content -LiteralPath $stderr -Value $workerError -Encoding utf8NoBOM
if ($timedOut) { throw "Portability matrix timed out after $TimeoutSeconds seconds. Worker PID $($process.Id) was terminated; staging output retained for diagnosis: $stagingOutput" }
if ($process.ExitCode -ne 0) { throw "Portability matrix worker failed with exit code $($process.ExitCode). Staging output retained for diagnosis: $stagingOutput" }
$completionPath = Join-Path $stagingOutput 'completion.json'
$manifestPath = Join-Path $stagingOutput 'manifest.json'
if (-not (Test-Path -LiteralPath $completionPath -PathType Leaf) -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Portability matrix worker produced incomplete output. Staging output retained for diagnosis: $stagingOutput" }
$completion = Get-Content -LiteralPath $completionPath -Raw | ConvertFrom-Json
$publishedManifest = @(Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
if ($completion.schemaVersion -ne 2 -or $completion.status -ne 'completed' -or -not $completion.completed -or $completion.cases -ne $completion.expectedCases -or $completion.cases -ne $publishedManifest.Count) { throw "Portability matrix completion contract failed. Staging output retained for diagnosis: $stagingOutput" }
if (@($publishedManifest | Where-Object { @($_.stages).Count -ne $completion.stagesPerCase }).Count -ne 0) { throw "Portability matrix manifest is partial. Staging output retained for diagnosis: $stagingOutput" }
$previousOutput = $null
if (Test-Path -LiteralPath $publishedOutput) {
    $previousOutput = "$publishedOutput.previous-$([guid]::NewGuid().ToString('N'))"
    Move-Item -LiteralPath $publishedOutput -Destination $previousOutput
}
try {
    Move-Item -LiteralPath $stagingOutput -Destination $publishedOutput
} catch {
    if ($previousOutput -and -not (Test-Path -LiteralPath $publishedOutput) -and (Test-Path -LiteralPath $previousOutput)) { Move-Item -LiteralPath $previousOutput -Destination $publishedOutput }
    throw
}
Write-Host "Portability matrix completed and published: $publishedOutput"
