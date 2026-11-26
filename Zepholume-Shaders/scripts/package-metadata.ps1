function Get-ZephPackageMetadataBytes([string]$Path) {
    # The V1.0.8 release stores the root license and notice with CRLF.
    # Preserve that archive format independently of the Git checkout OS.
    $text = [IO.File]::ReadAllText($Path) -replace '\r?\n', "`r`n"
    return ,([Text.Encoding]::UTF8.GetBytes($text))
}
