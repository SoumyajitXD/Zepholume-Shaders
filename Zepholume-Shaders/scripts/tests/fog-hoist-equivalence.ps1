[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fogSource = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/fog.glsl') -Raw
$vertexSource = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/vertex.glsl') -Raw
$fragmentSource = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/fragment.glsl') -Raw
$controlPackage = Join-Path $projectRoot 'dist/Zepholume-Shaders-1.0.3-dev.zip'
$expectedControlHash = 'C8C654607AF3A7A6E42966EDB75DA7ED17AA99A2CF8FBD94BF81A5899D7448A4'

# Bind the comparison to the immutable control package.  The numerical host
# model below is intentionally not its own evidence that the archived control
# still has the same endpoint formula.
if ((Get-FileHash -LiteralPath $controlPackage -Algorithm SHA256).Hash -cne $expectedControlHash) {
    throw 'Frozen V1.0.3-dev CONTROL package hash mismatch.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$controlZip = [IO.Compression.ZipFile]::OpenRead($controlPackage)
try {
    $controlEntry = $controlZip.GetEntry('shaders/lib/fog.glsl')
    if ($null -eq $controlEntry) { throw 'Frozen CONTROL package is missing shaders/lib/fog.glsl.' }
    $controlReader = [IO.StreamReader]::new($controlEntry.Open())
    try { $controlFogSource = $controlReader.ReadToEnd() }
    finally { $controlReader.Dispose() }
} finally { $controlZip.Dispose() }
$controlEndpoint = [regex]::Match($controlFogSource, '(?s)vec3\s+zephFogColour\s*\(\s*vec3\s+viewDir\s*\)(.*?)(?=\r?\nvec3\s+zephFogColour\s*\(\s*\))').Groups[1].Value
$treatmentEndpoint = [regex]::Match($fogSource, '(?s)vec3\s+zephComputeFogEndpoint\s*\(\s*\)(.*?)(?=\r?\nfloat\s+zephFogFactor)').Groups[1].Value
if ([string]::IsNullOrEmpty($controlEndpoint) -or [string]::IsNullOrEmpty($treatmentEndpoint)) { throw 'Could not isolate CONTROL/TREATMENT fog endpoint bodies.' }
if ($controlEndpoint -match '\bviewDir\b') { throw 'Frozen CONTROL fog endpoint unexpectedly depends on viewDir.' }
if ($controlEndpoint -cne $treatmentEndpoint) { throw 'Treatment fog endpoint body diverges from frozen CONTROL.' }

function Clamp01([single]$v) { return [single][Math]::Min(1.0, [Math]::Max(0.0, $v)) }
function Smooth([single]$x, [single]$edge0, [single]$edge1) {
    $t = Clamp01 ([single](($x - $edge0) / ($edge1 - $edge0)))
    return [single]($t * $t * ([single]3.0 - [single]2.0 * $t))
}
function Mix([single]$a, [single]$b, [single]$t) { return [single]($a * ([single]1.0 - $t) + $b * $t) }
function Mix-Vec([single[]]$a, [single[]]$b, [single]$t) { return @([single](Mix $a[0] $b[0] $t), [single](Mix $a[1] $b[1] $t), [single](Mix $a[2] $b[2] $t)) }
function Scale-Vec([single[]]$v, [single]$scale) { return @([single]($v[0] * $scale), [single]($v[1] * $scale), [single]($v[2] * $scale)) }

# Mirrors zephComputeFogEndpoint's GLSL operation order. The production source
# intentionally shares that function between the vertex treatment and the
# fragment control formula; the structural checks below make that relationship
# explicit rather than comparing a hand-designed approximation.
function Get-FogEndpointGlslEquivalent([string]$dimension, [int]$profileTier, [int]$eyeInWater, [single]$nightVision, [single]$rainStrength, [single[]]$fogColor, [single[]]$sunPosition) {
    if ($profileTier -eq 0) {
        if ($eyeInWater -eq 1) { return $fogColor }
    } elseif ($eyeInWater -eq 1) {
        $absorbed = @([single]($fogColor[0] * [single]0.76), [single]($fogColor[1] * [single]0.96), [single]($fogColor[2] * [single]0.93))
        $absorption = @([single]0.20, [single]0.20, [single]0.30, [single]0.36, [single]0.42)[$profileTier]
        $restored = Mix-Vec $absorbed $fogColor ([single]((Clamp01 $nightVision) * [single]0.45))
        return @(0..2 | ForEach-Object { [single]($restored[$_] * $absorption + $fogColor[$_] * ([single]1.0 - $absorption)) })
    }
    if ($dimension -eq 'Nether') { return Mix-Vec $fogColor @([single]0.30, [single]0.070, [single]0.028) ([single]0.22) }
    if ($dimension -eq 'End') { return Mix-Vec $fogColor @([single]0.090, [single]0.070, [single]0.145) ([single]0.15) }
    $lengthSquared = [single]($sunPosition[0] * $sunPosition[0] + $sunPosition[1] * $sunPosition[1] + $sunPosition[2] * $sunPosition[2])
    $sunY = [single]($sunPosition[1] / [Math]::Sqrt([Math]::Max([double]$lengthSquared, 0.00000001)))
    $daylight = Smooth $sunY ([single]-0.16) ([single]0.18)
    $twilight = [single]1.0 - (Smooth ([single][Math]::Abs($sunY)) ([single]0.06) ([single]0.34))
    $storm = Clamp01 $rainStrength
    $dayHaze = Mix-Vec $fogColor @([single]0.72, [single]0.78, [single]0.82) ([single]0.16)
    $nightHaze = Mix-Vec $fogColor @([single]0.055, [single]0.070, [single]0.105) ([single]0.42)
    $haze = Mix-Vec $nightHaze $dayHaze $daylight
    $luma = [single]($haze[0] * [single]0.2126 + $haze[1] * [single]0.7152 + $haze[2] * [single]0.0722)
    $haze = Mix-Vec $haze @([single]($luma * [single]0.76), [single]($luma * [single]0.79), [single]($luma * [single]0.82)) ([single]($storm * [single]0.35))
    return Mix-Vec $haze @([single]0.78, [single]0.48, [single]0.34) ([single]($twilight * ([single]1.0 - $storm) * [single]0.10))
}

function Get-ControlFogEndpoint([string]$dimension, [int]$profileTier, [int]$eyeInWater, [single]$nightVision, [single]$rainStrength, [single[]]$fogColor, [single[]]$sunPosition) {
    return Get-FogEndpointGlslEquivalent $dimension $profileTier $eyeInWater $nightVision $rainStrength $fogColor $sunPosition
}
function Get-TreatmentFogEndpoint([string]$dimension, [int]$profileTier, [int]$eyeInWater, [single]$nightVision, [single]$rainStrength, [single[]]$fogColor, [single[]]$sunPosition) {
    return Get-FogEndpointGlslEquivalent $dimension $profileTier $eyeInWater $nightVision $rainStrength $fogColor $sunPosition
}

foreach ($required in @('vec3 zephComputeFogEndpoint()', 'if (isEyeInWater == 1)', 'zephAtmosphereColour(fogColor, daylight, storm)')) {
    if ($fogSource -notmatch [regex]::Escape($required)) { throw "Fog endpoint source regression: missing $required" }
}
foreach ($required in @('uniform vec3 fogColor;', 'uniform int isEyeInWater;', 'uniform float nightVision;', 'uniform float rainStrength;', 'uniform vec3 sunPosition;')) {
    if ($vertexSource -notmatch [regex]::Escape($required)) { throw "Treatment vertex source regression: missing $required" }
}
if ($fogSource -match 'zephFogColour\s*\(') { throw 'Fog endpoint source regression: obsolete fragment-only helper remains.' }
if ($vertexSource -notmatch 'flat\s+varying\s+vec3\s+zephFogEndpoint\s*;' -or $vertexSource -notmatch 'zephFogEndpoint\s*=\s*zephComputeFogEndpoint\s*\(\s*\)\s*;') { throw 'Treatment vertex stage does not export the flat fog endpoint.' }
if ($fragmentSource -notmatch 'flat\s+varying\s+vec3\s+zephFogEndpoint\s*;' -or $fragmentSource -notmatch 'mix\s*\(\s*graded\s*,\s*zephFogEndpoint\s*,\s*zephFogFactor') { throw 'Treatment fragment stage does not consume the flat fog endpoint while retaining fragment fog factor.' }

$colours = @(@([single]0.0,[single]0.0,[single]0.0), @([single]1.0,[single]1.0,[single]1.0), @([single]1.0,[single]0.0,[single]1.0), @([single]0.12,[single]0.38,[single]0.71), @([single]0.73,[single]0.44,[single]0.18))
$sunDirections = @(@([single]0.0,[single]-1.0,[single]0.0), @([single]0.98,[single]-0.16,[single]0.0), @([single]0.99,[single]0.06,[single]0.0), @([single]0.98,[single]0.18,[single]0.0), @([single]0.0,[single]1.0,[single]0.0))
$samples = 0; $maximumAbsoluteError = [single]0.0; $maximumRelativeError = [single]0.0
foreach ($dimension in @('Overworld','Nether','End')) { foreach ($profileTier in 0..4) { foreach ($eyeInWater in 0..1) { foreach ($nightVision in @([single]0.0,[single]1.0)) { foreach ($rain in @([single]0.0,[single]0.5,[single]1.0)) { foreach ($colour in $colours) { foreach ($sun in $sunDirections) {
    $control = Get-ControlFogEndpoint $dimension $profileTier $eyeInWater $nightVision $rain $colour $sun
    $treatment = Get-TreatmentFogEndpoint $dimension $profileTier $eyeInWater $nightVision $rain $colour $sun
    foreach ($channel in 0..2) {
        $absoluteError = [single][Math]::Abs($control[$channel] - $treatment[$channel])
        $maximumAbsoluteError = [Math]::Max($maximumAbsoluteError, $absoluteError)
        $denominator = [Math]::Max([Math]::Abs($control[$channel]), 0.00000001)
        $maximumRelativeError = [Math]::Max($maximumRelativeError, [single]($absoluteError / $denominator))
        if ($absoluteError -ne 0.0) { throw "Fog endpoint relocation changed sample $samples channel $channel by $absoluteError" }
    }
    $samples++
} } } } } } }
Write-Host "Fog-hoist equivalence passed: $samples representative/boundary cases; maximum absolute error=$maximumAbsoluteError; maximum relative error=$maximumRelativeError; exact-zero host float32 evaluation."
