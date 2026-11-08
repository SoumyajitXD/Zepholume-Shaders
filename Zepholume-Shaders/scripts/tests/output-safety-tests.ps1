[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$scripts = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) ('zepholume-output-safety-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $sentinel = Join-Path $work 'sentinel.txt'
    [IO.File]::WriteAllText($sentinel, 'preserve')
    foreach ($script in @('generate-compiled-variants.ps1', 'portability-matrix.ps1')) {
        $rejected = $false
        try { & (Join-Path $scripts $script) -OutputRoot $work }
        catch {
            if ($_.Exception.Message -notmatch 'Output path already exists') { throw }
            $rejected = $true
        }
        if (-not $rejected -or [IO.File]::ReadAllText($sentinel) -ne 'preserve') { throw "$script did not safely reject existing output" }
    }
    # The worker is directly callable, so exercise its own guard too.
    $rejected = $false
    try { & (Join-Path $scripts 'portability-matrix.ps1') -Worker -OutputRoot $work }
    catch {
        if ($_.Exception.Message -notmatch 'Output path already exists') { throw }
        $rejected = $true
    }
    if (-not $rejected -or [IO.File]::ReadAllText($sentinel) -ne 'preserve') { throw 'Worker did not safely reject existing output' }
    . (Join-Path $scripts 'output-safety.ps1')
    $project = Split-Path -Parent $scripts
    $source = Join-Path $project 'shaders'
    $rejected = $false
    try { Assert-ZephFreshOutputPath -Path (Join-Path $source 'must-not-be-created') -ProjectRoot $project -SourceRoot $source }
    catch { if ($_.Exception.Message -notmatch 'overlaps project source') { throw }; $rejected = $true }
    if (-not $rejected) { throw 'A destination inside shader source was accepted' }
    $link = Join-Path $work 'source-link'
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $link -Target $source | Out-Null
    $rejected = $false
    try { Assert-ZephFreshOutputPath -Path (Join-Path $link 'must-not-be-created') -ProjectRoot $project -SourceRoot $source }
    catch { if ($_.Exception.Message -notmatch 'traverses a link') { throw }; $rejected = $true }
    if (-not $rejected) { throw 'A linked destination was accepted' }
    [IO.Directory]::Delete($link)
    Push-Location -LiteralPath $source
    try {
        $rejected = $false
        try { Assert-ZephFreshOutputPath -Path 'must-not-be-created' -ProjectRoot $project -SourceRoot $source }
        catch { if ($_.Exception.Message -notmatch 'overlaps project source') { throw }; $rejected = $true }
        if (-not $rejected) { throw 'Relative source destination after Set-Location was accepted' }
    } finally { Pop-Location }
    Push-Location -LiteralPath $work
    try {
        $resolved = Assert-ZephFreshOutputPath -Path 'new-output' -ProjectRoot $project -SourceRoot $source
        if ($resolved -ne (Join-Path $work 'new-output')) { throw 'Relative output did not resolve against PowerShell location' }
    } finally { Pop-Location }
    Write-Host 'Output safety fixtures PASS: existing directories and sentinel contents preserved.'
} finally {
    $resolved = [IO.Path]::GetFullPath($work)
    $relative = [IO.Path]::GetRelativePath([IO.Path]::GetTempPath(), $resolved)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.([\\/]|$)' -or [IO.Path]::GetFileName($resolved) -notlike 'zepholume-output-safety-*') { throw 'Unsafe fixture cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
