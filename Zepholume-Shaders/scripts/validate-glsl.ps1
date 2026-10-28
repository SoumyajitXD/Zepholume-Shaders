param(
    [string]$VariantRoot = (Join-Path $PSScriptRoot '..\artifacts\compiled-variants'),
    [string]$ReportRoot = (Join-Path $PSScriptRoot '..\artifacts\glslang-validation'),
    [string]$Validator = '',
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\shaders'),
    [switch]$WarningsAsErrors,
    [ValidateSet('Native','WSL','CI')][string]$ValidatorMode = 'Native',
    [string]$WslDistribution = 'kali-linux'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'validator-backend.ps1')
$validatorBackend = Resolve-ZephValidatorBackend -ValidatorMode $ValidatorMode -Validator $Validator -WslDistribution $WslDistribution
$VariantRoot = (Resolve-Path -LiteralPath $VariantRoot).Path
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$ReportRoot = [IO.Path]::GetFullPath($ReportRoot)
$sourceManifestPath = Join-Path $VariantRoot 'source-manifest.json'
$indexPath = Join-Path $VariantRoot 'index.json'
if (-not (Test-Path -LiteralPath $sourceManifestPath) -or -not (Test-Path -LiteralPath $indexPath)) { throw 'Variant inputs are incomplete: source-manifest.json and index.json are required. Regenerate variants before compilation.' }
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
foreach ($entry in @($sourceManifest.files)) {
    $sourceFile = Join-Path $SourceRoot $entry.path
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw "Variant source is missing: $($entry.path). Regenerate variants." }
    if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -cne $entry.sha256) { throw "Variant source hash is stale: $($entry.path). Regenerate variants." }
}
$currentFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File | Where-Object { $_.Extension -in '.vsh','.fsh','.glsl','.properties','.lang' } | ForEach-Object { $_.FullName.Substring($SourceRoot.Length + 1).Replace('\\','/') } | Sort-Object)
$manifestFiles = @($sourceManifest.files | ForEach-Object path | Sort-Object)
if (Compare-Object $currentFiles $manifestFiles) { throw 'Variant source inventory is stale. Regenerate variants.' }
$logicalMappings = @(Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json)
if ($logicalMappings.Count -eq 0) { throw 'Variant index has no logical mappings. Regenerate variants.' }
$logicalByHash = @{}
foreach ($mapping in $logicalMappings) {
    if (-not $logicalByHash.ContainsKey($mapping.ContentHash)) { $logicalByHash[$mapping.ContentHash] = [Collections.Generic.List[object]]::new() }
    $logicalByHash[$mapping.ContentHash].Add($mapping)
}
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$version = $validatorBackend.Version
Write-Host $version.Trim()
$variantFiles = @(Get-ChildItem -LiteralPath (Join-Path $VariantRoot 'unique') -File -ErrorAction Stop | Where-Object { $_.Extension -in '.vsh','.fsh' } | Sort-Object FullName)
if ($variantFiles.Count -eq 0) { throw "No preprocessed .vsh/.fsh inputs found under $VariantRoot\unique." }
$rows = foreach ($file in $variantFiles) {
    $stage = if ($file.Extension -eq '.vsh') { 'vert' } else { 'frag' }
    if (-not $logicalByHash.ContainsKey($file.BaseName)) { throw "Variant has no logical source mapping: $($file.Name)" }
    $output = Invoke-ZephValidatorBackend -Backend $validatorBackend -Arguments @('-S',$stage,$file.FullName)
    $code = $LASTEXITCODE
    $affected = @($logicalByHash[$file.BaseName] | ForEach-Object { [ordered]@{ Profile=$_.Profile; Dimension=$_.Dimension; LoaderModel=$_.LoaderModel; Program=$_.Program; Stage=$_.Stage; OriginalSource=$_.OriginalSource } } | Sort-Object Profile,Dimension,LoaderModel,Program,Stage -Unique)
    [pscustomobject]@{ Stage=$stage; ContentHash=$file.BaseName; File=($file.FullName.Substring($VariantRoot.Length + 1) -replace '\\','/'); Result=if ($code -eq 0) {'pass'} else {'fail'}; WarningCount=([regex]::Matches($output, '(?im)\bwarning\b')).Count; ErrorCount=([regex]::Matches($output, '(?im)\berror\b')).Count; AffectedVariants=$affected; Output=$output.Trim() }
}
$links = foreach ($pair in ($logicalMappings | Group-Object Profile,Dimension,LoaderModel,Program)) {
    $vertex = @($pair.Group | Where-Object Stage -eq 'vsh' | Select-Object -First 1)
    $fragment = @($pair.Group | Where-Object Stage -eq 'fsh' | Select-Object -First 1)
    if ($vertex.Count -ne 1 -or $fragment.Count -ne 1) { continue }
    # glslang determines each file's stage from .vert/.frag during linking;
    # generated artifacts deliberately retain Minecraft .vsh/.fsh names.
    $linkInputRoot = Join-Path $ReportRoot 'link-inputs'
    New-Item -ItemType Directory -Path $linkInputRoot -Force | Out-Null
    $vertexInput = Join-Path $linkInputRoot ($vertex[0].ContentHash + '.vert')
    $fragmentInput = Join-Path $linkInputRoot ($fragment[0].ContentHash + '.frag')
    if (-not (Test-Path -LiteralPath $vertexInput)) { Copy-Item -LiteralPath (Join-Path $VariantRoot $vertex[0].Artifact) -Destination $vertexInput }
    if (-not (Test-Path -LiteralPath $fragmentInput)) { Copy-Item -LiteralPath (Join-Path $VariantRoot $fragment[0].Artifact) -Destination $fragmentInput }
    $output = Invoke-ZephValidatorBackend -Backend $validatorBackend -Arguments @('-l',$vertexInput,$fragmentInput)
    $code = $LASTEXITCODE
    [pscustomobject]@{ Profile=$vertex[0].Profile; Dimension=$vertex[0].Dimension; LoaderModel=$vertex[0].LoaderModel; Program=$vertex[0].Program; Result=if ($code -eq 0) {'pass'} else {'fail'}; WarningCount=([regex]::Matches($output, '(?im)\bwarning\b')).Count; ErrorCount=([regex]::Matches($output, '(?im)\berror\b')).Count; Output=$output.Trim() }
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $ReportRoot 'glslang-report.json') -Encoding utf8
$links | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $ReportRoot 'glslang-link-report.json') -Encoding utf8
$markdown = "# glslang validation`n`nCompiler: ``$($version.Trim())`` `n`n| Result | Stages | Warnings | Errors |`n| --- | ---: | ---: | ---: |`n"
foreach ($group in $rows | Group-Object Result) { $markdown += "| $($group.Name) | $($group.Count) | $(($group.Group | Measure-Object WarningCount -Sum).Sum) | $(($group.Group | Measure-Object ErrorCount -Sum).Sum) |`n" }
$markdown += "`n| Link result | Programs | Warnings | Errors |`n| --- | ---: | ---: | ---: |`n"
foreach ($group in $links | Group-Object Result) { $markdown += "| $($group.Name) | $($group.Count) | $(($group.Group | Measure-Object WarningCount -Sum).Sum) | $(($group.Group | Measure-Object ErrorCount -Sum).Sum) |`n" }
$markdown += "`nThese inputs are Zepholume-preprocessed source, not Iris-patched source. OpenGL GLSL mode is used; no Vulkan or SPIR-V options are passed. Link checks are separate from loader-patched evidence.`n"
Set-Content -LiteralPath (Join-Path $ReportRoot 'glslang-report.md') -Value $markdown -Encoding utf8
if (($rows | Where-Object Result -eq 'fail').Count) { exit 1 }
if (($links | Where-Object Result -eq 'fail').Count) { exit 1 }
if ($WarningsAsErrors -and ((@($rows | Where-Object { $_.WarningCount -gt 0 }).Count -gt 0) -or (@($links | Where-Object { $_.WarningCount -gt 0 }).Count -gt 0))) { Write-Error 'Standalone GLSL compilation/linking emitted warning(s) and -WarningsAsErrors is enabled.'; exit 1 }
