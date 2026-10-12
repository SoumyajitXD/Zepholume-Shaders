[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$shaderRoot = Join-Path $Root 'shaders'
$programs = @(Get-ChildItem -LiteralPath $shaderRoot -File | Where-Object { $_.Extension -in '.vsh','.fsh' } | Sort-Object Name)
if ($programs.Count -eq 0) { throw 'No root shader programs found.' }

$dimensions = @(
    [ordered]@{ Folder = 'world0'; Macro = $null },
    [ordered]@{ Folder = 'world-1'; Macro = 'ZEPH_DIM_NETHER' },
    [ordered]@{ Folder = 'world1'; Macro = 'ZEPH_DIM_END' }
)
$utf8 = [Text.UTF8Encoding]::new($false)
$mismatches = [System.Collections.Generic.List[string]]::new()

foreach ($dimension in $dimensions) {
    $directory = Join-Path $shaderRoot $dimension.Folder
    if (-not $Check) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    foreach ($program in $programs) {
        $source = [IO.File]::ReadAllText($program.FullName).Replace("`r`n", "`n")
        $expected = if ($dimension.Macro) {
            [regex]::Replace($source, '\A(#version[^\n]*\n)', "`$1#define $($dimension.Macro)`n", 1)
        } else { $source }
        $target = Join-Path $directory $program.Name
        if ($Check) {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $mismatches.Add("Missing dimension wrapper: $($dimension.Folder)/$($program.Name)")
            } elseif ([IO.File]::ReadAllText($target).Replace("`r`n", "`n") -cne $expected) {
                $mismatches.Add("Dimension wrapper drift: $($dimension.Folder)/$($program.Name)")
            }
        } else {
            [IO.File]::WriteAllText($target, $expected, $utf8)
        }
    }
    if (Test-Path -LiteralPath $directory) {
        foreach ($extra in Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Extension -in '.vsh','.fsh' -and $_.Name -notin $programs.Name }) {
            $mismatches.Add("Unexpected dimension wrapper: $($dimension.Folder)/$($extra.Name)")
        }
    }
}

if ($mismatches.Count -gt 0) { throw ($mismatches -join [Environment]::NewLine) }
if ($Check) { Write-Host "Dimension wrapper topology passed: $($dimensions.Count) complete sets x $($programs.Count) root stages." }
else { Write-Host "Synchronized $($dimensions.Count * $programs.Count) dimension wrapper stages." }
