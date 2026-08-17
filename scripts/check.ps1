param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
}

function Invoke-Checked {
    param([string]$FilePath, [string[]]$Arguments)
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

Write-Host "`n== BGO structure =="
Invoke-Checked "python" @("scripts/check_structure.py")

if (Get-Command gdformat -ErrorAction SilentlyContinue) {
    Write-Host "`n== GDScript format (advisory during baseline) =="
    & gdformat --check src tests
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "gdformat reported existing formatting debt."
    }
} else {
    Write-Warning 'gdformat not installed. Install with: pip install "gdtoolkit==4.*"'
}

if (Get-Command gdlint -ErrorAction SilentlyContinue) {
    Write-Host "`n== GDScript lint (advisory during baseline) =="
    & gdlint src tests
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "gdlint reported existing lint debt."
    }
} else {
    Write-Warning 'gdlint not installed. Install with: pip install "gdtoolkit==4.*"'
}

Write-Host "`n== Godot import / parse =="
Invoke-Checked $GodotBin @("--headless", "--path", $Root, "--import", "--quit")

Write-Host "`n== Headless domain tests =="
Invoke-Checked $GodotBin @("--headless", "--path", $Root, "--script", "res://tests/test_runner.gd")

Write-Host "`n== Web export smoke test =="
New-Item -ItemType Directory -Force -Path (Join-Path $Root "build/web") | Out-Null
Invoke-Checked $GodotBin @("--headless", "--path", $Root, "--export-release", "Web", (Join-Path $Root "build/web/index.html"))
Invoke-Checked "node" @("scripts/sync_project_status.mjs")

if (-not (Test-Path "build/web/index.html")) { throw "Web export did not create build/web/index.html" }
if (-not (Test-Path "build/web/project-status/index.html")) { throw "Dashboard sync did not create build/web/project-status/index.html" }

Write-Host "`nBGO QUALITY GATE PASSED"
