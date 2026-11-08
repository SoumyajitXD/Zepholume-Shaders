[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$water = Get-Content -LiteralPath (Join-Path $root 'shaders/lib/water.glsl') -Raw
$common = Get-Content -LiteralPath (Join-Path $root 'shaders/lib/common.glsl') -Raw

# These locks bind the numeric properties below to the actual helper and its
# call sites. They are not evidence that the GPU executed the GLSL; native
# source-execution tests separately cover output and enclosed skylight.
foreach ($pair in @(
    @($water, 'float sunWeight = zephSolarIllumination(sunElevation, storm);'),
    @($water, 'float moonWeight = zephLunarIllumination(sunElevation, zephWorldElevation(moonDir), storm);'),
    @($water, 'if (sunWeight > 0.0 && skyExposure > 0.0)'),
    @($water, 'if (daylight < 1.0 && skyExposure > 0.0)'),
    @($water, 'if (moonWeight > 0.0)'),
    @($water, 'celestialSpecular *= skyExposure;'),
    @($common, 'zephSaturate(sunElevation * 6.0 + 0.1) * (1.0 - 0.85 * zephSaturate(weather))'),
    @($common, 'zephSaturate(moonElevation * 6.0 + 0.1) * (1.0 - 0.85 * zephSaturate(weather))')
)) { if (-not $pair[0].Contains($pair[1])) { throw "Water gating source contract missing: $($pair[1])" } }

function Clamp01([double]$x) { [Math]::Max(0.0, [Math]::Min(1.0, $x)) }
function Day([double]$y) { $t = Clamp01 (($y + 0.16) / 0.34); $t * $t * (3.0 - 2.0 * $t) }
$elevations = @(-1.0, -0.16, -0.016667, 0.0, 0.05, 0.179999, 0.18, 1.0)
$cases = 0; $skips = 0
foreach ($sun in $elevations) { foreach ($moon in $elevations) {
    foreach ($rain in @(0.0, 0.5, 1.0)) { foreach ($exposure in @(0.0, 0.25, 1.0)) {
        $day = Day $sun
        $weather = 1.0 - 0.85 * (Clamp01 $rain)
        $sw = $day * (Clamp01 ($sun * 6.0 + 0.1)) * $weather
        $mw = (1.0 - $day) * (Clamp01 ($moon * 6.0 + 0.1)) * $weather
        foreach ($lobe in @(0.0, 0.0001, 0.25, 1.0)) {
            # The ungated expression is the independent behavioral oracle:
            # exact-zero branch elimination must preserve finite contributions.
            $expectedSun = $lobe * $sw * $exposure
            $expectedMoon = $lobe * $mw * $exposure
            $actualSun = if ($sw -gt 0 -and $exposure -gt 0) { $lobe * $sw * $exposure } else { 0.0 }
            $actualMoon = if ($day -lt 1 -and $exposure -gt 0 -and $mw -gt 0) { $lobe * $mw * $exposure } else { 0.0 }
            if ($actualSun -ne $expectedSun -or $actualMoon -ne $expectedMoon) { throw 'Water exact-zero gate changed a finite contribution.' }
            if ($sw -eq 0 -or $mw -eq 0 -or $exposure -eq 0) { $skips++ }
            if ($sw -lt 0 -or $sw -gt 1 -or $mw -lt 0 -or $mw -gt 1) { throw 'Illumination out of bounds.' }
            $cases++
        }
    }}
}}
if ($skips -eq 0) { throw 'No zero-gate controls exercised.' }
Write-Host "Water gating contract passed: $cases numeric cases, $skips zero controls; native rendering tested separately."
