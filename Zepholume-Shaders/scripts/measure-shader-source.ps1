param(
    [string]$VariantRoot = (Join-Path $PSScriptRoot '..\artifacts\compiled-variants'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\artifacts\shader-source-metrics')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $VariantRoot 'unique'))) { throw "Missing evaluated variants: $VariantRoot. Run scripts/generate-compiled-variants.ps1 first." }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
function Count([string]$text,[string]$pattern) { return ([regex]::Matches($text,$pattern,[Text.RegularExpressions.RegexOptions]::Multiline)).Count }

$stageMap = @{}
$rows = Get-ChildItem -LiteralPath (Join-Path $VariantRoot 'unique') -File | Sort-Object Name | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    $obj = [pscustomobject]@{
        ContentHash=$_.BaseName; Stage=$_.Extension.TrimStart('.'); SourceBytes=([IO.FileInfo]$_.FullName).Length; SourceLines=(Count $text '^'); IncludeCount=(Count $text '^\s*#include'); MacroCount=(Count $text '^\s*#\s*(?:define|if|ifdef|ifndef|elif|else|endif)\b'); FunctionCount=(Count $text '(?m)^\s*(?:float|vec[234]|void)\s+\w+\s*\('); UniformCount=(Count $text '\buniform\b'); AttributeCount=(Count $text '\battribute\b'); VaryingCount=(Count $text '\bvarying\b'); TextureCallCount=(Count $text '\b(?:texture|texture2D|texelFetch|textureLod)\s*\('); NormalizeCount=(Count $text '\b(?:normalize|zephSafeNormalize)\s*\('); DivisionCount=(Count $text '(?<!/)/(?!/)'); SqrtCount=(Count $text '\b(?:sqrt|inversesqrt)\s*\('); PowCount=(Count $text '\bpow\s*\('); TrigonometricCount=(Count $text '\b(?:sin|cos|tan|asin|acos|atan)\s*\('); SmoothstepCount=(Count $text '\bsmoothstep\s*\('); DynamicBranchCount=(Count $text '\bif\s*\('); DiscardCount=(Count $text '\bdiscard\b'); FragmentOutputCount=(Count $text '\bgl_FragData\s*\[\s*0\s*\]\s*=') }
    $stageMap[$_.BaseName] = $obj
    $obj
}
$rows | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $OutputRoot 'stage-stats.json') -Encoding utf8
$summary = $rows | Measure-Object SourceBytes,SourceLines,IncludeCount,MacroCount,FunctionCount,UniformCount,AttributeCount,VaryingCount,TextureCallCount,NormalizeCount,DivisionCount,SqrtCount,PowCount,TrigonometricCount,SmoothstepCount,DynamicBranchCount,DiscardCount,FragmentOutputCount -Sum

# Profile and Program breakdown from index.json if present
$indexPath = Join-Path $VariantRoot 'index.json'
if (Test-Path -LiteralPath $indexPath) {
    $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
    $profileGroups = $index | Group-Object Profile
    $profileMetrics = @{}
    foreach ($pg in $profileGroups) {
        $uniqueHashes = $pg.Group | Select-Object -ExpandProperty ContentHash -Unique
        $profileRows = $uniqueHashes | ForEach-Object { $stageMap[$_] } | Where-Object { $null -ne $_ }
        $profileSummary = $profileRows | Measure-Object SourceBytes,SourceLines,TextureCallCount,NormalizeCount,DivisionCount,SqrtCount,PowCount,TrigonometricCount,SmoothstepCount,DynamicBranchCount -Sum
        $profileMetrics[$pg.Name] = [pscustomobject]@{
            UniqueStages = $profileRows.Count
            SourceBytes = ($profileSummary | Where-Object Property -eq 'SourceBytes').Sum
            SourceLines = ($profileSummary | Where-Object Property -eq 'SourceLines').Sum
            TextureCalls = ($profileSummary | Where-Object Property -eq 'TextureCallCount').Sum
            Normalizations = ($profileSummary | Where-Object Property -eq 'NormalizeCount').Sum
            SqrtCalls = ($profileSummary | Where-Object Property -eq 'SqrtCount').Sum
            PowCalls = ($profileSummary | Where-Object Property -eq 'PowCount').Sum
            SmoothstepCalls = ($profileSummary | Where-Object Property -eq 'SmoothstepCount').Sum
            Divisions = ($profileSummary | Where-Object Property -eq 'DivisionCount').Sum
            TrigCalls = ($profileSummary | Where-Object Property -eq 'TrigonometricCount').Sum
        }
    }
    $profileMetrics | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'profile-stats.json') -Encoding utf8
}

[pscustomobject]@{ UniqueStages=$rows.Count; Totals=$summary } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'summary.json') -Encoding utf8
Write-Host "Measured $($rows.Count) unique expanded stages."
