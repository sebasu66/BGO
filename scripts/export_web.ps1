$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Godot = if ($env:GODOT_BIN) {
    $env:GODOT_BIN
} elseif (Test-Path "./godot") {
    "./godot"
} elseif (Test-Path "./godot.exe") {
    "./godot.exe"
} else {
    "godot"
}

Write-Host "Using Godot CLI: $Godot"

function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,
        [Parameter(Mandatory = $true)]
        [string] $FailureMessage
    )

    # Godot's normal Windows executable is a GUI subsystem process. In an
    # interactive PowerShell session, invoking it directly can return control
    # before the export process has actually finished. Start-Process -Wait makes
    # the build pipeline deterministic regardless of whether godot.exe or the
    # console wrapper is used.
    $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$FailureMessage with exit code $($process.ExitCode)"
    }
}

if (Test-Path "build/web") {
    Remove-Item "build/web" -Recurse -Force
}
New-Item "build/web" -ItemType Directory -Force | Out-Null

Invoke-Godot -Arguments @("--headless", "--path", ".", "--import", "--quit") -FailureMessage "Godot import failed"
Invoke-Godot -Arguments @("--headless", "--path", ".", "--export-release", "Web", "build/web/index.html") -FailureMessage "Godot Web export failed"

node scripts/sync_project_status.mjs
if ($LASTEXITCODE -ne 0) { throw "Web auxiliary sync failed with exit code $LASTEXITCODE" }

python scripts/validate_web_export.py
if ($LASTEXITCODE -ne 0) { throw "Web export validation failed with exit code $LASTEXITCODE" }

Write-Host "BGO Web export ready at build/web/index.html"
