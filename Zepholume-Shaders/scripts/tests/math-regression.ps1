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
$atmosphere = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/atmosphere.glsl') -Raw
$cloudFragment = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/cloud_fragment.glsl') -Raw
$materials = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/materials.glsl') -Raw
$fragment = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/fragment.glsl') -Raw
$vertex = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/vertex.glsl') -Raw
$skyFragment = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/lib/sky_fragment.glsl') -Raw
$blockProperties = Get-Content -LiteralPath (Join-Path $projectRoot 'shaders/block.properties') -Raw

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
# Every immersed medium must reach the loader's fog endpoint. Water may reach
# it slightly earlier by profile, but rain and view angle must not weaken it.
$fogFactorSource = [regex]::Match($fog, '(?s)float\s+zephFogFactor\s*\([^)]*\)\s*\{.*?\n\}').Value
if ($fogFactorSource -notmatch 'if\s*\(\s*isEyeInWater\s*>=\s*1\s*\)' -or
    $fogFactorSource -notmatch 'mediumRange\s*=\s*fogEnd\s*-\s*fogStart\s*;' -or
    $fogFactorSource -notmatch 'if\s*\(\s*mediumRange\s*<=\s*0\.0\s*\)\s*return\s+d\s*>=\s*fogStart\s*\?\s*1\.0\s*:\s*0\.0\s*;' -or
    $fogFactorSource -notmatch 'factor\s*=\s*zephSaturate\s*\(\s*\(d\s*-\s*fogStart\)\s*/\s*mediumRange\s*\)' -or
    $fogFactorSource -notmatch 'return\s+zephSaturate\s*\(\s*factor\s*\)\s*;' -or
    $fogFactorSource.IndexOf('if (isEyeInWater >= 1)') -gt $fogFactorSource.IndexOf('zephAtmosphereFactor(')) {
    throw 'Fog regression: immersed media must use the loader distance range before open-air atmosphere.'
}
foreach ($sourceCase in @(
    @{ Name = 'open air'; Text = $atmosphere; Function = 'zephAtmosphereFactor'; Distance = 'distance' },
    @{ Name = 'cloud'; Text = $cloudFragment; Function = 'zephCloudFogFactor'; Distance = 'distance' }
)) {
    $body = [regex]::Match($sourceCase.Text, "(?s)float\s+$($sourceCase.Function)\s*\([^)]*\)\s*\{.*?\n\}").Value
    if ($body -notmatch 'range\s*=\s*fogEnd\s*-\s*fogStart\s*;' -or
        $body -notmatch 'if\s*\(\s*range\s*<=\s*0\.0\s*\)\s*return\s+distance\s*>=\s*fogStart\s*\?\s*1\.0\s*:\s*0\.0\s*;' -or
        $body -notmatch 'distance\s*-\s*fogStart\s*\)\s*/\s*range' -or
        $body -match 'max\s*\(\s*fogStart\s*,\s*1\.0\s*\)') {
        throw "Fog regression: $($sourceCase.Name) must preserve positive loader ranges and guard invalid ranges."
    }
}
foreach ($medium in @(1, 2, 3)) {
    foreach ($tier in @(0, 1, 2, 3, 4)) {
        $boost = if ($medium -ne 1) { 1.0 } else { @(1.0, 1.02, 1.06, 1.09, 1.12)[$tier] }
        foreach ($range in @(@(16.0,64.0), @(0.0,0.5), @(0.25,0.75), @(-0.5,0.5), @(0.0,0.000001))) {
            $start = $range[0]; $end = $range[1]
            foreach ($distance in @(($start - 1.0), $start, (($start + $end) / 2.0), $end, ($end + 1.0))) {
                $loaderFactor = Clamp01 (($distance - $start) / ($end - $start))
                $factor = Clamp01 ($loaderFactor * $boost)
                if ($distance -le $start) { Assert-Near "medium $medium tier $tier start $start" $factor 0.0 0.000000000001 | Out-Null }
                if ($distance -ge $end) { Assert-Near "medium $medium tier $tier endpoint $end" $factor 1.0 0.000000000001 | Out-Null }
                if ($medium -ge 2 -or $tier -eq 0) {
                    Assert-Near "medium $medium tier $tier at $distance in $start..$end" $factor $loaderFactor 0.000000000001 | Out-Null
                }
            }
        }
    }
}
# The old denominator floor missed the endpoint of a valid 1e-6 range.
$oldTinyEnd = Clamp01 (0.000001 / [Math]::Max(0.000001, 0.0001))
Assert-Near 'old tiny-range failure fixture' $oldTinyEnd 0.01 0.000000000001 | Out-Null
foreach ($start in @(0.0, 0.25, -0.5)) {
    foreach ($end in @($start, ($start - 0.25))) {
        $below = $start - 0.1
        $at = $start
        $above = $start + 0.1
        Assert-Near "invalid range below $start..$end" $(if ($below -ge $start) { 1.0 } else { 0.0 }) 0.0 0.0 | Out-Null
        Assert-Near "invalid range at $start..$end" $(if ($at -ge $start) { 1.0 } else { 0.0 }) 1.0 0.0 | Out-Null
        Assert-Near "invalid range above $start..$end" $(if ($above -ge $start) { 1.0 } else { 0.0 }) 1.0 0.0 | Out-Null
    }
}
foreach ($range in @(@(0.0, 0.5), @(0.0, 0.000001), @(-0.5, 0.5))) {
    $start = $range[0]; $end = $range[1]
    $midpoint = ($start + $end) / 2.0
    $linear = Clamp01 (($midpoint - $start) / ($end - $start))
    Assert-Near "open-air positive midpoint $start..$end" ($linear * $linear * (3.0 - 2.0 * $linear)) 0.5 0.000000000001 | Out-Null
    Assert-Near "cloud positive midpoint $start..$end" $linear 0.5 0.000000000001 | Out-Null
    Assert-Near "positive endpoint $start..$end" (Clamp01 (($end - $start) / ($end - $start))) 1.0 0.0 | Out-Null
}
$specularReuseMaxError = 0.0
foreach ($lobe in @(0.0, 0.00001, 0.12, 0.5, 0.99999, 1.0)) {
    foreach ($daylight in @(0.0, 0.01, 0.2, 0.5, 0.99, 1.0)) {
        foreach ($horizon in @(0.0, 0.01, 0.2, 0.5, 0.99, 1.0)) {
            $old = [single]([single]([single]$lobe * [single]$daylight) * [single]$horizon)
            $weight = [single]([single]$daylight * [single]$horizon)
            $new = [single]([single]$lobe * $weight)
            $specularReuseMaxError = [Math]::Max($specularReuseMaxError, (Assert-Near 'specular weight reuse float32' $new $old 0.00000012))
        }
    }
}
if ($water -notmatch 'sunSpecFactor\s*=\s*zephSpecularLobe\s*\(\s*sunNdotH\s*\)\s*\*\s*sunWeight\s*;' -or
    $water -notmatch 'moonSpecFactor\s*=\s*zephSpecularLobe\s*\(\s*moonNdotH\s*\)\s*\*\s*moonWeight\s*;') {
    throw 'Water optimization regression: celestial lobes must reuse the already computed weights.'
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
if ($water -notmatch 'float\s+sunWeight\s*=\s*daylight\s*\*\s*sunHorizonFade\s*;' -or $water -notmatch 'float\s+moonWeight\s*=\s*\(\s*1\.0\s*-\s*daylight\s*\)\s*\*\s*moonHorizonFade\s*;') { throw 'Water regression: celestial lobe weights must remain explicit uniform-only products.' }
if ($water -notmatch 'if\s*\(\s*sunWeight\s*>\s*0\.0\s*\)' -or $water -notmatch 'if\s*\(\s*daylight\s*<\s*1\.0\s*\)' -or $water -notmatch 'if\s*\(\s*moonWeight\s*>\s*0\.0\s*\)') { throw 'Water regression: exact-zero celestial lobe gates are missing.' }
if ($fog -match 'ZEPH_EFFECTIVE_ATMOSPHERE_QUALITY\s*>=\s*2' -or $materials -match 'ZEPH_EFFECTIVE_MATERIAL_QUALITY\s*>=\s*3') { throw 'An unreachable profile threshold returned; either expose and test it or remove it.' }
if ($fog -notmatch 'isEyeInWater\s*>=\s*2') { throw 'Fog regression: lava and powdered snow must retain loader fog colour.' }
if ($blockProperties -notmatch '(?m)^block\.10001\s*=\s*minecraft:water\s*$') { throw 'Water routing regression: pack-local ID 10001 must map only to minecraft:water.' }
if ($vertex -notmatch 'mc_Entity\.x\s*-\s*10001\.0' -or $vertex -notmatch 'if\s*\(\s*zephIsWater\s*>\s*0\.5\s*\)') { throw 'Water routing regression: only classified water may be displaced.' }
if ($fragment -notmatch 'zephIsWater\s*>\s*0\.5\s*\?\s*zephWaterSurfaceLinear') { throw 'Water routing regression: non-water translucent terrain must bypass water shading.' }
if ($vertex -notmatch 'gl_TextureMatrix\s*\[\s*0\s*\]\s*\*\s*gl_MultiTexCoord0') { throw 'Texture-coordinate regression: generic textured programs must apply texture matrix 0.' }
if ($skyFragment -notmatch 'skyDir\s*=\s*zephSafeNormalize\s*\(\s*zephSkyDirection\s*\)') { throw 'Sky regression: interpolated sky directions must be normalized before angular calculations.' }

# P0 lighting invariant.  The production fragment source must consume the
# loader-provided per-surface lightmap before decoding/scene grading.  The
# numeric cases below use the same component-wise multiplication that source
# locks above: zero incident light must not retain albedo, while full light
# preserves it.  This is a source-derived regression, not a rendered claim.
if ($fragment -notmatch '(?m)^\s*uniform\s+sampler2D\s+lightmap\s*;') { throw 'Lighting regression: missing lightmap sampler.' }
if ($fragment -notmatch 'source\.rgb\s*\*=\s*texture2D\s*\(\s*lightmap\s*,\s*zephLightCoord\s*\)\.rgb\s*;') { throw 'Lighting regression: source must apply per-surface lightmap irradiance.' }
if ($fragment -notmatch '#ifdef\s+ZEPH_LIGHTMAP_LIT_PROGRAM') { throw 'Lighting regression: lightmap sampling must be restricted to lit program routes.' }
foreach ($case in @(
    [ordered]@{ Name = 'zero sky and block light'; Albedo = 0.80; Lightmap = 0.0; Expected = 0.0 },
    [ordered]@{ Name = 'mixed cave light'; Albedo = 0.80; Lightmap = 0.25; Expected = 0.20 },
    [ordered]@{ Name = 'full light'; Albedo = 0.80; Lightmap = 1.0; Expected = 0.80 }
)) {
    $lit = [double][single]([single]$case.Albedo * [single]$case.Lightmap)
    Assert-Near "lightmap irradiance $($case.Name)" $lit $case.Expected 0.0000001 | Out-Null
}
Write-Host ('Math regression tests passed. Maximum smoothstep absolute errors: ' + (($maxErrors.GetEnumerator() | ForEach-Object { "$($_.Key)=$([string]::Format('{0:E3}', $_.Value))" }) -join '; ') + '; water float32 old/new=' + [string]::Format('{0:E3}', $waterRoundTripError) + '; specular weight reuse float32=' + [string]::Format('{0:E3}', $specularReuseMaxError))
