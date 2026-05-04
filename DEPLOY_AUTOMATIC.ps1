# Automatic Deployment Script for Gemma 4 Health & Education Features
# Run this from PowerShell in the workspace directory

$ErrorActionPreference = "Stop"
$workspaceBase = Get-Location
$targetBase = "C:\Users\ankit\Projects\Android\CyborgAI-main"

Write-Host "🚀 Deploying Gemma 4 Health & Education Features..." -ForegroundColor Cyan
Write-Host ""

# 1. Deploy Backend Services
Write-Host "📦 Step 1: Deploying backend services..." -ForegroundColor Yellow

$healthSrc = "$workspaceBase\assets\backend\services\health"
$eduSrc = "$workspaceBase\assets\backend\services\education"
$healthDest = "$targetBase\assets\backend\services\health"
$eduDest = "$targetBase\assets\backend\services\education"

New-Item -ItemType Directory -Force -Path $healthDest | Out-Null
New-Item -ItemType Directory -Force -Path $eduDest | Out-Null

Copy-Item "$healthSrc\*" -Destination $healthDest -Force
Copy-Item "$eduSrc\*" -Destination $eduDest -Force

Write-Host "  ✅ Health services deployed to: $healthDest" -ForegroundColor Green
Write-Host "  ✅ Education services deployed to: $eduDest" -ForegroundColor Green

# 2. Deploy API Routes
Write-Host ""
Write-Host "📦 Step 2: Deploying API routes..." -ForegroundColor Yellow

$routeSrc = "$workspaceBase\assets\backend\api\routes\health_edu.py"
$routeDest = "$targetBase\assets\backend\api\routes\health_edu.py"

Copy-Item $routeSrc -Destination $routeDest -Force
Write-Host "  ✅ API routes deployed to: $routeDest" -ForegroundColor Green

# 3. Update main.py
Write-Host ""
Write-Host "📦 Step 3: Updating backend main.py..." -ForegroundColor Yellow

$mainDest = "$targetBase\assets\backend\main.py"
$mainContent = Get-Content $mainDest -Raw

# Add health_edu import if not present
if ($mainContent -notmatch "health_edu") {
    $mainContent = $mainContent -replace "(from api\.routes import \([^)]*)(voice,)", '$1`n    health_edu as health_edu_router,`n    $2'

    # Add router registration
    if ($mainContent -notmatch "health_edu_router\.router") {
        $mainContent = $mainContent -replace '(app\.include_router\(voice\.router,[^)]+\))', '$1`n    app.include_router(health_edu_router.router,   prefix="/api/v1",              tags=["Health & Education"])'
    }

    Set-Content -Path $mainDest -Value $mainContent
    Write-Host "  ✅ main.py updated with health_edu routes" -ForegroundColor Green
} else {
    Write-Host "  ℹ️  main.py already contains health_edu routes" -ForegroundColor Gray
}

# 4. Deploy Frontend Files
Write-Host ""
Write-Host "📱 Step 4: Deploying frontend UI updates..." -ForegroundColor Yellow

$winHomeSrc = "$workspaceBase\lib\screens\windows\home_screen.dart"
$androidHomeSrc = "$workspaceBase\lib\screens\android\home_screen.dart"
$winHomeDest = "$targetBase\lib\screens\windows\home_screen.dart"
$androidHomeDest = "$targetBase\lib\screens\android\home_screen.dart"

Copy-Item $winHomeSrc -Destination $winHomeDest -Force
Copy-Item $androidHomeSrc -Destination $androidHomeDest -Force

Write-Host "  ✅ Windows home screen updated: $winHomeDest" -ForegroundColor Green
Write-Host "  ✅ Android home screen updated: $androidHomeDest" -ForegroundColor Green

# 5. Summary
Write-Host ""
Write-Host "✅ DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your Flutter app: flutter run -d windows" -ForegroundColor White
Write-Host "2. The backend will auto-reload with new health/education endpoints" -ForegroundColor White
Write-Host "3. You'll see new Health & Education options in the sidebar/chips" -ForegroundColor White
Write-Host ""
Write-Host "New API endpoints available at:" -ForegroundColor Cyan
Write-Host "  - GET  /api/v1/health/status" -ForegroundColor White
Write-Host "  - POST /api/v1/health/analyze-xray" -ForegroundColor White
Write-Host "  - POST /api/v1/health/ehr/query" -ForegroundColor White
Write-Host "  - GET  /api/v1/education/status" -ForegroundColor White
Write-Host "  - POST /api/v1/education/grade-homework" -ForegroundColor White
Write-Host "  - POST /api/v1/education/generate-quiz" -ForegroundColor White
Write-Host ""
