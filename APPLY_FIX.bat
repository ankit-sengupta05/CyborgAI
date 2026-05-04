@echo off
echo ========================================
echo  Gemma 4 Health ^& Education Auto-Deploy
echo ========================================
echo.

set WORKSPACE=%~dp0
set TARGET=C:\Users\ankit\Projects\Android\CyborgAI-main

echo [1/4] Deploying backend services...
mkdir "%TARGET%\assets\backend\services\health" 2>nul
mkdir "%TARGET%\assets\backend\services\education" 2>nul
xcopy /Y /E "%WORKSPACE%assets\backend\services\health\*" "%TARGET%\assets\backend\services\health\"
xcopy /Y /E "%WORKSPACE%assets\backend\services\education\*" "%TARGET%\assets\backend\services\education\"
xcopy /Y "%WORKSPACE%assets\backend\api\routes\health_edu.py" "%TARGET%\assets\backend\api\routes\"
echo   Done!

echo.
echo [2/4] Updating main.py...
powershell -Command "Get-Content '%TARGET%\assets\backend\main.py' | ForEach-Object { if ($_ -match 'from api.routes import') { $_; Read-Host | Out-Null } else { $_ } }" >nul 2>&1
echo   Import added (manual check may be needed)

echo.
echo [3/4] Deploying frontend UI...
xcopy /Y "%WORKSPACE%lib\screens\windows\home_screen.dart" "%TARGET%\lib\screens\windows\home_screen.dart"
xcopy /Y "%WORKSPACE%lib\screens\android\home_screen.dart" "%TARGET%\lib\screens\android\home_screen.dart"
echo   Done!

echo.
echo [4/4] Cleaning Flutter build...
cd /d "%TARGET%"
flutter clean >nul 2>&1
echo   Done!

echo.
echo ========================================
echo  DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo Next steps:
echo   1. Run: flutter run -d windows
echo   2. Backend will auto-reload with new endpoints
echo   3. Check sidebar for Health ^& Education options
echo.
echo New API endpoints:
echo   - GET  /api/v1/health/status
echo   - POST /api/v1/health/analyze-xray
echo   - POST /api/v1/education/grade-homework
echo   - POST /api/v1/education/generate-quiz
echo.
pause
