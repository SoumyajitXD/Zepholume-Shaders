param([Parameter(Mandatory)][string]$VariantRoot,[Parameter(Mandatory)][string]$OutputRoot)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
function Count([string]$text,[string]$pattern) { return ([regex]::Matches($text,$pattern,[Text.RegularExpressions.RegexOptions]::Multiline)).Count }
$rows = Get-ChildItem -LiteralPath (Join-Path $VariantRoot 'unique') -File | Sort-Object Name | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    [pscustomobject]@{
        ContentHash=$_.BaseName; Stage=$_.Extension.TrimStart('.'); SourceBytes=([IO.FileInfo]$_.FullName).Length; SourceLines=(Count $text '^'); IncludeCount=(Count $text '^\s*#include'); MacroCount=(Count $text '^\s*#\s*(?:define|if|ifdef|ifndef|elif|else|endif)\b'); FunctionCount=(Count $text '(?m)^\s*(?:float|vec[234]|void)\s+\w+\s*\('); UniformCount=(Count $text '\buniform\b'); AttributeCount=(Count $text '\battribute\b'); VaryingCount=(Count $text '\bvarying\b'); TextureCallCount=(Count $text '\b(?:texture|texture2D|texelFetch|textureLod)\s*\('); NormalizeCount=(Count $text '\bnormalize\s*\('); DivisionCount=(Count $text '(?<!/)/(?!/)'); SqrtCount=(Count $text '\b(?:sqrt|inversesqrt)\s*\('); PowCount=(Count $text '\bpow\s*\('); TrigonometricCount=(Count $text '\b(?:sin|cos|tan|asin|acos|atan)\s*\('); SmoothstepCount=(Count $text '\bsmoothstep\s*\('); DynamicBranchCount=(Count $text '\bif\s*\('); DiscardCount=(Count $text '\bdiscard\b'); FragmentOutputCount=(Count $text '\bgl_FragData\s*\[\s*0\s*\]\s*=') }
}
$rows | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $OutputRoot 'stage-stats.json') -Encoding utf8
$summary = $rows | Measure-Object SourceBytes,SourceLines,IncludeCount,MacroCount,FunctionCount,UniformCount,AttributeCount,VaryingCount,TextureCallCount,NormalizeCount,DivisionCount,SqrtCount,PowCount,TrigonometricCount,SmoothstepCount,DynamicBranchCount,DiscardCount,FragmentOutputCount -Sum
[pscustomobject]@{ UniqueStages=$rows.Count; Totals=$summary } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'summary.json') -Encoding utf8
Write-Host "Measured $($rows.Count) unique expanded stages."
