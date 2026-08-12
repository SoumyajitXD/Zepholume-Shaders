function Get-ZephShaderOptions {
    param([Parameter(Mandatory)][string]$ShaderRoot)

    $settingsPath = Join-Path $ShaderRoot 'lib/settings.glsl'
    $settings = Get-Content -LiteralPath $settingsPath -Raw
    $options = [ordered]@{}
    foreach ($match in [regex]::Matches($settings, '(?m)^#define\s+(ZEPH_[A-Z_]+)\s+(\d+)\s*//\s*\[([^\]]+)\]')) {
        $options[$match.Groups[1].Value] = @($match.Groups[3].Value -split '\s+' | ForEach-Object { [int]$_ })
    }
    return $options
}

function Get-ZephProfiles {
    param(
        [Parameter(Mandatory)][string]$ShaderRoot,
        [System.Collections.IDictionary]$Options = (Get-ZephShaderOptions -ShaderRoot $ShaderRoot)
    )

    $propertiesPath = Join-Path $ShaderRoot 'shaders.properties'
    $profiles = [System.Collections.Generic.List[object]]::new()
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $propertiesPath -Raw), '(?m)^profile\.([^\s=]+)\s*=\s*(.+)$')) {
        $values = [ordered]@{}
        foreach ($assignment in $match.Groups[2].Value -split '\s+') {
            if ($assignment -notmatch '^(ZEPH_[A-Z_]+):(\d+)$') { throw "Invalid profile assignment in $($match.Groups[1].Value): $assignment" }
            $option = $Matches[1]
            $value = [int]$Matches[2]
            if (-not $Options.Contains($option)) { throw "Profile references undefined option: $option" }
            if ($Options[$option] -notcontains $value) { throw "Profile value outside declared range: ${option}:$value" }
            if ($values.Contains($option)) { throw "Profile assigns an option more than once: $($match.Groups[1].Value): $option" }
            $values[$option] = $value
        }
        $profiles.Add([pscustomobject]@{ Name=$match.Groups[1].Value; Values=$values })
    }
    if ($profiles.Count -eq 0) { throw "No profiles found: $propertiesPath" }
    return $profiles
}
