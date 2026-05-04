# PowerShell Script to Sync Gemma 4 Frontend Updates
# Run this from your CyborgAI project directory

$sourceDir = "C:\path\to\workspace\lib\screens"
$destDir = "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens"

Write-Host "🔄 Syncing Gemma 4 Frontend Updates..." -ForegroundColor Cyan

# Copy Windows home screen
Copy-Item "$sourceDir\windows\home_screen.dart" "$destDir\windows\home_screen.dart" -Force
Write-Host "✅ Updated windows/home_screen.dart" -ForegroundColor Green

# Copy Android home screen
Copy-Item "$sourceDir\android\home_screen.dart" "$destDir\android\home_screen.dart" -Force
Write-Host "✅ Updated android/home_screen.dart" -ForegroundColor Green

Write-Host "`n🎉 Sync Complete!" -ForegroundColor Green
Write-Host "Run: flutter run -d windows" -ForegroundColor Yellow
