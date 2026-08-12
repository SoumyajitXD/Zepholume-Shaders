[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$Detailed,
    [string[]]$SelectedProfiles,
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$shaderRoot = Join-Path $Root 'shaders'
. (Join-Path $PSScriptRoot 'profile-config.ps1')
$output = if ($OutputRoot) { $OutputRoot } else { Join-Path $Root 'artifacts/portability-matrix' }
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Path $output | Out-Null

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
    @{ name='iris'; macros=@('IRIS_FEATURES','MC_GL_VERSION 330','MC_GLSL_VERSION 330') },
    @{ name='oculus-conservative'; macros=@('MC_GL_VERSION 330','MC_GLSL_VERSION 330') },
    @{ name='unknown-loader'; macros=@() }
)
$profiles = @(Get-ZephProfiles -ShaderRoot $shaderRoot | ForEach-Object { @{ name=$_.Name.ToLowerInvariant().Replace('_','-'); values=$_.Values } })
if ($SelectedProfiles) {
    $profiles = @($profiles | Where-Object { $_.name -in $SelectedProfiles })
    if ($profiles.Count -ne $SelectedProfiles.Count) { throw "Unknown profile selection: $($SelectedProfiles -join ', ')" }
}
$dimensions = @('overworld','nether','end')
$capabilities = @('gl33-no-optional-extensions','higher-gl-retaining-glsl330')
$stages = @(Get-ChildItem -LiteralPath $shaderRoot -Recurse -File | Where-Object { $_.Extension -in '.vsh','.fsh' })
$expandedStages = @{}
foreach ($stage in $stages) {
    $includeCount = 0
    $expanded = Expand-ZephInclude $stage.FullName ([System.Collections.Generic.List[string]]::new()) ([ref]$includeCount)
    if ($expanded -match '#include\s+"') { throw "Unexpanded include in $($stage.FullName)" }
    $expandedStages[$stage.FullName] = [ordered]@{ source=$expanded; includeCount=$includeCount }
}
$manifest = [System.Collections.Generic.List[object]]::new()
foreach ($vendor in $vendors) { foreach ($loader in $loaders) { foreach ($profile in $profiles) { foreach ($dimension in $dimensions) { foreach ($capability in $capabilities) {
    $caseName = "$($vendor.name)--$($loader.name)--$($profile.name)--$dimension--$capability"
    $caseRows = [System.Collections.Generic.List[object]]::new()
    foreach ($stage in $stages) {
        $expanded = $expandedStages[$stage.FullName].source
        foreach ($option in $profile.values.Keys) { $expanded = [regex]::Replace($expanded, "(?m)^#define $option \d+", "#define $option $($profile.values[$option])") }
        $bytes = [Text.Encoding]::UTF8.GetBytes($expanded)
        $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
        $caseRows.Add([ordered]@{ stage=[IO.Path]::GetRelativePath($shaderRoot,$stage.FullName).Replace('\','/'); expandedBytes=$bytes.Length; includeCount=$expandedStages[$stage.FullName].includeCount; sha256=$sha })
    }
    $case = [ordered]@{ name=$caseName; vendor=$vendor.name; loader=$loader.name; profile=$profile.name; dimension=$dimension; capability=$capability; macros=@($vendor.macros + $loader.macros); stages=@($caseRows) }
    if ($Detailed) { $case | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output ($caseName + '.json')) -Encoding utf8NoBOM }
    $manifest.Add($case)
} } } } }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8NoBOM
Write-Host "Portability matrix passed: $($manifest.Count) mocked cases; $($stages.Count) stages per case. Detailed case files: $Detailed. Output: $output"
