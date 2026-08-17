param(
    [string]$Source = "web/project-status",
    [string]$Destination = "build/web/project-status"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot $Source
$destinationPath = Join-Path $repoRoot $Destination

if (-not (Test-Path $sourcePath)) {
    throw "Project status source directory not found: $sourcePath"
}

if (-not (Test-Path (Join-Path $repoRoot "build/web"))) {
    New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot "build/web") | Out-Null
}

if (Test-Path $destinationPath) {
    Remove-Item -Recurse -Force $destinationPath
}

New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null
Copy-Item -Path (Join-Path $sourcePath "*") -Destination $destinationPath -Recurse -Force

Write-Host "Project status dashboard synced to $destinationPath"
Write-Host "Firebase path after deploy: /project-status/"
