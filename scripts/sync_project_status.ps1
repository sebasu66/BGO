param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $repoRoot "build/web"

$staticRoutes = @(
    @{
        Name = "Project status dashboard"
        Source = Join-Path $repoRoot "web/project-status"
        Destination = Join-Path $buildRoot "project-status"
        Route = "/project-status/"
    },
    @{
        Name = "BGO test launcher"
        Source = Join-Path $repoRoot "web/test-launcher"
        Destination = Join-Path $buildRoot "test-launcher"
        Route = "/test-launcher/"
    },
    @{
        Name = "BGO user manual"
        Source = Join-Path $repoRoot "web/help"
        Destination = Join-Path $buildRoot "help"
        Route = "/help/"
    }
)

if (-not (Test-Path $buildRoot)) {
    New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
}

foreach ($item in $staticRoutes) {
    if (-not (Test-Path $item.Source)) {
        throw "$($item.Name) source directory not found: $($item.Source)"
    }

    if (Test-Path $item.Destination) {
        Remove-Item -Recurse -Force $item.Destination
    }

    New-Item -ItemType Directory -Force -Path $item.Destination | Out-Null
    Copy-Item -Path (Join-Path $item.Source "*") -Destination $item.Destination -Recurse -Force

    Write-Host "$($item.Name) synced to $($item.Destination)"
    Write-Host "Firebase path after deploy: $($item.Route)"
}
