param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\shaders'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\artifacts\compiled-variants'),
    [string]$Validator = ''
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path

if ($Validator) {
    $resolvedCommand = Get-Command $Validator -CommandType Application -ErrorAction SilentlyContinue
    if ($resolvedCommand) {
        $Validator = $resolvedCommand.Source
    } elseif (Test-Path -LiteralPath $Validator) {
        $Validator = (Resolve-Path -LiteralPath $Validator).Path
    }
}

if (-not $Validator) {
    $bundledRoot = Join-Path $PSScriptRoot '..\tools\glslang'
    if (Test-Path -LiteralPath $bundledRoot) {
        $Validator = Get-ChildItem -LiteralPath $bundledRoot -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @('glslangValidator.exe', 'glslangValidator') } |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not $Validator) {
    $pathCommand = Get-Command glslangValidator -CommandType Application -ErrorAction SilentlyContinue
    if ($pathCommand) { $Validator = $pathCommand.Source }
}

if (-not $Validator -or -not (Test-Path -LiteralPath $Validator)) {
    throw 'glslangValidator is required to generate evaluated shader variants. Pass -Validator, place an official binary under tools\glslang\<version>\, or make glslangValidator available on PATH.'
}

Remove-Item -LiteralPath $OutputRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

. (Join-Path $PSScriptRoot 'profile-config.ps1')
$profiles = Get-ZephProfiles -ShaderRoot $sourceRoot
$dimensions = @{ Overworld = ''; Nether = 'world-1'; End = 'world1' }
$loaders = @(
    @{ Name = 'Iris render-stage model'; Defines = @('#define IRIS_FEATURES 1','#define MC_RENDER_STAGE_SKY 1','#define MC_RENDER_STAGE_SUNSET 2','#define MC_RENDER_STAGE_STARS 3','#define MC_RENDER_STAGE_VOID 4') },
    @{ Name = 'Conservative Oculus model'; Defines = @() }
)
$gpus = @('Generic', 'NVIDIA', 'AMD', 'Intel', 'Mesa', 'Unknown')
$relationships = @{}
$preprocessorCache = @{}
$auditErrors = [System.Collections.Generic.List[string]]::new()

function Expand-ZephSource([string]$path, [System.Collections.IDictionary]$options, [System.Collections.Generic.List[string]]$includes) {
    $full = (Resolve-Path -LiteralPath $path).Path
    $includes.Add($full)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -LiteralPath $full)) {
        if ($line -match '^\s*#version') { continue }
        if ($line -match '^\s*#include\s+"(/[^\"]+)"') {
            $includePath = Join-Path $sourceRoot $Matches[1].TrimStart('/')
            $out.Add((Expand-ZephSource $includePath $options $includes))
            continue
        }
        if ($line -match '^\s*#define\s+(ZEPH_[A-Z_]+)\s+' -and $options.Contains($Matches[1])) {
            $out.Add("#define $($Matches[1]) $($options[$Matches[1]])")
            continue
        }
        $out.Add($line)
    }
    return ($out -join "`n")
}

function Invoke-ZephPreprocessor([string]$Source, [string]$Stage) {
    $temporary = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($temporary, $Source, [Text.UTF8Encoding]::new($false))
        $output = & $Validator -E -S $Stage $temporary 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "glslang preprocessor failed for $Stage`: $output" }
        return $output
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

