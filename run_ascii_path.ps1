param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$projectPath = (Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$driveLetter = "X:"

$substOutput = subst
$currentMapping = $substOutput | Where-Object { $_ -match "^$([regex]::Escape($driveLetter))\\\\:\s+=>\s+" }

if (-not $currentMapping) {
    subst $driveLetter "$projectPath" | Out-Null
} else {
    $mappedPath = ($currentMapping -replace "^$([regex]::Escape($driveLetter))\\\\:\s+=>\s+", "").Trim()
    if ($mappedPath -ne $projectPath) {
        subst $driveLetter /d | Out-Null
        subst $driveLetter "$projectPath" | Out-Null
    }
}

Push-Location "$driveLetter\"
try {
    if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
        $FlutterArgs = @("run")
    }

    if ($PSBoundParameters.ContainsKey("Debug")) {
        Write-Warning "PowerShell consumed '-d' as '-Debug'. Use: .\\run_ascii_path.ps1 --% <flutter args>"
    }

    & flutter @FlutterArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
