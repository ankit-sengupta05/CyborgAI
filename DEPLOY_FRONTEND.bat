@echo off
echo === Deploying Gemma 4 Frontend Updates ===
echo.

set SOURCE=%~dp0
set DEST=C:\Users\ankit\Projects\Android\CyborgAI-main

echo Copying Health Screen...
copy "%SOURCE%lib\screens\windows\health_screen.dart" "%DEST%\lib\screens\windows\health_screen.dart" /Y

echo Copying Education Screen...
copy "%SOURCE%lib\screens\windows\education_screen.dart" "%DEST%\lib\screens\windows\education_screen.dart" /Y

echo Copying Home Screen (with sidebar updates)...
copy "%SOURCE%lib\screens\windows\home_screen.dart" "%DEST%\lib\screens\windows\home_screen.dart" /Y

echo Copying HealthEduService...
copy "%SOURCE%lib\core\services\health_edu_service.dart" "%DEST%\lib\core\services\health_edu_service.dart" /Y

echo.
echo === Deployment Complete! ===
echo.
echo Next steps:
echo 1. cd C:\Users\ankit\Projects\Android\CyborgAI-main
echo 2. flutter clean
echo 3. flutter pub get
echo 4. flutter run -d windows
echo.
echo You will now see:
echo   - Health Track button in sidebar - opens X-Ray and EHR tabs
echo   - Education Track button in sidebar - opens Homework Grader and Quiz Generator tabs
echo   - Working file pickers for uploading images and documents
echo   - Backend API integration for all features
pause
