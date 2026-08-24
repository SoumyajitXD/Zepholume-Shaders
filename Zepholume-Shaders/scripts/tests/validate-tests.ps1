[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$validator = Join-Path $projectRoot 'scripts/validate.ps1'
$packager = Join-Path $projectRoot 'scripts/package.ps1'
$package = Join-Path $projectRoot 'dist/Zepholume-Shaders-1.0.2.zip'
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-validator-tests-' + [guid]::NewGuid().ToString('N'))
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source

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
    & $Mutation $fixture
    if ((Invoke-Validator $fixture $null) -eq 0) { throw "Expected validator rejection: $Name" }
    Write-Host "Rejected as expected: $Name"
}

try {
    New-Item -ItemType Directory -Path $work | Out-Null
    if (-not (Test-Path -LiteralPath $package)) {
        & $pwsh -NoLogo -NoProfile -File $packager | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Failed to create validator package: $package" }
    }
    Invoke-Valid $projectRoot $package
    Invoke-Invalid 'duplicated-malformed-define' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_skybasic.vsh') -Value "`n#define #ZEPH_BROKEN`n#define #ZEPH_BROKEN" }
    Invoke-Invalid 'missing-main' { param($root) $p=Join-Path $root 'shaders/lib/vertex.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('void main(', 'void not_main(') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'include-cycle' { param($root) $s=Join-Path $root 'shaders'; Set-Content -LiteralPath (Join-Path $s 'zz_cycle_a.glsl') '#include "/zz_cycle_b.glsl"' -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle_b.glsl') '#include "/zz_cycle_a.glsl"' -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle.vsh') "#version 330 compatibility`n#include `"/zz_cycle_a.glsl`"`nvoid main() { gl_Position = vec4(0.0); }" -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'zz_cycle.fsh') "#version 330 compatibility`n#include `"/zz_cycle_a.glsl`"`nvoid main() { gl_FragData[0] = vec4(1.0); }" -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-include' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.vsh') -Value "`n#include `"/does-not-exist.glsl`"" }
    Invoke-Invalid 'varying-mismatch' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.vsh') -Value "`nvarying vec2 zephTest;" }
    Invoke-Invalid 'unknown-profile-option' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/shaders.properties') -Value "`nprofile.Invalid=ZEPH_UNKNOWN:0" }
    Invoke-Invalid 'invalid-option-range' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/shaders.properties') -Value "`nprofile.Invalid=ZEPH_COLOR_GRADE:999" }
    Invoke-Invalid 'missing-required-profile' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw) -replace '(?m)^profile\.High\s*=.*\r?\n', '' | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'profile-matrix-drift' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:1', 'profile.Low = ZEPH_PROFILE_TIER:1 ZEPH_EXPOSURE:2') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'ultra-lite-alias-drift' { param($root) $p=Join-Path $root 'shaders/shaders.properties'; (Get-Content -LiteralPath $p -Raw).Replace('profile.Ultra_Lite = ZEPH_PROFILE_TIER:1', 'profile.Ultra_Lite = ZEPH_PROFILE_TIER:4') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'additional-colour-target' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`ngl_FragData[1] = vec4(0.0);" }
    Invoke-Invalid 'destroyed-output-alpha' { param($root) $p=Join-Path $root 'shaders/lib/fragment.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('clamp(source.a, 0.0, 1.0)', '1.0') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'forbidden-composite-program' { param($root) $s=Join-Path $root 'shaders'; Set-Content -LiteralPath (Join-Path $s 'composite.vsh') '#version 330 compatibility`nvoid main() { gl_Position = vec4(0.0); }' -Encoding utf8NoBOM; Set-Content -LiteralPath (Join-Path $s 'composite.fsh') '#version 330 compatibility`nvoid main() { gl_FragData[0] = vec4(1.0); }' -Encoding utf8NoBOM }
    Invoke-Invalid 'forbidden-extension' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`n#extension GL_ARB_gpu_shader5 : enable" }
    Invoke-Invalid 'post-330-feature' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nvec4 testPost330() { return textureGather(texture, vec2(0.0)); }" }
    Invoke-Invalid 'literal-division-by-zero' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nfloat zephBad = 1.0 / 0.0;" }
    Invoke-Invalid 'undefined-pow' { param($root) Add-Content -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Value "`nfloat zephBad = pow(0.0, 0.0);" }
    Invoke-Invalid 'missing-include-guard' { param($root) $p=Join-Path $root 'shaders/lib/color.glsl'; (Get-Content -LiteralPath $p -Raw).Replace('#ifndef ZEPHO_COLOR_GLSL', '// guard removed') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    Invoke-Invalid 'fog-uniform-after-helper' { param($root) $p=Join-Path $root 'shaders/lib/fragment.glsl'; $s=Get-Content -LiteralPath $p -Raw; $s=$s.Replace('#include "/lib/fog.glsl"', ''); $s=$s.Replace('uniform vec3 fogColor;', "#include `"/lib/fog.glsl`"`nuniform vec3 fogColor;"); Set-Content -LiteralPath $p -Value $s -Encoding utf8NoBOM }
    Invoke-Invalid 'missing-shader-pair' { param($root) Remove-Item -LiteralPath (Join-Path $root 'shaders/gbuffers_basic.fsh') -Force }
    Invoke-Invalid 'stale-release-metadata' { param($root) $p=Join-Path $root 'README.md'; (Get-Content -LiteralPath $p -Raw).Replace('V1.0.2', '0.2.0-dev') | Set-Content -LiteralPath $p -Encoding utf8NoBOM }
    $badZip = Join-Path $work 'backslash-paths.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($badZip, [IO.Compression.ZipArchiveMode]::Create)
    try { $zip.CreateEntry('shaders\\shaders.properties') | Out-Null } finally { $zip.Dispose() }
    if ((Invoke-Validator $projectRoot $badZip) -eq 0) { throw 'Expected validator rejection: backslash ZIP paths' }
    Write-Host 'Rejected as expected: backslash ZIP paths'
    $duplicateZip = Join-Path $work 'duplicate-entry.zip'
    $zip = [IO.Compression.ZipFile]::Open($duplicateZip, [IO.Compression.ZipArchiveMode]::Create)
    try { $zip.CreateEntry('shaders/shaders.properties') | Out-Null; $zip.CreateEntry('shaders/shaders.properties') | Out-Null } finally { $zip.Dispose() }
    if ((Invoke-Validator $projectRoot $duplicateZip) -eq 0) { throw 'Expected validator rejection: duplicate ZIP entry' }
    Write-Host 'Rejected as expected: duplicate ZIP entry'
    Write-Host 'Validator regression tests passed.'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
