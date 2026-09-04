[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$InputCsv,
    [Parameter(Mandatory)] [ValidateSet('1.0.2','1.0.3-dev')] [string]$PackVersion,
    [Parameter(Mandatory)] [string]$Profile,
    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$InputCsv = (Resolve-Path -LiteralPath $InputCsv).Path
$rows = @(Import-Csv -LiteralPath $InputCsv)
if ($rows.Count -eq 0) { throw 'Frame-time CSV contains no rows.' }
$samples = [System.Collections.Generic.List[double]]::new()
foreach ($row in $rows) {
    $raw = if ($null -ne $row.frameTimeMs) { $row.frameTimeMs } elseif ($null -ne $row.frametimeMs) { $row.frametimeMs } elseif ($null -ne $row.ms) { $row.ms } else { throw 'CSV must contain frameTimeMs, frametimeMs, or ms.' }
    $value = 0.0
    if (-not [double]::TryParse([string]$raw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or $value -le 0.0) { throw "Invalid frame-time sample: $raw" }
    $samples.Add($value)
}
$sorted = @($samples | Sort-Object)
function Percentile([double]$p) { $index = [Math]::Min($sorted.Count - 1, [Math]::Max(0, [int][Math]::Ceiling($p * $sorted.Count) - 1)); return $sorted[$index] }
$mean = ($samples | Measure-Object -Average).Average
$result = [ordered]@{
    schemaVersion = 1; status = 'measured-input-summary'; packVersion = $PackVersion; profile = $Profile
    inputFile = [IO.Path]::GetFileName($InputCsv); inputSha256 = (Get-FileHash -LiteralPath $InputCsv -Algorithm SHA256).Hash
    samples = $samples.Count; meanFrameTimeMs = $mean; medianFrameTimeMs = Percentile 0.50; p95FrameTimeMs = Percentile 0.95; p99FrameTimeMs = Percentile 0.99
    averageFps = 1000.0 / $mean; onePercentLowFps = 1000.0 / (Percentile 0.99)
    note = 'Compare only records with identical locked environment and scene fields from bench/scene-manifest.json. This script does not infer GPU, CPU, VRAM, power, or utilisation values.'
}
if (-not $OutputJson) { $OutputJson = [IO.Path]::ChangeExtension($InputCsv, '.summary.json') }
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputJson -Encoding utf8NoBOM
Write-Host "Wrote frame-time summary: $OutputJson"
