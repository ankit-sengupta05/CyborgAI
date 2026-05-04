@echo off
echo === Fixing Gemma 4 Backend & Frontend ===
echo.

REM Fix education __init__.py
echo Fixing education module imports...
powershell -Command "(Get-Content 'C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\education\__init__.py') -replace 'from .quiz_generator import AdaptiveQuizGenerator', 'from .quiz_generator import QuizGenerator as AdaptiveQuizGenerator' | Set-Content 'C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\education\__init__.py'"

REM Fix health_edu.py route imports
echo Fixing API route imports...
powershell -Command "(Get-Content 'C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\api\routes\health_edu.py') -replace 'from ..services.education.quiz_generator import AdaptiveQuizGenerator', 'from ..services.education.quiz_generator import QuizGenerator as AdaptiveQuizGenerator' | Set-Content 'C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\api\routes\health_edu.py'"

echo.
echo === Fixes Applied! ===
echo.
echo Next steps:
echo 1. Close the running Flutter app (press q in terminal)
echo 2. Run: flutter clean
echo 3. Run: flutter run -d windows
echo.
echo You'll now see Health Track and Education Track options!
pause
