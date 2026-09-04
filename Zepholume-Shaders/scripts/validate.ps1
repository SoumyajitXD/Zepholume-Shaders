[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Package
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$errors = [System.Collections.Generic.List[string]]::new()
$packageEntries = @()
if ($Package) {
    $Package = (Resolve-Path -LiteralPath $Package).Path
    if ([System.IO.Path]::GetExtension($Package) -ne '.zip') { $errors.Add("Package is not a ZIP file: $Package") }
    else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Package)
        try {
            $packageEntries = @($archive.Entries | ForEach-Object FullName)
            if ($packageEntries | Where-Object { $_ -match '\\' }) { $errors.Add("ZIP contains backslash path(s): $Package") }
            if (-not ($packageEntries -contains 'shaders/shaders.properties')) { $errors.Add("ZIP does not contain shaders/ at its root: $Package") }
            if ($packageEntries | Where-Object { $_ -match '^(?:[^/]+/)?\.\.(?:/|$)' }) { $errors.Add("ZIP contains traversal path(s): $Package") }
            foreach ($duplicate in ($packageEntries | Group-Object | Where-Object Count -gt 1)) { $errors.Add("ZIP contains duplicate entry: $($duplicate.Name)") }
            if ($packageEntries | Where-Object { $_ -match '(^|/)(?:dist|artifacts|runtime|tools)(/|$)|\.(?:log|tmp|bak)$' }) { $errors.Add("ZIP contains generated/runtime artifact(s): $Package") }
        } finally { $archive.Dispose() }
    }
}
$required = @(
    'README.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md',
    'docs/ARCHITECTURE.md','docs/BASELINE_PERFORMANCE.md','docs/COMPATIBILITY_MATRIX.md','docs/GPU_COMPATIBILITY_POLICY.md','docs/KNOWN_ISSUES.md','docs/PERFORMANCE_BUDGET.md','docs/PORTABILITY_AUDIT.md','docs/RESEARCH.md','docs/RUNTIME_RESULTS.md','docs/RUNTIME_TEST_CHANGES.md','docs/SHADER_COST_REPORT.md','docs/SHADER_VARIANT_MATRIX.md','docs/SOURCE_PROVENANCE.md','docs/TESTING.md','docs/UNRESOLVED_LOADER_ISSUES.md',
    'shaders/shaders.properties','shaders/lang/en_US.lang','shaders/lib/settings.glsl','shaders/lib/profile.glsl','shaders/lib/common.glsl','shaders/lib/color.glsl','shaders/lib/fog.glsl','shaders/lib/water.glsl','shaders/lib/vertex.glsl','shaders/lib/fragment.glsl'
)
foreach ($relative in $required) { if (-not (Test-Path -LiteralPath (Join-Path $Root $relative))) { $errors.Add("Missing required file: $relative") } }
$shaderRoot = Join-Path $Root 'shaders'
$programs = @(Get-ChildItem -LiteralPath $shaderRoot -Recurse -File | Where-Object { $_.Extension -in '.vsh','.fsh' })
if ($programs.Count -eq 0) { $errors.Add('No program shaders found.') }
if ($Package) {
    foreach ($requiredPackageEntry in @('README.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md','docs/ARCHITECTURE.md','docs/PROFILE_GUIDE.md','shaders/shaders.properties')) {
        if ($packageEntries -notcontains $requiredPackageEntry) { $errors.Add("ZIP missing required entry: $requiredPackageEntry") }
    }
    foreach ($shaderFile in (Get-ChildItem -LiteralPath $shaderRoot -Recurse -File)) {
        $relative = $shaderFile.FullName.Substring($shaderRoot.Length + 1).Replace('\','/')
        if ($packageEntries -notcontains "shaders/$relative") { $errors.Add("ZIP missing shader source: shaders/$relative") }
    }
}
foreach ($sourceFile in (Get-ChildItem -LiteralPath $shaderRoot -Recurse -File | Where-Object { $_.Extension -in '.vsh','.fsh','.glsl','.properties','.lang' })) {
    if ([System.IO.File]::ReadAllBytes($sourceFile.FullName) -contains 0) { $errors.Add("NUL byte in shader source: $($sourceFile.FullName)") }
}

function Resolve-ZephInclude {
    param([string]$Path, [System.Collections.Generic.List[string]]$Stack)
    $fullPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    if ($Stack.Contains($fullPath)) { throw "Include cycle: $($Stack -join ' -> ') -> $fullPath" }
    if ($Stack.Count -ge 8) { throw "Excessive include depth (maximum 8): $($Stack -join ' -> ') -> $fullPath" }
    $Stack.Add($fullPath)
    $source = Get-Content -LiteralPath $fullPath -Raw
    $source = [regex]::Replace($source, '#include\s+"([^"]+)"', {
        param($match)
        $include = $match.Groups[1].Value
        if ($include -match '^[A-Za-z]:|^\\\\') { throw "Absolute include path: ${fullPath}: $include" }
        $candidate = Join-Path $shaderRoot $include.TrimStart('/')
        if (-not (Test-Path -LiteralPath $candidate)) { throw "Unresolved include: ${fullPath}: $include" }
        Resolve-ZephInclude -Path $candidate -Stack $Stack
    })
    $Stack.RemoveAt($Stack.Count - 1)
    return $source
}

$includeFiles = @(Get-ChildItem -LiteralPath (Join-Path $shaderRoot 'lib') -File -Filter '*.glsl')
foreach ($includeFile in $includeFiles) {
    $includeSource = Get-Content -LiteralPath $includeFile.FullName -Raw
    if ($includeSource -notmatch '(?ms)^\s*#ifndef\s+([A-Z_][A-Z0-9_]*)\s*\r?\n\s*#define\s+\1\b') {
        $errors.Add("Missing or malformed include guard: $($includeFile.FullName)")
    }
}

# GLSL has no forward declaration for global variables.  fog.glsl's helper
# bodies consume these uniforms, so expanding it before their declarations
# causes every ordinary fragment program to fail on strict GLSL 330 compilers.
$fragmentLibrary = Join-Path $shaderRoot 'lib/fragment.glsl'
if (Test-Path -LiteralPath $fragmentLibrary) {
    $fragmentSource = Get-Content -LiteralPath $fragmentLibrary -Raw
    $fogInclude = $fragmentSource.IndexOf('#include "/lib/fog.glsl"', [System.StringComparison]::Ordinal)
    $fogUniform = $fragmentSource.IndexOf('uniform vec3 fogColor;', [System.StringComparison]::Ordinal)
    if ($fogInclude -lt 0 -or $fogUniform -lt 0 -or $fogInclude -lt $fogUniform) {
        $errors.Add("Fog helper include must follow its fog uniform declarations: $fragmentLibrary")
    }
}

$resolved = @{}
foreach ($shader in $programs) {
    $raw = Get-Content -LiteralPath $shader.FullName -Raw
    $first = (Get-Content -LiteralPath $shader.FullName -TotalCount 1)
    if ($first -notmatch '^#version 330 compatibility$') { $errors.Add("Invalid version declaration: $($shader.FullName)") }
    if ($raw.Trim().Length -eq 0) { $errors.Add("Empty shader: $($shader.FullName)") }
    if ($raw -match '(?m)^\s*#define\s+#') { $errors.Add("Malformed preprocessor definition: $($shader.FullName)") }
    if ($raw -match '(?m)^\s*#define\s+(?![A-Za-z_]\w*(?:\s|$))') { $errors.Add("Malformed preprocessor definition: $($shader.FullName)") }
    if ($raw -match '(?mi)^\s*#extension\b') { $errors.Add("Extensions are not permitted by the GLSL 330 portability floor: $($shader.FullName)") }
    if ($raw -match '\b(?:imageLoad|imageStore|imageAtomic|atomic\w*|textureGather|texelFetch|barrier|memoryBarrier|subgroup\w*)\s*\(') { $errors.Add("Post-GLSL-330 feature: $($shader.FullName)") }
    if ($raw -match '(?m)^\s*precision\s+(?:lowp|mediump|highp)\b') { $errors.Add("Desktop precision qualifier is not permitted: $($shader.FullName)") }
    if ($raw -match '(?i)\bsqrt\s*\(\s*-\s*\d') { $errors.Add("Constant negative sqrt input: $($shader.FullName)") }
    if ($raw -match '(?i)\bpow\s*\(\s*0(?:\.0*)?\s*,\s*0(?:\.0*)?\s*\)') { $errors.Add("Undefined pow(0,0): $($shader.FullName)") }
    if ($raw -match '/\s*0(?:\.0*)?\b') { $errors.Add("Literal division by zero: $($shader.FullName)") }
    if ($raw -match '\bMC_GL_(?:VENDOR|RENDERER)_[A-Z_]+\b' -and $raw -notmatch 'ZEPH_VENDOR_WORKAROUND') { $errors.Add("Vendor-specific code lacks ZEPH_VENDOR_WORKAROUND documentation marker: $($shader.FullName)") }
    $peerExtension = if ($shader.Extension -eq '.vsh') { '.fsh' } else { '.vsh' }
    $peer = [System.IO.Path]::ChangeExtension($shader.FullName, $peerExtension)
    if (-not (Test-Path -LiteralPath $peer)) { $errors.Add("Missing program pair: $($shader.FullName)") }
    try { $resolved[$shader.FullName] = Resolve-ZephInclude -Path $shader.FullName -Stack ([System.Collections.Generic.List[string]]::new()) } catch { $errors.Add($_.Exception.Message) }
}

foreach ($shaderPath in $resolved.Keys) {
    $macroNames = @([regex]::Matches($resolved[$shaderPath], '(?m)^\s*#define\s+([A-Za-z_]\w*)') | ForEach-Object { $_.Groups[1].Value })
    foreach ($macro in ($macroNames | Group-Object | Where-Object { $_.Count -gt 1 -and $_.Name -notmatch '^ZEPH_(?:PROFILE_BASE|EFFECTIVE)_' })) { $errors.Add("Duplicated preprocessor definition: ${shaderPath}: $($macro.Name)") }
}

foreach ($vertex in $programs | Where-Object Extension -eq '.vsh') {
    $fragmentPath = [System.IO.Path]::ChangeExtension($vertex.FullName, '.fsh')
    if (-not $resolved.ContainsKey($vertex.FullName) -or -not $resolved.ContainsKey($fragmentPath)) { continue }
    foreach ($stage in @($vertex.FullName, $fragmentPath)) {
        if ($resolved[$stage] -notmatch '(?m)\bvoid\s+main\s*\(') { $errors.Add("Missing main entry point: $stage") }
    }
    $vertexVaryings = @([regex]::Matches($resolved[$vertex.FullName], '(?m)^\s*varying\s+([A-Za-z_][\w]*)\s+([A-Za-z_]\w*)\s*;') | ForEach-Object { "$($_.Groups[1].Value) $($_.Groups[2].Value)" } | Sort-Object -Unique)
    $fragmentVaryings = @([regex]::Matches($resolved[$fragmentPath], '(?m)^\s*varying\s+([A-Za-z_][\w]*)\s+([A-Za-z_]\w*)\s*;') | ForEach-Object { "$($_.Groups[1].Value) $($_.Groups[2].Value)" } | Sort-Object -Unique)
    if ((Compare-Object $vertexVaryings $fragmentVaryings)) { $errors.Add("Vertex/fragment varying mismatch: $($vertex.FullName)") }
    if ($resolved[$fragmentPath] -match 'gl_FragData\s*\[\s*[1-9]') { $errors.Add("Unexpected extra colour attachment: $fragmentPath") }
    if ($resolved[$fragmentPath] -notmatch 'gl_FragData\s*\[\s*0\s*\]') { $errors.Add("No main colour output: $fragmentPath") }
    if ($resolved[$fragmentPath] -notmatch '(?s)gl_FragData\s*\[\s*0\s*\]\s*=\s*vec4\s*\(.*?,\s*clamp\s*\(\s*source\.a\s*,\s*0\.0\s*,\s*1\.0\s*\)\s*\)') { $errors.Add("Main colour output must preserve clamped source alpha: $fragmentPath") }
}

foreach ($pattern in @('*.csh','*.gsh','*.tcs','*.tes')) { foreach ($file in Get-ChildItem -LiteralPath $shaderRoot -Recurse -File -Filter $pattern) { $errors.Add("Forbidden high-cost stage: $($file.FullName)") } }
foreach ($file in $programs) { if ($file.BaseName -match '^(?:composite|deferred|shadow)(?:\d+)?$') { $errors.Add("Forbidden render-program family: $($file.FullName)") } }
$settings = Get-Content -LiteralPath (Join-Path $shaderRoot 'lib/settings.glsl') -Raw
$properties = Get-Content -LiteralPath (Join-Path $shaderRoot 'shaders.properties') -Raw
$lang = Get-Content -LiteralPath (Join-Path $shaderRoot 'lang/en_US.lang') -Raw
$readme = Get-Content -LiteralPath (Join-Path $Root 'README.md') -Raw
$changelog = Get-Content -LiteralPath (Join-Path $Root 'CHANGELOG.md') -Raw
foreach ($staleVersion in @('0.1.0-dev','0.2.0-dev')) {
    if ($properties -match [regex]::Escape($staleVersion) -or $readme -match [regex]::Escape($staleVersion) -or $changelog -match [regex]::Escape($staleVersion)) {
        $errors.Add("Stale development version remains in release-facing metadata: $staleVersion")
    }
}
if ($properties -notmatch 'Zepholume 1\.0\.3-dev') { $errors.Add('Shader properties must identify the 1.0.3-dev development line.') }
if ($changelog -notmatch '(?m)^## 1\.0\.3-dev .+unreleased') { $errors.Add('Changelog must contain the unreleased 1.0.3-dev heading.') }
if ($readme -notmatch '(?i)current public release[^\r\n]*V1\.0\.2') { $errors.Add('README must retain V1.0.2 as the current public release until final publication.') }
$definitions = @{}
foreach ($m in [regex]::Matches($settings, '(?m)^#define\s+(ZEPH_[A-Z_]+)\s+(\d+)\s*//\s*\[([^\]]+)\]')) { $definitions[$m.Groups[1].Value] = @($m.Groups[3].Value -split '\s+' | ForEach-Object {[int]$_}) }
$options = @([regex]::Matches($properties, 'ZEPH_[A-Z_]+') | ForEach-Object Value | Sort-Object -Unique)
foreach ($option in $options) {
    if (-not $definitions.ContainsKey($option)) { $errors.Add("Property references undefined or unconstrained option: $option"); continue }
    if ($lang -notmatch "(?m)^option\.$option=") { $errors.Add("Missing language label: $option") }
    if ($lang -notmatch "(?m)^comment\.$option=") { $errors.Add("Missing language tooltip: $option") }
}
foreach ($profile in [regex]::Matches($properties, '(?m)^profile\.([^\s=]+)\s*=\s*(.+)$')) {
    foreach ($assignment in $profile.Groups[2].Value -split '\s+') {
        if ($assignment -notmatch '^(ZEPH_[A-Z_]+):(\d+)$') { $errors.Add("Invalid profile assignment in $($profile.Groups[1].Value): $assignment"); continue }
        $name,$value = $Matches[1],[int]$Matches[2]
        if (-not $definitions.ContainsKey($name)) { $errors.Add("Profile references unknown option: $name"); continue }
        if ($definitions[$name] -notcontains $value) { $errors.Add("Profile value outside declared range: ${name}:$value") }
    }
}
$requiredProfiles = @('Potato','Low','Balanced','High','Ultra')
foreach ($profileName in $requiredProfiles) {
    if ($properties -notmatch "(?m)^profile\.$profileName\s*=") { $errors.Add("Missing required profile: $profileName") }
    if ($lang -notmatch "(?m)^profile\.$profileName=") { $errors.Add("Missing language label for required profile: $profileName") }
}
$profileConfig = Get-Content -LiteralPath (Join-Path $shaderRoot 'lib/profile.glsl') -Raw
$matrix = @{}
foreach ($entry in [regex]::Matches($profileConfig, '(?m)^#define\s+ZEPH_PROFILE_(POTATO|LOW|BALANCED|HIGH|ULTRA)_(TIER|[A-Z_]+)\s+(\d+)\s*$')) {
    $profileName = (Get-Culture).TextInfo.ToTitleCase($entry.Groups[1].Value.ToLowerInvariant())
    $option = if ($entry.Groups[2].Value -eq 'TIER') { 'ZEPH_PROFILE_TIER' } else { 'ZEPH_' + $entry.Groups[2].Value }
    if (-not $matrix.ContainsKey($profileName)) { $matrix[$profileName] = @{} }
    $matrix[$profileName][$option] = [int]$entry.Groups[3].Value
}
foreach ($profileName in $requiredProfiles) {
    if (-not $matrix.ContainsKey($profileName)) { $errors.Add("Profile matrix is missing: $profileName"); continue }
    $propertyMatch = [regex]::Match($properties, "(?m)^profile\.$profileName\s*=\s*(.+)$")
    if (-not $propertyMatch.Success) { continue }
    $actual = @{}
    foreach ($assignment in $propertyMatch.Groups[1].Value -split '\s+') { if ($assignment -match '^(ZEPH_[A-Z_]+):(\d+)$') { $actual[$Matches[1]] = [int]$Matches[2] } }
    if (($actual.Count -ne $matrix[$profileName].Count) -or (Compare-Object ($actual.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" } | Sort-Object) ($matrix[$profileName].GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" } | Sort-Object))) { $errors.Add("Profile does not match authoritative matrix: $profileName") }
}
$aliasMatch = [regex]::Match($properties, '(?m)^profile\.Ultra_Lite\s*=\s*(.+)$')
$lowMatch = [regex]::Match($properties, '(?m)^profile\.Low\s*=\s*(.+)$')
if (-not $aliasMatch.Success -or -not $lowMatch.Success) { $errors.Add('Missing deprecated Ultra Lite compatibility alias or Low profile.') }
elseif ($aliasMatch.Groups[1].Value -ne $lowMatch.Groups[1].Value) { $errors.Add('Deprecated Ultra Lite compatibility alias must map to the Low baseline.') }
$balanced = $matrix['Balanced']
foreach ($option in $definitions.Keys) {
    $defaultMatch = [regex]::Match($settings, "(?m)^#define\s+$option\s+(\d+)\s*//")
    if (-not $defaultMatch.Success) { $errors.Add("Missing numeric source default for profile option: $option"); continue }
    if ($balanced[$option] -ne [int]$defaultMatch.Groups[1].Value) { $errors.Add("Source default must match Balanced profile: $option") }
}
if ($properties -match '(?m)^(?:RENDERTARGETS|DRAWBUFFERS)\s*=.*[1-9]') { $errors.Add('Properties request an extra colour attachment.') }
$invalid = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Name -match '\.(tmp|bak|log)$' -and $_.FullName -notmatch '[\\/](?:dist|artifacts|runtime|tools)[\\/]' }
foreach ($file in $invalid) { $errors.Add("Temporary file would be packaged: $($file.FullName)") }
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Host "Structural validation passed: $($programs.Count) program files checked; includes, entry points, pair interfaces, profiles, and colour-target policy checked."
