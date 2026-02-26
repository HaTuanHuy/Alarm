param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$driveLetter = "X:"

$substOutput = cmd /c "subst"
$mappingPattern = "^$([regex]::Escape($driveLetter))\\s+=>\\s+(.+)$"
$currentMapping = ($substOutput | Where-Object { $_ -match "^$([regex]::Escape($driveLetter))\\s+=>" })

if (-not $currentMapping) {
    cmd /c "subst $driveLetter \"$projectPath\"" | Out-Null
} else {
    $mappedPath = ($currentMapping -replace "^$([regex]::Escape($driveLetter))\\s+=>\\s+", "").Trim()
    if ($mappedPath -ne $projectPath) {
        cmd /c "subst $driveLetter /d" | Out-Null
        cmd /c "subst $driveLetter \"$projectPath\"" | Out-Null
    }
}

Push-Location "$driveLetter\\"
try {
    if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
        $FlutterArgs = @("run")
    }

    & flutter @FlutterArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
