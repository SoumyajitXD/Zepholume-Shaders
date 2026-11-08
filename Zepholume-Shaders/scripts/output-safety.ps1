# Shared guard for newly created generated-output directories.
function Assert-ZephFreshOutputPath {
    param([string]$Path, [string]$ProjectRoot, [string]$SourceRoot)
    $location = (Get-Location).ProviderPath
    $full = [IO.Path]::GetFullPath($Path, $location)
    $project = [IO.Path]::GetFullPath($ProjectRoot)
    $source = [IO.Path]::GetFullPath($SourceRoot)
    $artifacts = Join-Path $project 'artifacts'
    function Test-ZephWithin([string]$Child, [string]$Parent) {
        $relative = [IO.Path]::GetRelativePath($Parent, $Child)
        return -not ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.([\\/]|$)')
    }
    if ((Test-ZephWithin $full $source) -or (Test-ZephWithin $source $full) -or
        ((Test-ZephWithin $full $project) -and -not (Test-ZephWithin $full $artifacts)) -or
        (Test-ZephWithin $project $full)) {
        throw "Output path overlaps project source: $full"
    }
    # Resolve every existing ancestor and reject links, including junctions. An
    # output path must not redirect writes into a different tree unexpectedly.
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Output path traverses a link: $cursor" }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    if (Test-Path -LiteralPath $full) { throw "Output path already exists; choose a new path: $full" }
    return $full
}
