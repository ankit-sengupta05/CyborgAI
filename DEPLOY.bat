@echo off
REM Automatic deployment script for Gemma 4 Health & Education Features
REM Run this file to deploy all updates to your Flutter project

set PROJECT_DIR=C:\Users\ankit\Projects\Android\CyborgAI-main

echo.
echo ===============================================
echo   Gemma 4 Health & Education Deployment
echo ===============================================
echo.

REM Check if project directory exists
if not exist "%PROJECT_DIR%" (
    echo ERROR: Project directory not found: %PROJECT_DIR%
    echo Please update PROJECT_DIR in this script
    pause
    exit /b 1
)

echo [1/5] Found project at: %PROJECT_DIR%
echo.

REM Copy Python backend files
echo [2/5] Copying backend services...
xcopy /E /I /Y "assets\backend\services\health" "%PROJECT_DIR%\assets\backend\services\health\" >nul
xcopy /E /I /Y "assets\backend\services\education" "%PROJECT_DIR%\assets\backend\services\education\" >nul
echo       - Health services copied
echo       - Education services copied
echo.

REM Copy API routes
echo [3/5] Copying API routes...
copy /Y "assets\backend\api\routes\health_edu.py" "%PROJECT_DIR%\assets\backend\api\routes\" >nul
echo       - API routes copied
echo.

REM Copy main.py
echo [4/5] Updating main.py...
copy /Y "assets\backend\main.py" "%PROJECT_DIR%\assets\backend\" >nul
echo       - main.py updated
echo.

REM Copy Flutter frontend files
echo [5/5] Copying Flutter UI updates...
copy /Y "lib\screens\windows\home_screen.dart" "%PROJECT_DIR%\lib\screens\windows\" >nul
copy /Y "lib\screens\android\home_screen.dart" "%PROJECT_DIR%\lib\screens\android\" >nul
echo       - Windows home screen updated
echo       - Android home screen updated
echo.

echo ===============================================
echo   Deployment Complete!
echo ===============================================
echo.
echo Next steps:
echo   1. Navigate to your project:
echo      cd %PROJECT_DIR%
echo.
echo   2. Clean and rebuild:
echo      flutter clean ^&^& flutter pub get
echo.
echo   3. Run the app:
echo      flutter run -d windows
echo.
echo The new Health ^& Education features will appear!
echo   - Health Track: X-Ray Analysis, EHR Assistant
echo   - Education Track: Homework Grader, Quiz Generator
echo.
pause
