$ErrorActionPreference = "Stop"

$boardDir = $PSScriptRoot
$projectDir = Split-Path -Parent $boardDir
$firmwareBuild = Get-ChildItem -LiteralPath $projectDir -Recurse -File -Filter "build.ps1" |
    Where-Object { $_.FullName -notlike "$boardDir\*" } |
    Select-Object -First 1 -ExpandProperty FullName
$gowinShell = "D:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe"

if (-not $firmwareBuild) {
    throw "Firmware build script was not found under the project directory"
}

& $firmwareBuild
if ($LASTEXITCODE -ne 0) {
    throw "Firmware build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $gowinShell)) {
    throw "Gowin shell not found at $gowinShell"
}

Push-Location $boardDir
try {
    & $gowinShell build.tcl
    if ($LASTEXITCODE -ne 0) {
        throw "Gowin build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
