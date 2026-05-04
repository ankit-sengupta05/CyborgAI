# Gemma 4 Health & Education Auto-Deploy Script
# Run this in PowerShell: .\DEPLOY.ps1

$PROJECT_DIR = "C:\Users\ankit\Projects\Android\CyborgAI-main"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Gemma 4 Health & Education Deployment" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check if project directory exists
if (-not (Test-Path $PROJECT_DIR)) {
    Write-Host "ERROR: Project directory not found: $PROJECT_DIR" -ForegroundColor Red
    Write-Host "Please update PROJECT_DIR in this script" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[1/5] Found project at: $PROJECT_DIR" -ForegroundColor Green
Write-Host ""

# Copy Backend Services
Write-Host "[2/5] Copying backend services..." -ForegroundColor Yellow
try {
    Copy-Item -Recurse -Force "assets\backend\services\health" "$PROJECT_DIR\assets\backend\services\" -ErrorAction Stop
    Write-Host "      ✓ Health services copied" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to copy health services: $_" -ForegroundColor Red
}

try {
    Copy-Item -Recurse -Force "assets\backend\services\education" "$PROJECT_DIR\assets\backend\services\" -ErrorAction Stop
    Write-Host "      ✓ Education services copied" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to copy education services: $_" -ForegroundColor Red
}
Write-Host ""

# Copy API Routes
Write-Host "[3/5] Copying API routes..." -ForegroundColor Yellow
try {
    Copy-Item -Force "assets\backend\api\routes\health_edu.py" "$PROJECT_DIR\assets\backend\api\routes\" -ErrorAction Stop
    Write-Host "      ✓ API routes copied" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to copy API routes: $_" -ForegroundColor Red
}
Write-Host ""

# Update main.py
Write-Host "[4/5] Updating main.py..." -ForegroundColor Yellow
try {
    Copy-Item -Force "assets\backend\main.py" "$PROJECT_DIR\assets\backend\" -ErrorAction Stop
    Write-Host "      ✓ main.py updated" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to update main.py: $_" -ForegroundColor Red
}
Write-Host ""

# Copy Flutter UI
Write-Host "[5/5] Copying Flutter UI updates..." -ForegroundColor Yellow
try {
    Copy-Item -Force "lib\screens\windows\home_screen.dart" "$PROJECT_DIR\lib\screens\windows\" -ErrorAction Stop
    Write-Host "      ✓ Windows home screen updated" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to copy Windows UI: $_" -ForegroundColor Red
}

try {
    Copy-Item -Force "lib\screens\android\home_screen.dart" "$PROJECT_DIR\lib\screens\android\" -ErrorAction Stop
    Write-Host "      ✓ Android home screen updated" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to copy Android UI: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Navigate to your project:" -ForegroundColor White
Write-Host "     cd $PROJECT_DIR" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Clean and rebuild:" -ForegroundColor White
Write-Host "     flutter clean && flutter pub get" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Run the app:" -ForegroundColor White
Write-Host "     flutter run -d windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "New features will appear in the sidebar:" -ForegroundColor Green
Write-Host "  • Health Track: X-Ray Analysis, EHR Assistant" -ForegroundColor White
Write-Host "  • Education Track: Homework Grader, Quiz Generator" -ForegroundColor White
Write-Host ""

pause
