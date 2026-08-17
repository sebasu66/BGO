$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }

if (Test-Path "build/web") {
    Remove-Item "build/web" -Recurse -Force
}
New-Item "build/web" -ItemType Directory -Force | Out-Null

& $Godot --headless --path . --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE" }

& $Godot --headless --path . --export-release Web build/web/index.html
if ($LASTEXITCODE -ne 0) { throw "Godot Web export failed with exit code $LASTEXITCODE" }

node scripts/sync_project_status.mjs
if ($LASTEXITCODE -ne 0) { throw "Web auxiliary sync failed with exit code $LASTEXITCODE" }

python scripts/validate_web_export.py
if ($LASTEXITCODE -ne 0) { throw "Web export validation failed with exit code $LASTEXITCODE" }

Write-Host "BGO Web export ready at build/web/index.html"
