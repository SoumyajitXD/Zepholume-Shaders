function Get-ZephShaderOptions {
    param([Parameter(Mandatory)][string]$ShaderRoot)

    $settingsPath = Join-Path $ShaderRoot 'lib/settings.glsl'
    $settings = Get-Content -LiteralPath $settingsPath -Raw
    $options = [ordered]@{}
    foreach ($match in [regex]::Matches($settings, '(?m)^#define\s+(ZEPH_[A-Z_]+)\s+(\d+)\s*//\s*\[([^\]]+)\]')) {
        $name = $match.Groups[1].Value
        if ($options.Contains($name)) { throw "Duplicate shader option definition: $name" }
        $values = @($match.Groups[3].Value.Trim() -split '\s+' | ForEach-Object { [int]$_ })
        if ($values.Count -ne @($values | Select-Object -Unique).Count) { throw "Duplicate shader option value: $name" }
        if ($values -notcontains [int]$match.Groups[2].Value) { throw "Shader option default outside declared range: $name" }
        $options[$name] = $values
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($match in [regex]::Matches($settings, '(?m)^#define\s+(ZEPH_[A-Z_]+)\b')) {
        $name = $match.Groups[1].Value
        if (-not $seen.Add($name)) { throw "Duplicate shader option definition: $name" }
        if (-not $options.Contains($name)) { throw "Shader option lacks a valid numeric range: $name" }
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
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $propertiesPath -Raw), '(?m)^profile\.([^\s=]+)\s*=\s*([^\r\n]*)')) {
        if (-not $names.Add($match.Groups[1].Value)) { throw "Duplicate profile definition: $($match.Groups[1].Value)" }
        $values = [ordered]@{}
        foreach ($assignment in $match.Groups[2].Value.Trim() -split '\s+') {
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
