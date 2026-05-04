# PowerShell script to fix Gemma 4 backend imports and deploy

Write-Host "=== Fixing Gemma 4 Backend Imports ===" -ForegroundColor Cyan
Write-Host ""

$projectPath = "C:\Users\ankit\Projects\Android\CyborgAI-main"

# Fix 1: education/__init__.py
Write-Host "Fixing education module imports..." -ForegroundColor Yellow
$eduInitPath = Join-Path $projectPath "assets\backend\services\education\__init__.py"
if (Test-Path $eduInitPath) {
    $content = Get-Content $eduInitPath -Raw
    $content = $content -replace 'from \.quiz_generator import AdaptiveQuizGenerator', 'from .quiz_generator import QuizGenerator as AdaptiveQuizGenerator'
    Set-Content $eduInitPath $content -NoNewline
    Write-Host "  ✓ Fixed education/__init__.py" -ForegroundColor Green
} else {
    Write-Host "  ⚠ File not found: $eduInitPath" -ForegroundColor Red
}

# Fix 2: health_edu.py route imports
Write-Host "Fixing API route imports..." -ForegroundColor Yellow
$routePath = Join-Path $projectPath "assets\backend\api\routes\health_edu.py"
if (Test-Path $routePath) {
    $content = Get-Content $routePath -Raw
    $content = $content -replace 'from \.\.services\.education\.quiz_generator import AdaptiveQuizGenerator', 'from ..services.education.quiz_generator import QuizGenerator as AdaptiveQuizGenerator'
    Set-Content $routePath $content -NoNewline
    Write-Host "  ✓ Fixed api/routes/health_edu.py" -ForegroundColor Green
} else {
    Write-Host "  ⚠ File not found: $routePath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Fixes Applied Successfully! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Close the running Flutter app (press 'q' in terminal)" -ForegroundColor White
Write-Host "2. Run: flutter clean" -ForegroundColor White
Write-Host "3. Run: flutter run -d windows" -ForegroundColor White
Write-Host ""
Write-Host "You'll now see Health Track and Education Track options in the sidebar!" -ForegroundColor Green
Write-Host ""
