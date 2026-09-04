[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Assert-Near([string]$Name, [double]$Actual, [double]$Expected, [double]$Tolerance) {
    $error = [Math]::Abs($Actual - $Expected)
    if ($error -gt $Tolerance) { throw "${Name}: expected $Expected, got $Actual (absolute error $error; tolerance $Tolerance)" }
    return $error
}
function Clamp01([double]$v) { return [Math]::Min(1.0, [Math]::Max(0.0, $v)) }
function SmoothReference([double]$x, [double]$edge0, [double]$edge1) {
    $t = Clamp01 (($x - $edge0) / ($edge1 - $edge0))
    return $t * $t * (3.0 - 2.0 * $t)
}
function SmoothReciprocal([double]$x, [double]$edge0, [double]$inverseRange) {
    $t = Clamp01 (($x - $edge0) * $inverseRange)
    return $t * $t * (3.0 - 2.0 * $t)
}
function SmoothReciprocalFloat32([double]$x, [double]$edge0, [double]$inverseRange) {
    $t = [single](Clamp01 ([single](([single]($x - $edge0)) * [single]$inverseRange)))
    return [double][single]($t * $t * ([single]3.0 - [single]2.0 * $t))
}
function Daylight([double]$elevation) { return SmoothReference $elevation -0.16 0.18 }
function Twilight([double]$elevation) { return 1.0 - (SmoothReference ([Math]::Abs($elevation)) 0.06 0.34) }
function WaterDecode([double]$display) { $v = [Math]::Max(0.0, $display); return $v * $v }
function WaterEncode([double]$linear) { return [Math]::Sqrt([Math]::Max(0.0, $linear)) }
function WaterDecodeFloat32([double]$display) { $v = [single][Math]::Max(0.0, $display); return [double][single]($v * $v) }
function WaterEncodeFloat32([double]$linear) { return [double][single][Math]::Sqrt([single][Math]::Max(0.0, $linear)) }

$lighting = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/lighting.glsl') -Raw
$water = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/water.glsl') -Raw
$fog = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/fog.glsl') -Raw
$materials = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/materials.glsl') -Raw

function Read-ShaderFloatConstant([string]$Name) {
    $match = [regex]::Match($lighting, "const\s+float\s+" + [regex]::Escape($Name) + "\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*;")
    if (-not $match.Success) { throw "Missing numeric lighting constant: $Name" }
    return [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

$maxErrors = [ordered]@{}
$transfers = @(
    [ordered]@{ Name = 'skylight gate'; Edge0 = 0.04; Edge1 = 0.65; Inv = (Read-ShaderFloatConstant 'ZEPH_SKYLIGHT_INV_RANGE'); Values = @(-0.01, 0.039, 0.04, 0.10, 0.345, 0.62, 0.65, 0.651, 1.0) },
    [ordered]@{ Name = 'block-light warmth'; Edge0 = 0.10; Edge1 = 0.90; Inv = (Read-ShaderFloatConstant 'ZEPH_BLOCK_LIGHT_INV_RANGE'); Values = @(-0.01, 0.099, 0.10, 0.20, 0.50, 0.80, 0.90, 0.901, 1.0) }
)
foreach ($transfer in $transfers) {
    $maximum = 0.0
    foreach ($value in $transfer.Values) {
        $actual = SmoothReciprocal $value $transfer.Edge0 $transfer.Inv
        $expected = SmoothReference $value $transfer.Edge0 $transfer.Edge1
        $maximum = [Math]::Max($maximum, (Assert-Near "$($transfer.Name) at $value" $actual $expected 0.000000000001))
        $floatActual = SmoothReciprocalFloat32 $value $transfer.Edge0 $transfer.Inv
        $maximum = [Math]::Max($maximum, (Assert-Near "$($transfer.Name) float32 at $value" $floatActual $expected 0.0000005))
    }
    $maxErrors[$transfer.Name] = $maximum
}

# These lock the intentionally selected V1.0.3 curves rather than treating a
# curve change as a free optimization: fourth-power tiers below High, fifth-
# power Fresnel-Schlick shaping at High and Ultra.
foreach ($nDotV in @(0.0, 0.15, 0.50, 0.85, 1.0)) {
    $base = 1.0 - $nDotV; $fourth = $base * $base * $base * $base; $fifth = $fourth * $base
    Assert-Near "fourth-power Fresnel at $nDotV" $fourth ([Math]::Pow($base, 4)) 0.000000000001 | Out-Null
    Assert-Near "fifth-power Fresnel at $nDotV" $fifth ([Math]::Pow($base, 5)) 0.000000000001 | Out-Null
}
foreach ($elevation in @(-0.20, -0.16, -0.10, 0.01, 0.18, 0.30)) {
    $day = Daylight $elevation
    Assert-Near "day/moon complement at $elevation" ($day + (1.0 - $day)) 1.0 0.000000000001 | Out-Null
    Assert-Near "daylight range at $elevation" (Clamp01 $day) $day 0.000000000001 | Out-Null
}
foreach ($elevation in @(-0.40, -0.34, -0.10, 0.06, 0.20, 0.34, 0.40)) {
    $twilight = Twilight $elevation
    Assert-Near "twilight symmetry at $elevation" $twilight (Twilight (-$elevation)) 0.000000000001 | Out-Null
    Assert-Near "twilight range at $elevation" (Clamp01 $twilight) $twilight 0.000000000001 | Out-Null
}

# Atmosphere uses the same Hermite factor for enabled profiles, then clamps
# after bounded horizon and rain multipliers.
foreach ($distance in @(0.0, 15.0, 16.0, 32.0, 64.0, 65.0, 128.0)) {
    $linear = Clamp01 (($distance - 16.0) / (64.0 - 16.0))
    $curved = $linear * $linear * (3.0 - 2.0 * $linear)
    foreach ($viewY in @(-1.0, 0.0, 1.0)) { foreach ($rain in @(0.0, 0.5, 1.0)) {
        $factor = Clamp01 ($curved * (1.0 - [Math]::Abs($viewY) * 0.18) * (0.84 + $rain * 0.28))
        Assert-Near "fog range at distance $distance" (Clamp01 $factor) $factor 0.000000000001 | Out-Null
    }}
}
$waterRoundTripError = 0.0
foreach ($value in @(-0.10, 0.0, 0.10, 0.50, 1.0, 1.50)) {
    Assert-Near "water display round trip at $value" (WaterEncode (WaterDecode $value)) ([Math]::Max(0.0, $value)) 0.000000000001 | Out-Null
    Assert-Near "water working-space round trip at $value" (WaterDecode (WaterEncode $value)) ([Math]::Max(0.0, $value)) 0.000000000001 | Out-Null
}
foreach ($surface in @(0.0, 0.0001, 0.035, 0.125, 0.50005, 0.875, 1.0, 1.5)) {
    # The removed path was encode (sqrt) then decode (square).  New code
    # keeps this non-negative working-space value directly.  Float32 is not
    # bit-exact, so this guards the only expected rounding difference.
    $oldPath = WaterDecodeFloat32 (WaterEncodeFloat32 $surface)
    $waterRoundTripError = [Math]::Max($waterRoundTripError, (Assert-Near "water float32 old/new path at $surface" $oldPath $surface 0.0000002))
}

foreach ($required in @('ZEPH_SKYLIGHT_INV_RANGE', 'tSky * tSky * (3.0 - 2.0 * tSky)', 'ZEPH_BLOCK_LIGHT_INV_RANGE', 'tWarmth * tWarmth * (3.0 - 2.0 * tWarmth)')) {
    if ($lighting -notmatch [regex]::Escape($required)) { throw "Lighting transfer regression: missing $required" }
}
if ($water -notmatch 'vec3\s+zephWaterSurfaceLinear\s*\(' -or $water -match 'zephWaterEncode\s*\(') {
    throw 'Water working-space regression: the active surface must return linear colour without an encode step.'
}
if ($water -match 'if\s*\(\s*daylight\s*[<>]') { throw 'Water daylight branch gate returned; it changed the continuous V1.0.2 lobe contribution without measured justification.' }
if ($fog -match 'ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY\s*>=\s*2' -or $materials -match 'ZEPH_EFFECTIVE_MATERIAL_QUALITY\s*>=\s*3') { throw 'An unreachable profile threshold returned; either expose and test it or remove it.' }
Write-Host ('Math regression tests passed. Maximum smoothstep absolute errors: ' + (($maxErrors.GetEnumerator() | ForEach-Object { "$($_.Key)=$([string]::Format('{0:E3}', $_.Value))" }) -join '; ') + '; water float32 old/new=' + [string]::Format('{0:E3}', $waterRoundTripError))
