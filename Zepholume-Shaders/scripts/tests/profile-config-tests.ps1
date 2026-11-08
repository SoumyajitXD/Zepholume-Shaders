[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$shaderRoot = Join-Path $root 'shaders'
. (Join-Path $root 'scripts/profile-config.ps1')

$expected = @('Potato','Low','Balanced','High','Ultra')
$properties = Get-Content -LiteralPath (Join-Path $shaderRoot 'shaders.properties') -Raw
$settings = Get-Content -LiteralPath (Join-Path $shaderRoot 'lib/settings.glsl') -Raw
$lang = Get-Content -LiteralPath (Join-Path $shaderRoot 'lang/en_US.lang') -Raw
$profiles = @(Get-ZephProfiles -ShaderRoot $shaderRoot)
$names = @($profiles | ForEach-Object Name)
if (($names.Count -ne 5) -or (($names -join '|') -cne ($expected -join '|'))) {
    throw "Expected exactly five ordered profiles: $($expected -join ', '); found: $($names -join ', ')"
}
if (([regex]::Matches($properties, '(?m)^screen\s*=\s*[^\r\n]*<profile>(?:\s|$)')).Count -ne 1) {
    throw 'The main settings screen must expose one <profile> control.'
}

$options = Get-ZephShaderOptions -ShaderRoot $shaderRoot
$screenMatches = [regex]::Matches($properties, '(?m)^screen(?:\.([A-Za-z_]+))?\s*=\s*([^\r\n]+)')
$screenNames = @($screenMatches | Where-Object { $_.Groups[1].Success } | ForEach-Object { $_.Groups[1].Value })
if (@($screenNames | Group-Object | Where-Object Count -gt 1).Count -ne 0) { throw 'Duplicate settings screen definition.' }
$displayed = [System.Collections.Generic.List[string]]::new()
foreach ($screen in $screenMatches) {
    foreach ($token in $screen.Groups[2].Value.Trim() -split '\s+') {
        if ($token -match '^\[([A-Za-z_]+)\]$') {
            if ($screenNames -cnotcontains $Matches[1]) { throw "Settings screen references missing sub-screen: $token" }
        } elseif ($token -match '^ZEPH_[A-Z_]+$') {
            if (-not $options.Contains($token)) { throw "Settings screen references missing option: $token" }
            $displayed.Add($token)
        } elseif ($token -cnotin @('<profile>','<empty>')) { throw "Unknown settings screen token: $token" }
    }
}
if (@($displayed | Group-Object | Where-Object Count -gt 1).Count -ne 0) { throw 'A shader option is shown more than once.' }
if (Compare-Object @($options.Keys | Where-Object { $_ -ne 'ZEPH_PROFILE_TIER' } | Sort-Object) @($displayed | Sort-Object)) {
    throw 'The settings screens do not show each adjustable option exactly once.'
}
$tooltipMatches = [regex]::Matches($lang, '(?m)^option\.(ZEPH_[A-Z_]+)\.comment=(\S.*)$')
$tooltipNames = @($tooltipMatches | ForEach-Object { $_.Groups[1].Value })
if ($tooltipNames.Count -ne $options.Count -or
    (Compare-Object @($options.Keys | Sort-Object) @($tooltipNames | Sort-Object)) -or
    @($tooltipNames | Group-Object | Where-Object Count -gt 1).Count -ne 0 -or
    $lang -match '(?m)^comment\.ZEPH_') {
    throw 'Every shader option must have exactly one Iris-compatible option.<name>.comment tooltip.'
}
$profilesByName = @{}
foreach ($profile in $profiles) {
    $profilesByName[$profile.Name] = $profile.Values
    if ($profile.Values.Count -ne $options.Count) { throw "Profile $($profile.Name) does not assign every shader option." }
    if ($lang -notmatch "(?m)^profile\.$($profile.Name)=") { throw "Missing profile label: $($profile.Name)" }
}
foreach ($option in $options.Keys) {
    $default = [regex]::Match($settings, "(?m)^#define\s+$option\s+(\d+)\s*//")
    if (-not $default.Success -or $profilesByName['Balanced'][$option] -ne [int]$default.Groups[1].Value) {
        throw "Balanced does not match the source default for $option."
    }
    if (([regex]::Matches($lang, "(?m)^option\.$option=")).Count -ne 1) { throw "Missing or duplicate option label: $option" }
    foreach ($value in $options[$option]) {
        if (([regex]::Matches($lang, "(?m)^value\.$option\.$value=")).Count -ne 1) { throw "Missing or duplicate option value label: ${option}:$value" }
    }
}

$potato = $profilesByName['Potato']
$low = $profilesByName['Low']
if ($low['ZEPH_WATER_WAVES'] -ne 0 -or $profilesByName['Balanced']['ZEPH_WATER_WAVES'] -ne 1) {
    throw 'Low must report water movement off; Balanced must enable its supported movement path.'
}
# The water movement implementation is only compiled from tier 2 upwards.
$waterSource = Get-Content -LiteralPath (Join-Path $shaderRoot 'lib/water.glsl') -Raw
if ($waterSource -notmatch '(?m)^#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1\s*$') {
    throw 'Water movement gate changed; recheck profile defaults and labels.'
}
$weatherSource = Get-Content -LiteralPath (Join-Path $shaderRoot 'lib/weather.glsl') -Raw
$weatherBranches = [regex]::Match($weatherSource, '(?s)#if ZEPH_EFFECTIVE_WEATHER_QUALITY == 1\s+const float weatherBlend = ([0-9.]+);\s+#elif ZEPH_EFFECTIVE_WEATHER_QUALITY == 2\s+const float weatherBlend = ([0-9.]+);\s+#else\s+const float weatherBlend = ([0-9.]+);')
if (-not $weatherBranches.Success) { throw 'Weather levels no longer define their expected compile-time blend strengths.' }
$weatherStrengths = @(1..3 | ForEach-Object { [double]::Parse($weatherBranches.Groups[$_].Value, [Globalization.CultureInfo]::InvariantCulture) })
if ($weatherStrengths[0] -ne 0.22 -or $weatherStrengths[0] -ge $weatherStrengths[1] -or $weatherStrengths[1] -ge $weatherStrengths[2] -or $weatherStrengths[2] -gt 1) {
    throw 'Weather strengths must preserve Balanced, increase by tier, and stay bounded.'
}
foreach ($option in @('ZEPH_PROFILE_TIER','ZEPH_FACE_LIGHTING_QUALITY','ZEPH_CLOUD_QUALITY','ZEPH_WATER_QUALITY','ZEPH_WEATHER_QUALITY')) {
    if ($potato[$option] -ge $low[$option]) { throw "Potato must reduce $option below Low." }
}
$high = $profilesByName['High']
$ultra = $profilesByName['Ultra']
foreach ($option in @('ZEPH_PROFILE_TIER','ZEPH_CLOUD_TIER','ZEPH_WATER_TIER','ZEPH_WEATHER_QUALITY')) {
    if ($ultra[$option] -le $high[$option]) { throw "Ultra must increase $option above High." }
}
foreach ($name in @('High','Ultra')) {
    foreach ($option in @('ZEPH_CONTRAST','ZEPH_SATURATION')) {
        if ($profilesByName[$name][$option] -ne $profilesByName['Balanced'][$option]) {
            throw "$name must not force stronger $option than Balanced."
        }
    }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('zeph-profile-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fixture 'lib') | Out-Null
    Copy-Item -LiteralPath (Join-Path $shaderRoot 'lib/settings.glsl') -Destination (Join-Path $fixture 'lib/settings.glsl')
    # Regex captures retain CR at line ends on Windows; both newline forms
    # must parse the same five profiles without a phantom empty assignment.
    foreach ($newline in @("`n", "`r`n")) {
        $fixtureProperties = $properties.Replace("`r`n", "`n").Replace("`n", $newline)
        [IO.File]::WriteAllText((Join-Path $fixture 'shaders.properties'), $fixtureProperties, [Text.UTF8Encoding]::new($false))
        $parsed = @(Get-ZephProfiles -ShaderRoot $fixture)
        if (($parsed.Name -join '|') -cne ($expected -join '|')) { throw 'Profile parser changed between LF and CRLF input.' }
    }
    Set-Content -LiteralPath (Join-Path $fixture 'shaders.properties') -Value ($properties + "`nprofile.Low = ZEPH_PROFILE_TIER:1`n") -Encoding utf8NoBOM
    $rejectedDuplicate = $false
    try { Get-ZephProfiles -ShaderRoot $fixture | Out-Null } catch { $rejectedDuplicate = $_.Exception.Message -match 'Duplicate profile definition' }
    if (-not $rejectedDuplicate) { throw 'Profile parser accepted a duplicate profile definition.' }
    # Profile parsing must be independent of Git checkout line endings and BOM.
    $canonical = (($properties -replace "`r`n", "`n") -replace "[`r`n]+$", "")
    foreach ($sample in @(
        @{ Name='LF'; Newline="`n"; Bom=$false },
        @{ Name='CRLF'; Newline="`r`n"; Bom=$false },
        @{ Name='CRLF-BOM'; Newline="`r`n"; Bom=$true }
    )) {
        $encoding = [Text.UTF8Encoding]::new([bool]$sample.Bom)
        $sampleText = $canonical.Replace("`n", $sample.Newline) + $sample.Newline
        [IO.File]::WriteAllText((Join-Path $fixture 'shaders.properties'), $sampleText, $encoding)
        $found = @(Get-ZephProfiles -ShaderRoot $fixture)
        if ($found.Count -ne 5 -or (($found.Name -join '|') -cne ($expected -join '|'))) {
            throw "Profile parsing differs for $($sample.Name)."
        }
        foreach ($profile in $found) {
            foreach ($option in $profilesByName[$profile.Name].Keys) {
                if ($profile.Values[$option] -ne $profilesByName[$profile.Name][$option]) {
                    throw "Profile $($profile.Name) differs for $($sample.Name): $option"
                }
            }
        }
    }

    $invalidCrlf = $canonical.Replace('ZEPH_PROFILE_TIER:0', 'ZEPH_UNKNOWN:0').Replace("`n", "`r`n") + "`r`n"
    [IO.File]::WriteAllText((Join-Path $fixture 'shaders.properties'), $invalidCrlf, [Text.UTF8Encoding]::new($false))
    $rejectedInvalid = $false
    try { Get-ZephProfiles -ShaderRoot $fixture | Out-Null } catch { $rejectedInvalid = $_.Exception.Message -match 'undefined option: ZEPH_UNKNOWN' }
    if (-not $rejectedInvalid) { throw 'Profile parser did not report the intended undefined option in a CRLF assignment.' }


    $badCases = @(
        @{ Text=$properties.Replace('profile.Potato =', 'profile.Potato :'); Error='Malformed profile declaration' },
        @{ Text=$properties.Replace('profile.Potato =', 'profile. ='); Error='Malformed profile declaration' },
        @{ Text=$properties.Replace('ZEPH_PROFILE_TIER:0', 'ZEPH_UNKNOWN:0'); Error='undefined option' },
        @{ Text=$properties.Replace('ZEPH_PROFILE_TIER:0', 'ZEPH_PROFILE_TIER:9'); Error='outside declared range' },
        @{ Text=$properties.Replace('ZEPH_PROFILE_TIER:0', 'ZEPH_PROFILE_TIER:0 ZEPH_PROFILE_TIER:0'); Error='more than once' }
    )
    foreach ($case in $badCases) {
        Set-Content -LiteralPath (Join-Path $fixture 'shaders.properties') -Value $case.Text -Encoding utf8NoBOM
        $rejected = $false
        try { Get-ZephProfiles -ShaderRoot $fixture | Out-Null } catch { $rejected = $_.Exception.Message -match $case.Error }
        if (-not $rejected) { throw "Profile parser accepted malformed assignment: $($case.Error)" }
    }
    foreach ($case in @(
        @{ Text=$settings + "`n#define ZEPH_EXPOSURE 1 // [0 1 2]`n"; Error='Duplicate shader option definition' },
        @{ Text=$settings.Replace('ZEPH_EXPOSURE 1 // [0 1 2]', 'ZEPH_EXPOSURE 1'); Error='lacks a valid numeric range' },
        @{ Text=$settings.Replace('ZEPH_EXPOSURE 1 // [0 1 2]', 'ZEPH_EXPOSURE 1 // [0 1 1 2]'); Error='Duplicate shader option value' },
        @{ Text=$settings.Replace('ZEPH_EXPOSURE 1 // [0 1 2]', 'ZEPH_EXPOSURE 9 // [0 1 2]'); Error='default outside declared range' }
    )) {
        [IO.File]::WriteAllText((Join-Path $fixture 'lib/settings.glsl'), $case.Text, [Text.UTF8Encoding]::new($false))
        $rejected = $false
        try { Get-ZephShaderOptions -ShaderRoot $fixture | Out-Null } catch { $rejected = $_.Exception.Message -match $case.Error }
        if (-not $rejected) { throw "Option parser accepted malformed settings: $($case.Error)" }
    }
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

Write-Host 'Profile configuration tests passed: five profiles, defaults, ranges, screens, labels, tooltips, quality distinctions, and malformed-input rejection.'
