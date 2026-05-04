# 🔧 Quick Fix for Gemma 4 Import Errors

## Problem
The backend is failing to start with this error:
```
ImportError: cannot import name 'AdaptiveQuizGenerator' from 'services.education.quiz_generator'
```

## Root Cause
The class in `quiz_generator.py` is named `QuizGenerator`, but the imports expect `AdaptiveQuizGenerator`.

## Solution (Already Applied in /workspace)

### Fixed Files:
1. **`assets/backend/services/education/__init__.py`**
   - Changed: `from .quiz_generator import AdaptiveQuizGenerator`
   - To: `from .quiz_generator import QuizGenerator as AdaptiveQuizGenerator`

2. **`assets/backend/api/routes/health_edu.py`**
   - Same fix applied to API route imports

## How to Deploy the Fix

### Option A: Run PowerShell Script (Recommended)
```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main
powershell -ExecutionPolicy Bypass -File DEPLOY_FIX.ps1
```

### Option B: Run Batch File
```cmd
cd C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend
FIX_AND_DEPLOY.bat
```

### Option C: Manual Fix
Run these commands in PowerShell:
```powershell
# Fix education/__init__.py
(Get-Content "assets\backend\services\education\__init__.py") -replace 'from .quiz_generator import AdaptiveQuizGenerator', 'from .quiz_generator import QuizGenerator as AdaptiveQuizGenerator' | Set-Content "assets\backend\services\education\__init__.py"

# Fix api/routes/health_edu.py
(Get-Content "assets\backend\api\routes\health_edu.py") -replace 'from ..services.education.quiz_generator import AdaptiveQuizGenerator', 'from ..services.education.quiz_generator import QuizGenerator as AdaptiveQuizGenerator' | Set-Content "assets\backend\api\routes\health_edu.py"
```

## After Applying Fix

1. **Stop the running app** (press `q` in terminal)
2. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

3. **Verify backend starts successfully** - you should see:
   ```
   [Backend] [OK] All services ready
   [Backend ERR] INFO: Uvicorn running on http://127.0.0.1:8765
   ```

## What You'll See

After the fix, the sidebar will show:
- **Health Track** (purple header)
  - X-Ray Analysis
  - EHR Assistant
- **Education Track** (purple header)
  - Homework Grader
  - Quiz Generator

Click any option to access the feature panel with file upload buttons!

## Troubleshooting

If backend still fails:
1. Check Python environment: `py --version` (should be 3.13+)
2. Verify files exist in `assets/backend/services/`
3. Check logs for specific import errors
