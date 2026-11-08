[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$validator = Join-Path $projectRoot 'scripts/validate.ps1'
$packager = Join-Path $projectRoot 'scripts/package.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-validator-tests-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $work 'Zepholume-Shaders-validator-fixture.zip'
$pwsh = (Get-Process -Id $PID).Path
$rejectedFixtures = 0

function Invoke-Validator([string]$Root, [string]$PackagePath) {
    $args = @('-NoLogo','-NoProfile','-File',$validator,'-Root',$Root)
    if ($PackagePath) { $args += @('-Package',$PackagePath) }
    & $pwsh @args | Out-Host
    return $LASTEXITCODE
}

function Invoke-Valid([string]$Root, [string]$PackagePath) {
    if ((Invoke-Validator $Root $PackagePath) -ne 0) { throw "Expected validation to pass: $Root" }
}
function Invoke-Invalid([string]$Name, [scriptblock]$Mutation) {
    $fixture = Join-Path $work $Name
    New-Item -ItemType Directory -Path $fixture | Out-Null
    # Copy only validator inputs. Copying generated variant/portability trees
    # for every negative fixture made the regression suite I/O-bound.
    foreach ($item in @('shaders','docs','README.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $item) -Destination $fixture -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts') | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts/sync-dimension-wrappers.ps1') -Destination (Join-Path $fixture 'scripts/sync-dimension-wrappers.ps1') -Force
    & $Mutation $fixture
    # Keep derived wrappers consistent when a root program is intentionally
    # mutated, so wrapper drift cannot mask the rule under test.
    $isolatedRules = @{
        'duplicated-malformed-define' = 'Malformed preprocessor definition'
        'include-cycle' = 'Include cycle:'
        'missing-include' = 'Unresolved include:'
        'varying-mismatch' = 'Vertex/fragment varying mismatch'
        'additional-colour-target' = 'Unexpected extra colour attachment'
        'unlit-lightmap-routing' = 'must not declare ZEPH_LIGHTMAP_LIT_PROGRAM'
        'missing-lit-lightmap-routing' = 'must declare ZEPH_LIGHTMAP_LIT_PROGRAM'
        'late-lightmap-routing' = 'must precede'
        'forbidden-composite-program' = 'Forbidden render-program family'
        'forbidden-extension' = 'Extensions are not permitted'
        'post-330-feature' = 'Post-GLSL-330 feature'
        'literal-division-by-zero' = 'Literal division by zero'
        'undefined-pow' = 'Undefined pow(0,0)'
        'missing-shader-pair' = 'Missing program pair'
        'non-flat-water-classification' = 'Water material classification must use flat interpolation'
        'invalid-option-range' = 'Profile value outside declared range'
    }
    if ($Name -eq 'missing-shader-pair') {
        foreach ($dimension in @('world0','world-1','world1')) { Remove-Item -LiteralPath (Join-Path $fixture "shaders/$dimension/gbuffers_basic.fsh") }
    }
    if ($isolatedRules.ContainsKey($Name)) {
        & $pwsh -NoLogo -NoProfile -File (Join-Path $fixture 'scripts/sync-dimension-wrappers.ps1') -Root $fixture | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Wrapper synchronization failed: $Name" }
        $capture = Join-Path $work "$Name-output.txt"
        & $pwsh -NoLogo -NoProfile -File $validator -Root $fixture *> $capture
        $code = $LASTEXITCODE
        $output = Get-Content -LiteralPath $capture -Raw
        if ($code -eq 0 -or -not $output.Contains($isolatedRules[$Name])) { throw "Expected '$($isolatedRules[$Name])' rejection for $Name; exit=$code; output=$output" }
        if ($output -match 'Dimension wrapper (differs|topology)') { throw "Unrelated wrapper failure masked $Name" }
        Write-Host "Isolated rejection: $Name; expected and actual: $($isolatedRules[$Name]); wrapper checks passed."
    } else {
        if ((Invoke-Validator $fixture $null) -eq 0) { throw "Expected validator rejection: $Name" }
        Write-Host "Rejected as expected: $Name"
    }
    $script:rejectedFixtures++
}

try {
    New-Item -ItemType Directory -Path $work | Out-Null
    & $pwsh -NoLogo -NoProfile -File $packager -OutputName 'Zepholume-Shaders-validator-fixture.zip' -OutputDirectory $work | Out-Host
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $package)) { throw "Failed to create validator package: $package" }
    & $pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'math-regression.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Mathematical regression tests failed.' }
    & $pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'profile-config-tests.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Profile configuration tests failed.' }
    & $pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'water-specular-gating-equivalence.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Water specular gating equivalence tests failed.' }
    Invoke-Valid $projectRoot $package
    $stalePackage = Join-Path $projectRoot 'dist/Zepholume-Shaders-1.0.4.zip'
    if (Test-Path -LiteralPath $stalePackage) {
        if ((Invoke-Validator $projectRoot $stalePackage) -eq 0) { throw 'Expected the preserved V1.0.4 ZIP to fail exact current-source validation.' }
        $rejectedFixtures++
        Write-Host 'Rejected as expected: stale V1.0.4 package bytes'
    } else { Write-Host 'SKIP: optional preserved V1.0.4 package is unavailable; no rejection claimed.' }
    Invoke-Invalid 'duplicated-malformed-define' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_skybasic.vsh') -Value "`n#define #ZEPH_BROKEN`n#define #ZEPH_BROKEN" }
    Invoke-Invalid 'missing-main' { param($root) $p=Join-Path $root 'shaders/lib/vertex.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('void main(', 'void not_main(') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'include-cycle' { param($root) $s=Join-Path $root 'shaders'; Set-Content -LiteralPath (Join-Path $s 'zz_cycle_a.glsl') '#include "/zz_cycle_b.glsl"' -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle_b.glsl') '#include "/zz_cycle_a.glsl"' -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle.vsh') "#version 330 compatibility`n#include `"/zz_cycle_a.glsl`"`nvoid main() { gl_Position = vec4(0.0); }" -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle.fsh') "#version 330 compatibility`n#include `"/zz_cycle_a.glsl`"`nvoid main() { gl_FragData[0] = vec4(1.0); }" -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-include' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.vsh') -Value "`n#include `"/does-not-exist.glsl`"" }
    Invoke-Invalid 'varying-mismatch' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.vsh') -Value "`nvarying vec2 zephTest;" }
    Invoke-Invalid 'unknown-profile-option' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/shaders.properties') -Value "`nprofile.Invalid=ZEPH_UNKNOWN:0" }
    Invoke-Invalid 'invalid-option-range' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:1', 'profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:999') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-required-profile' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw) -replace '(?m)^profile\.High\s*=.*\r?\n', '' | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'profile-matrix-drift' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:1', 'profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:2') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'obsolete-extra-profile' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/shaders.properties') -Value 'profile.Ultra_Lite = ZEPH_PROFILE_TIER:1' }
    Invoke-Invalid 'duplicate-profile' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/shaders.properties') -Value 'profile.Low = ZEPH_PROFILE_TIER:1' }
    Invoke-Invalid 'missing-profile-control' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('screen = <profile> <empty>', 'screen = <empty> <empty>') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'additional-colour-target' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`ngl_FragData[1] = vec4(0.0);" }
    Invoke-Invalid 'destroyed-output-alpha' { param($root) $p=Join-Path $root 'shaders/lib/fragment.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('clamp(source.a, 0.0, 1.0)', '1.0') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-lightmap-irradiance' { param($root) $p=Join-Path $root 'shaders/lib/fragment.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('source.rgb *= texture2D(lightmap, zephLightCoord).rgb;', '// lightmap application removed') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'unlit-lightmap-routing' { param($root) $p=Join-Path $root 'shaders/gbuffers_textured.fsh'; (Get-Content -LiteralPath $p -Raw).Replace('#include "/lib/fragment.glsl"', "#define ZEPH_LIGHTMAP_LIT_PROGRAM`n#include `"/lib/fragment.glsl`"") | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-lit-lightmap-routing' { param($root) $p=Join-Path $root 'shaders/gbuffers_terrain.fsh'; (Get-Content -LiteralPath $p -Raw).Replace('#define ZEPH_LIGHTMAP_LIT_PROGRAM', '// lightmap marker removed') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-hand-lightmap-routing' { param($root) foreach ($dimension in @('','world0','world-1','world1')) { $p=Join-Path $root "shaders/$dimension/gbuffers_hand.fsh"; (Get-Content -LiteralPath $p -Raw).Replace('#define ZEPH_LIGHTMAP_LIT_PROGRAM', '// lightmap marker removed') | Set-Content -LiteralPath $p -Encoding utf8NoBOM } }
    Invoke-Invalid 'late-lightmap-routing' { param($root) $p=Join-Path $root 'shaders/gbuffers_terrain.fsh'; (Get-Content -LiteralPath $p -Raw).Replace('#define ZEPH_LIGHTMAP_LIT_PROGRAM', '').Replace('#include "/lib/fragment.glsl"', "#include `"/lib/fragment.glsl`"`n#define ZEPH_LIGHTMAP_LIT_PROGRAM") | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'forbidden-composite-program' { param($root) $s=Join-Path $root 'shaders'; Copy-Item -LiteralPath (Join-Path $s 'gbuffers_basic.vsh') -Destination (Join-Path $s 'composite.vsh'); Copy-Item -LiteralPath (Join-Path $s 'gbuffers_basic.fsh') -Destination (Join-Path $s 'composite.fsh') }
    Invoke-Invalid 'forbidden-extension' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`n#extension GL_ARB_gpu_shader5 : enable" }
    Invoke-Invalid 'post-330-feature' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nvec4 testPost330() { return textureGather(texture, vec2(0.0)); }" }
    Invoke-Invalid 'literal-division-by-zero' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nfloat zephBad = 1.0 / 0.0;" }
    Invoke-Invalid 'undefined-pow' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nfloat zephBad = pow(0.0, 0.0);" }
    Invoke-Invalid 'missing-include-guard' { param($root) $p=Join-Path $root 'shaders/lib/color.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('#ifndef ZEPHO_COLOR_GLSL', '// guard removed') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'fog-uniform-after-helper' { param($root) $p=Join-Path $root 'shaders/lib/fragment.glsl'; $s=Get-Content -LiteralPath $p -Raw; $s=$s.Replace('#include "/lib/fog.glsl"', ''); $s=$s.Replace('uniform vec3 fogColor;', "#include `"/lib/fog.glsl`"`nuniform vec3 fogColor;"); Set-Content -LiteralPath $p -Value $s -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-shader-pair' { param($root) Remove-Item -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Force }
    Invoke-Invalid 'missing-dimension-wrapper' { param($root) Remove-Item -LiteralPath (Join-Path $root 'shaders/world1/gbuffers_basic.fsh') -Force }
    Invoke-Invalid 'corrupted-dimension-wrapper' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/world-1/gbuffers_basic.vsh') -Value "`n// fixture wrapper drift" }
    Invoke-Invalid 'non-water-material-mapping' { param($root) $p=Join-Path $root 'shaders/block.properties'; (Get-Content -LiteralPath $p -Raw).Replace('block.10001=minecraft:water', 'block.10001=minecraft:water minecraft:glass') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'non-flat-water-classification' { param($root) foreach ($file in @('vertex.glsl','fragment.glsl')) { $p=Join-Path $root "shaders/lib/$file"; (Get-Content -LiteralPath $p -Raw).Replace('flat varying float zephIsWater;', 'varying float zephIsWater;') | Set-Content -LiteralPath $p -Encoding utf8NoBOM } }
    Invoke-Invalid 'stale-release-metadata' { param($root) $p=Join-Path $root 'README.md'; (Get-Content -LiteralPath $p -Raw).Replace('V1.0.7 Phase 1 development', '0.2.0-dev') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'final-release-identification' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('Zepholume 1.0.7 Phase 1 development', 'Zepholume 1.0.7 final release') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-development-heading' { param($root) $p=Join-Path $root 'CHANGELOG.md'; (Get-Content -LiteralPath $p -Raw) -replace '(?m)^## 1\.0\.7-dev-phase1[^\r\n]*', '## candidate' | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    $badZip = Join-Path $work 'backslash-paths.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($badZip, [IO.Compression.ZipArchiveMode]::Create)
    try { $zip.CreateEntry('shaders\\shaders.properties') | Out-Null } finally { $zip.Dispose() }
    if ((Invoke-Validator $projectRoot $badZip) -eq 0) { throw 'Expected validator rejection: backslash ZIP paths' }
    $rejectedFixtures++
    Write-Host 'Rejected as expected: backslash ZIP paths'
    $duplicateZip = Join-Path $work 'duplicate-entry.zip'
    $zip = [IO.Compression.ZipFile]::Open($duplicateZip, [IO.Compression.ZipArchiveMode]::Create)
    try { $zip.CreateEntry('shaders/shaders.properties') | Out-Null; $zip.CreateEntry('shaders/shaders.properties') | Out-Null } finally { $zip.Dispose() }
    if ((Invoke-Validator $projectRoot $duplicateZip) -eq 0) { throw 'Expected validator rejection: duplicate ZIP entry' }
    $rejectedFixtures++
    Write-Host 'Rejected as expected: duplicate ZIP entry'
    $wrongCaseZip = Join-Path $work 'wrong-case-entry.zip'
    $sourceZip = [IO.Compression.ZipFile]::OpenRead($package)
    $caseZip = [IO.Compression.ZipFile]::Open($wrongCaseZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($sourceEntry in $sourceZip.Entries) {
            $name = if ($sourceEntry.FullName -ceq 'shaders/shaders.properties') { 'shaders/Shaders.properties' } else { $sourceEntry.FullName }
            $targetEntry = $caseZip.CreateEntry($name)
            $input = $sourceEntry.Open(); $output = $targetEntry.Open()
            try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
        }
    } finally { $caseZip.Dispose(); $sourceZip.Dispose() }
    if ((Invoke-Validator $projectRoot $wrongCaseZip) -eq 0) { throw 'Expected validator rejection: wrong-case ZIP entry' }
    $rejectedFixtures++
    Write-Host 'Rejected as expected: wrong-case ZIP entry'
    Write-Host "Validator regression tests passed: $rejectedFixtures invalid fixtures rejected."
    exit 0
} finally {
    $resolved = [IO.Path]::GetFullPath($work)
    $relative = [IO.Path]::GetRelativePath([IO.Path]::GetTempPath(), $resolved)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.([\\/]|$)' -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-validator-tests-*') { throw 'Unsafe fixture cleanup target.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
