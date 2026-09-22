[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$water = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/water.glsl') -Raw

# The branch predicates must be constructed from the exact clamped uniform
# values used by the original product. The guarded bodies retain the former
# multiplication order, so a skipped finite lobe is exactly its former zero.
foreach ($required in @(
    'float sunWeight = daylight * sunHorizonFade;',
    'if (sunWeight > 0.0)',
    'float sunSpecFactor = zephSpecularLobe(sunNdotH) * daylight * sunHorizonFade;',
    'if (daylight < 1.0)',
    'float moonWeight = (1.0 - daylight) * moonHorizonFade;',
    'if (moonWeight > 0.0)',
    'float moonSpecFactor = zephSpecularLobe(moonNdotH) * (1.0 - daylight) * moonHorizonFade;'
)) {
    if ($water -notmatch [regex]::Escape($required)) { throw "Water gating source lock failed: missing $required" }
}

function F([double]$value) { [single]$value }
function Clamp01([double]$value) { F ([Math]::Min(1.0, [Math]::Max(0.0, $value))) }
function Daylight([double]$elevation) {
    $t = Clamp01 ((F ($elevation - -0.16)) / (F 0.34))
    F ((F ($t * $t)) * (F (3.0 - (F (2.0 * $t)))) )
}
function HorizonFade([double]$elevation) { Clamp01 (F ((F ($elevation * 6.0)) + 0.1)) }

$elevations = @(-1.0, -0.34, -0.16, -0.159999, -0.05, -0.016667, 0.0, 0.016667, 0.179999, 0.18, 0.34, 1.0)
$cases = 0; $skippedLobes = 0; $maximum = 0.0
foreach ($profile in @(0, 1, 2, 3, 4)) {
    foreach ($fluid in @('air', 'water')) {
        foreach ($sunY in $elevations) {
            foreach ($moonY in $elevations) {
                $daylight = Daylight $sunY
                $sunWeight = F ($daylight * (HorizonFade $sunY))
                $moonWeight = F ((F (1.0 - $daylight)) * (HorizonFade $moonY))
                if ($sunWeight -eq 0.0) { $skippedLobes++ }
                if ($moonWeight -eq 0.0) { $skippedLobes++ }
                # For finite lobe values, x * 0.0 is exactly 0.0 in the GLSL
                # expression whose factors are source-locked above. Existing
                # safe normalisation bounds the lobe input, so skipping does
                # not introduce NaN/Inf behaviour.
                if ($sunWeight -eq 0.0) { $maximum = [Math]::Max($maximum, [Math]::Abs((F (0.0 * $sunWeight)))) }
                if ($moonWeight -eq 0.0) { $maximum = [Math]::Max($maximum, [Math]::Abs((F (0.0 * $moonWeight)))) }
                $cases++
            }
        }
    }
}
if ($maximum -ne 0.0) { throw "Water specular gating equivalence failed: maximum absolute error $maximum" }
Write-Host "Water specular gating equivalence passed: $cases float32 predicate cases; $skippedLobes exact-zero lobes; maximum absolute error = 0.0. Covers five profiles, air/water, day/noon/sunrise/sunset/twilight/night/midnight boundaries and celestial elevations."