$programs = Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object { $_.Extension -in '.vsh', '.fsh' } | Sort-Object Name
$logical = @()
foreach ($profile in $profiles | Sort-Object Name) {
    foreach ($dimensionName in $dimensions.Keys | Sort-Object) {
        foreach ($loader in $loaders) {
            foreach ($program in $programs) {
                $candidate = if ($dimensions[$dimensionName]) { Join-Path $sourceRoot (Join-Path $dimensions[$dimensionName] $program.Name) } else { $program.FullName }
                if (-not (Test-Path -LiteralPath $candidate)) { $candidate = $program.FullName }
                $includes = [System.Collections.Generic.List[string]]::new()
                $body = Expand-ZephSource $candidate $profile.Values $includes
                $defines = if ($loader.Defines.Count) { ($loader.Defines -join "`n") + "`n" } else { '' }
                $source = "#version 330 compatibility`n// Zepholume-preprocessed source; loader macro model follows.`n$defines$body`n"
                $stage = if ($program.Extension -eq '.vsh') { 'vert' } else { 'frag' }
                $sourceBytes = [Text.Encoding]::UTF8.GetBytes($source)
                $preprocessorKey = "$stage-" + ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sourceBytes)))
                if ($preprocessorCache.ContainsKey($preprocessorKey)) {
                    $expanded = $preprocessorCache[$preprocessorKey]
                } else {
                    $expanded = Invoke-ZephPreprocessor -Source $source -Stage $stage
                    $preprocessorCache[$preprocessorKey] = $expanded
                }
                $candidateRelative = ($candidate.Substring($sourceRoot.Length + 1) -replace '\\','/')
                if ($profile.Name -eq 'Potato' -and $program.Name -eq 'gbuffers_water.fsh' -and $expanded -match '\b(?:sunSpecular|moonSpecular|reflectedSky)\b') {
                    $auditErrors.Add("Potato retains analytical water code: $candidateRelative")
                }
                if ($profile.Name -eq 'Potato' -and $program.Name -eq 'gbuffers_terrain.fsh' -and $expanded -match 'zephSafeNormalize\s*\(\s*zephNormalView\s*\)') {
                    $auditErrors.Add("Potato terrain retains a normal normalization consumer: $candidateRelative")
                }
                if ($candidateRelative -match '^world(?:-1|1)/' -and $program.Extension -eq '.fsh' -and $expanded -match '\b(?:sunSpecular|moonSpecular|zephCelestialGlow|zephAnalyticSky)\b') {
                    $auditErrors.Add("Dimension wrapper retains Overworld celestial shading: $candidateRelative")
                }
                $bytes = [Text.Encoding]::UTF8.GetBytes($expanded)
                $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash.ToLowerInvariant()
                $uniquePath = Join-Path $OutputRoot ("unique\$hash$($program.Extension)")
                if (-not (Test-Path -LiteralPath $uniquePath)) {
                    New-Item -ItemType Directory -Path (Split-Path $uniquePath) -Force | Out-Null
                    [IO.File]::WriteAllBytes($uniquePath, $bytes)
                }
                foreach ($gpu in $gpus) {
                    $logical += [pscustomobject]@{
                        Profile=$profile.Name
                        Dimension=$dimensionName
                        LoaderModel=$loader.Name
                        GpuIdentity=$gpu
                        Program=[IO.Path]::GetFileNameWithoutExtension($program.Name)
                        Stage=$program.Extension.TrimStart('.')
                        ContentHash=$hash
                        Artifact=($uniquePath.Substring($OutputRoot.Length + 1) -replace '\\','/')
                        OriginalSource=($candidate.Substring($sourceRoot.Length + 1) -replace '\\','/')
                        Includes=@($includes | ForEach-Object { $_.Substring($sourceRoot.Length + 1) -replace '\\','/' } | Select-Object -Unique)
                    }
                    $relationships[$hash] = @($includes | ForEach-Object { $_.Substring($sourceRoot.Length + 1) -replace '\\','/' } | Select-Object -Unique)
                }
            }
        }
    }
}

$logical | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputRoot 'index.json') -Encoding utf8
($relationships.GetEnumerator() | ForEach-Object { [pscustomobject]@{ ContentHash=$_.Key; Includes=$_.Value } }) |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $OutputRoot 'relationships.json') -Encoding utf8

if ($auditErrors.Count -gt 0) {
    $auditErrors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "glslangValidator: $Validator"
Write-Host "Generated $($logical.Count) logical mappings and $((Get-ChildItem (Join-Path $OutputRoot 'unique') -File).Count) unique Zepholume-preprocessed stages."
