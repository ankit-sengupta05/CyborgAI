@echo off
echo === Deploying Gemma 4 Health & Education Screens ===
echo.

REM Get the workspace directory
set WORKSPACE_DIR=%~dp0

REM Copy Health Screen
echo Copying Health Screen...
copy "%WORKSPACE_DIR%lib\screens\windows\health_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\health_screen.dart" /Y

REM Copy Education Screen
echo Copying Education Screen...
copy "%WORKSPACE_DIR%lib\screens\windows\education_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\education_screen.dart" /Y

echo.
echo === Deployment Complete! ===
echo.
echo Next steps:
echo 1. The new screens are ready at:
echo    - lib/screens/windows/health_screen.dart
echo    - lib/screens/windows/education_screen.dart
echo.
echo 2. These screens have:
echo    - Working file picker for X-rays and homework
echo    - Backend API integration
echo    - Results display with confidence scores
echo    - Medical disclaimers and safety info
echo.
echo 3. Run: flutter clean ^&^& flutter run -d windows
echo.
pause
