[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$InputCsv,
    [Parameter(Mandatory)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')] [string]$PackVersion,
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
    if (-not [double]::TryParse([string]$raw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or -not [double]::IsFinite($value) -or $value -le 0.0) { throw "Invalid frame-time sample: $raw" }
    $samples.Add($value)
}
$sorted = @($samples | Sort-Object)
function Percentile([double]$p) { $index = [Math]::Min($sorted.Count - 1, [Math]::Max(0, [int][Math]::Ceiling($p * $sorted.Count) - 1)); return $sorted[$index] }
# Select ceil(1% of frames), including at least one, and average frame times
# before conversion to FPS. This differs from averaging per-frame FPS.
$slowestCount = [int][Math]::Ceiling($sorted.Count * 0.01)
$slowestMean = 0.0
for ($i = $sorted.Count - $slowestCount; $i -lt $sorted.Count; $i++) { $slowestMean += $sorted[$i] / $slowestCount }
$mean = ($samples | Measure-Object -Average).Average
$variance = 0.0
foreach ($sample in $samples) { $variance += ($sample - $mean) * ($sample - $mean) / $samples.Count }
if (-not [double]::IsFinite($mean) -or -not [double]::IsFinite($variance)) { throw 'Frame-time aggregate overflow.' }
$result = [ordered]@{
    schemaVersion = 2; status = 'measured-input-summary'; packVersion = $PackVersion; profile = $Profile
    inputFile = [IO.Path]::GetFileName($InputCsv); inputSha256 = (Get-FileHash -LiteralPath $InputCsv -Algorithm SHA256).Hash
    samples = $samples.Count; meanFrameTimeMs = $mean; medianFrameTimeMs = Percentile 0.50; p95FrameTimeMs = Percentile 0.95; p99FrameTimeMs = Percentile 0.99
    averageFps = 1000.0 / $mean; onePercentLowFps = 1000.0 / (Percentile 0.99)
    p99EquivalentFps = 1000.0 / (Percentile 0.99)
    slowestOnePercentFrameCount = $slowestCount; slowestOnePercentMeanFrameTimeMs = $slowestMean
    slowestOnePercentFps = 1000.0 / $slowestMean
    frameTimeVarianceMs2 = $variance; frameTimeStdDevMs = [Math]::Sqrt($variance)
    capturedFrameSeconds = $mean * $samples.Count / 1000.0
    note = 'Nearest-rank percentiles; population variance within this run. onePercentLowFps is a legacy alias of p99EquivalentFps, not slowestOnePercentFps. The latter is 1000 divided by the mean of the slowest ceiling(1% of sample count) frame times. Captured frame duration is not wall-clock validation. No GPU/CPU bottleneck, power or utilisation is inferred. Synthetic input is not runtime evidence.'
}
foreach ($key in @('meanFrameTimeMs','averageFps','p99EquivalentFps','slowestOnePercentMeanFrameTimeMs','slowestOnePercentFps','capturedFrameSeconds')) {
    if (-not [double]::IsFinite([double]$result[$key]) -or [double]$result[$key] -le 0) { throw "Invalid derived statistic: $key" }
}
if (-not $OutputJson) { $OutputJson = [IO.Path]::ChangeExtension($InputCsv, '.summary.json') }
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputJson -Encoding utf8NoBOM
Write-Host "Wrote frame-time summary: $OutputJson"
