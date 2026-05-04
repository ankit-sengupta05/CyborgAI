# Gemma 4 Health & Education - Complete Deployment Script
# Run this in PowerShell from your CyborgAI project folder

Write-Host "=== Deploying Gemma 4 Health & Education Features ===" -ForegroundColor Cyan
Write-Host ""

$projectRoot = "C:\Users\ankit\Projects\Android\CyborgAI-main"
$workspaceRoot = "C:\path\to\workspace"  # Update this path

# Check if running from workspace or need to copy
if (Test-Path "$PSScriptRoot\lib\core\services\health_edu_service.dart") {
    $sourceBase = $PSScriptRoot
    Write-Host "Deploying from workspace folder..." -ForegroundColor Green
} else {
    Write-Host "ERROR: Please run this script from the workspace folder" -ForegroundColor Red
    Write-Host "Or update the source paths manually" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[1/5] Fixing health_edu_service.dart imports..." -ForegroundColor Yellow
$serviceFile = "$sourceBase\lib\core\services\health_edu_service.dart"
$content = Get-Content $serviceFile -Raw
if ($content -notmatch "import 'dart:convert';") {
    $content = "import 'dart:convert';`n$content"
    Set-Content $serviceFile $content -NoNewline
    Write-Host "✓ Added dart:convert import" -ForegroundColor Green
} else {
    Write-Host "✓ dart:convert already imported" -ForegroundColor Green
}

Write-Host "`n[2/5] Copying updated files to Flutter project..." -ForegroundColor Yellow

# Create directories if they don't exist
$dirs = @(
    "$projectRoot\lib\core\constants",
    "$projectRoot\lib\core\services",
    "$projectRoot\lib\screens\windows",
    "$projectRoot\lib\screens\android"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Gray
    }
}

# Copy files
$files = @(
    @{Source="lib\core\constants\api_constants.dart"; Dest="$projectRoot\lib\core\constants\api_constants.dart"},
    @{Source="lib\core\services\health_edu_service.dart"; Dest="$projectRoot\lib\core\services\health_edu_service.dart"},
    @{Source="lib\screens\windows\home_screen.dart"; Dest="$projectRoot\lib\screens\windows\home_screen.dart"},
    @{Source="lib\screens\android\home_screen.dart"; Dest="$projectRoot\lib\screens\android\home_screen.dart"}
)

foreach ($file in $files) {
    if (Test-Path "$sourceBase\$($file.Source)") {
        Copy-Item "$sourceBase\$($file.Source)" $file.Dest -Force
        Write-Host "  ✓ $($file.Source)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Missing: $($file.Source)" -ForegroundColor Yellow
    }
}

Write-Host "`n[3/5] Updating backend Python files..." -ForegroundColor Yellow

# Copy backend files
$backendFiles = @(
    @{Source="assets\backend\api\routes\health_edu.py"; Dest="$projectRoot\assets\backend\api\routes\health_edu.py"},
    @{Source="assets\backend\api\routes\__init__.py"; Dest="$projectRoot\assets\backend\api\routes\__init__.py"},
    @{Source="assets\backend\services\__init__.py"; Dest="$projectRoot\assets\backend\services\__init__.py"},
    @{Source="assets\backend\services\health\__init__.py"; Dest="$projectRoot\assets\backend\services\health\__init__.py"},
    @{Source="assets\backend\services\education\__init__.py"; Dest="$projectRoot\assets\backend\services\education\__init__.py"},
    @{Source="assets\backend\main.py"; Dest="$projectRoot\assets\backend\main.py"}
)

foreach ($file in $backendFiles) {
    if (Test-Path "$sourceBase\$($file.Source)") {
        Copy-Item "$sourceBase\$($file.Source)" $file.Dest -Force
        Write-Host "  ✓ $($file.Source)" -ForegroundColor Green
    }
}

# Copy health & education service folders
$serviceDirs = @(
    "assets\backend\services\health",
    "assets\backend\services\education"
)

foreach ($dir in $serviceDirs) {
    if (Test-Path "$sourceBase\$dir") {
        Get-ChildItem "$sourceBase\$dir" -Filter *.py | ForEach-Object {
            $destFile = "$projectRoot\$dir\$($_.Name)"
            Copy-Item $_.FullName $destFile -Force
            Write-Host "  ✓ $dir\$($_.Name)" -ForegroundColor Green
        }
    }
}

Write-Host "`n[4/5] Cleaning Flutter build..." -ForegroundColor Yellow
Set-Location $projectRoot
flutter clean
Write-Host "✓ Flutter clean complete" -ForegroundColor Green

Write-Host "`n[5/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host "✓ Dependencies resolved" -ForegroundColor Green

Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                  DEPLOYMENT COMPLETE!                  " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "1. Run: flutter run -d windows" -ForegroundColor Yellow
Write-Host "2. You'll see new sidebar options:" -ForegroundColor Yellow
Write-Host "   • Health Track → X-Ray Analysis, EHR Assistant" -ForegroundColor Gray
Write-Host "   • Education Track → Homework Grader, Quiz Generator" -ForegroundColor Gray
Write-Host "`nFeatures ready to test:" -ForegroundColor White
Write-Host "✓ Upload & analyze chest X-rays" -ForegroundColor Green
Write-Host "✓ Grade homework with OCR" -ForegroundColor Green
Write-Host "✓ Generate adaptive quizzes" -ForegroundColor Green
Write-Host "✓ Track student progress" -ForegroundColor Green
Write-Host "`nBackend API docs: http://127.0.0.1:8765/api/docs" -ForegroundColor Cyan
Write-Host "`n"
