function Resolve-ZephValidatorBackend {
    param([ValidateSet('Native','WSL','CI')][string]$ValidatorMode = 'Native', [string]$Validator = '', [string]$WslDistribution = 'kali-linux')
    if ($ValidatorMode -eq 'WSL') {
        $wsl = Join-Path $env:SystemRoot 'System32\wsl.exe'
        if (-not (Test-Path -LiteralPath $wsl -PathType Leaf)) { throw 'BLOCKED: WSL execution backend is unavailable.' }
        $version = & $wsl -d $WslDistribution -- glslangValidator --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "BLOCKED: WSL distribution '$WslDistribution' cannot run glslangValidator." }
        return [pscustomobject]@{ Mode='WSL'; Command=$wsl; WslDistribution=$WslDistribution; Version=$version.Trim() }
    }
    if ($ValidatorMode -eq 'CI' -and -not $IsLinux) { throw 'BLOCKED: CI validator mode requires a Linux runner.' }
    if (-not $Validator) { if ($ValidatorMode -eq 'Native') { throw 'BLOCKED: Native validator mode requires an explicit trusted -Validator.' }; $Validator = 'glslangValidator' }
    if (Test-Path -LiteralPath $Validator -PathType Leaf) { $command = (Resolve-Path -LiteralPath $Validator).Path } else { $command = (Get-Command -Name $Validator -CommandType Application -ErrorAction Stop).Source }
    $version = & $command --version 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "BLOCKED: Selected validator '$Validator' did not return a version." }
    return [pscustomobject]@{ Mode=$ValidatorMode; Command=$command; WslDistribution=$null; Version=$version.Trim() }
}

function ConvertTo-ZephWslPath([string]$Path) {
    if ($Path -notmatch '^(?<drive>[A-Za-z]):\\(?<tail>.*)$') { return $Path }
    return ('/mnt/' + $Matches.drive.ToLowerInvariant() + '/' + ($Matches.tail -replace '\\','/'))
}

function Invoke-ZephValidatorBackend {
    param([object]$Backend, [string[]]$Arguments)
    if ($Backend.Mode -eq 'WSL') { return (& $Backend.Command -d $Backend.WslDistribution -- glslangValidator @($Arguments | ForEach-Object { ConvertTo-ZephWslPath $_ }) 2>&1 | Out-String) }
    return (& $Backend.Command @Arguments 2>&1 | Out-String)
}
