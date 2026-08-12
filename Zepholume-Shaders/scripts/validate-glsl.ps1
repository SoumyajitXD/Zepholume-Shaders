param(
    [string]$VariantRoot = (Join-Path $PSScriptRoot '..\artifacts\compiled-variants'),
    [string]$ReportRoot = (Join-Path $PSScriptRoot '..\artifacts\glslang-validation'),
    [string]$Validator = ''
)
$ErrorActionPreference = 'Stop'
if (-not $Validator) { $Validator = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\tools\glslang') -Filter glslangValidator.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
if (-not $Validator -or -not (Test-Path -LiteralPath $Validator)) { throw 'glslangValidator is unavailable. Install an official Khronos release under tools\glslang\<version>\ or pass -Validator.' }
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$version = & $Validator --version 2>&1 | Out-String
Write-Host $version.Trim()
$rows = foreach ($file in Get-ChildItem -LiteralPath (Join-Path $VariantRoot 'unique') -File) {
    $stage = if ($file.Extension -eq '.vsh') { 'vert' } else { 'frag' }
    $output = & $Validator -S $stage $file.FullName 2>&1 | Out-String
    $code = $LASTEXITCODE
    [pscustomobject]@{ Stage=$stage; ContentHash=$file.BaseName; File=($file.FullName.Substring($VariantRoot.Length + 1) -replace '\\','/'); Result=if ($code -eq 0) {'pass'} else {'fail'}; WarningCount=([regex]::Matches($output, '(?im)\bwarning\b')).Count; ErrorCount=([regex]::Matches($output, '(?im)\berror\b')).Count; Output=$output.Trim() }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $ReportRoot 'glslang-report.json') -Encoding utf8
$markdown = "# glslang validation`n`nCompiler: ``$($version.Trim())`` `n`n| Result | Stages | Warnings | Errors |`n| --- | ---: | ---: | ---: |`n"
foreach ($group in $rows | Group-Object Result) { $markdown += "| $($group.Name) | $($group.Count) | $(($group.Group | Measure-Object WarningCount -Sum).Sum) | $(($group.Group | Measure-Object ErrorCount -Sum).Sum) |`n" }
$markdown += "`nThese inputs are Zepholume-preprocessed source, not Iris-patched source. OpenGL GLSL mode is selected by stage only; no Vulkan or SPIR-V options are passed.`n"
Set-Content -LiteralPath (Join-Path $ReportRoot 'glslang-report.md') -Value $markdown -Encoding utf8
if (($rows | Where-Object Result -eq 'fail').Count) { exit 1 }
