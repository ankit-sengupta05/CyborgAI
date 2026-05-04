# PowerShell script to deploy updated frontend files to your Flutter project

$targetBase = "C:\Users\ankit\Projects\Android\CyborgAI-main"
$sourceBase = (Get-Item $PSScriptRoot).FullName

Write-Host "=== Deploying Gemma 4 Frontend Updates ===" -ForegroundColor Cyan
Write-Host ""

# Copy API Constants
Write-Host "Copying API constants..." -ForegroundColor Yellow
Copy-Item "$sourceBase\lib\core\constants\api_constants.dart" `
          "$targetBase\lib\core\constants\api_constants.dart" -Force

# Copy HealthEdu Service
Write-Host "Copying HealthEduService..." -ForegroundColor Yellow
Copy-Item "$sourceBase\lib\core\services\health_edu_service.dart" `
          "$targetBase\lib\core\services\health_edu_service.dart" -Force

# Copy Windows Home Screen
Write-Host "Copying Windows home_screen.dart..." -ForegroundColor Yellow
Copy-Item "$sourceBase\lib\screens\windows\home_screen.dart" `
          "$targetBase\lib\screens\windows\home_screen.dart" -Force

Write-Host ""
Write-Host "=== Deployment Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. cd $targetBase"
Write-Host "2. flutter clean"
Write-Host "3. flutter run -d windows"
Write-Host ""
Write-Host "You'll now see:" -ForegroundColor Green
Write-Host "  - Health Track (X-Ray Analysis, EHR Assistant)"
Write-Host "  - Education Track (Homework Grader, Quiz Generator)"
Write-Host ""
