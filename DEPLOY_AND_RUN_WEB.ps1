# Cyborg AGI: Unified Web Deploy & Launch Script
# This builds the Flutter web UI, deploys it to the FastAPI backend, and starts the unified server.

$ErrorActionPreference = "Stop"
$projectRoot = Get-Location

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "   🛸 Cyborg AGI: Unified Web Deployment & Server 🛸" -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host ""

# 1. Build Flutter Web
Write-Host "[1/3] Compiling Flutter Web in Release Mode..." -ForegroundColor Yellow
try {
    & flutter build web --release --no-wasm-dry-run
    Write-Host "      ✓ Flutter web compiled successfully!" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to compile Flutter Web. Make sure Flutter is installed and active." -ForegroundColor Red
    exit 1
}
Write-Host ""

# 2. Deploy Web Build to Backend Static Directory
Write-Host "[2/3] Deploying Web UI build to Backend static directory..." -ForegroundColor Yellow
$staticDir = Join-Path $projectRoot "assets\backend\static"

try {
    if (Test-Path $staticDir) {
        Remove-Item -Path $staticDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $staticDir -Force | Out-Null
    
    $buildWebPath = Join-Path $projectRoot "build\web\*"
    Copy-Item -Path $buildWebPath -Destination $staticDir -Recurse -Force
    Write-Host "      ✓ Static assets copied to: assets\backend\static" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to deploy UI assets to backend: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 3. Boot Unified Server
Write-Host "[3/3] Launching Unified AGI Web & Backend Server..." -ForegroundColor Yellow
$backendPath = Join-Path $projectRoot "assets\backend"
Set-Location $backendPath

$venvPython = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "      ⚠ Local .venv not found. Bootstrapping dependencies via setup_env.py..." -ForegroundColor Cyan
    & python setup_env.py
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  🛸 Cyborg AGI is now serving at: http://localhost:8765" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop the unified service at any time." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""

& $venvPython main.py
