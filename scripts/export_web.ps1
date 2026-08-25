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
        [string] $FailureMessage,
        [Parameter(Mandatory = $true)]
        [string] $LogPath
    )

    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }

    $process = Start-Process -FilePath $Godot -ArgumentList ($Arguments + @("--log-file", $LogPath)) -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$FailureMessage with exit code $($process.ExitCode)"
    }

    if (Test-Path $LogPath) {
        $parseErrors = Select-String -Path $LogPath -Pattern "SCRIPT ERROR: Parse Error:|Failed to load script"
        if ($parseErrors) {
            $parseErrors | ForEach-Object { Write-Error $_.Line }
            throw "$FailureMessage because Godot logged GDScript parse/load errors"
        }
    }
}

if (Test-Path "build/web") {
    Remove-Item "build/web" -Recurse -Force
}
New-Item "build/web" -ItemType Directory -Force | Out-Null
New-Item "build/logs" -ItemType Directory -Force | Out-Null

Invoke-Godot -Arguments @("--headless", "--path", ".", "--import", "--quit") -FailureMessage "Godot import failed" -LogPath "build/logs/godot-import.log"
Invoke-Godot -Arguments @("--headless", "--path", ".", "--export-release", "Web", "build/web/index.html") -FailureMessage "Godot Web export failed" -LogPath "build/logs/godot-web-export.log"

node scripts/sync_project_status.mjs
if ($LASTEXITCODE -ne 0) { throw "Web auxiliary sync failed with exit code $LASTEXITCODE" }

python scripts/validate_web_export.py
if ($LASTEXITCODE -ne 0) { throw "Web export validation failed with exit code $LASTEXITCODE" }

Write-Host "BGO Web export ready at build/web/index.html"
