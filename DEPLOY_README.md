# 🚀 Automatic Deployment Guide

## Quick Deploy (One Command)

Open PowerShell in the `/workspace` directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File DEPLOY_AUTOMATIC.ps1
```

This will automatically:
1. ✅ Copy all Python backend services to your CyborgAI project
2. ✅ Add new API routes for health & education
3. ✅ Update `main.py` to register the new endpoints
4. ✅ Deploy updated Flutter UI files (Windows & Android)
5. ✅ Show you the next steps

## Manual Deployment (If Needed)

### Step 1: Backend Services

```powershell
# Create directories
New-Item -ItemType Directory -Force "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\health"
New-Item -ItemType Directory -Force "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\education"

# Copy service files
Copy-Item ".\assets\backend\services\health\*" -Destination "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\health\" -Force
Copy-Item ".\assets\backend\services\education\*" -Destination "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\education\"

# Copy API route
Copy-Item ".\assets\backend\api\routes\health_edu.py" -Destination "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\api\routes\" -Force
```

### Step 2: Update main.py

Add this import to `C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\main.py`:

```python
from api.routes import (
    vault,
    worldmonitor,
    codeflow,
    gsd_engine as gsd_engine_router,
    ingest as ingest_router,
    voice,
    health_edu as health_edu_router,  # ← Add this line
)
```

Add this router registration (around line 187):

```python
app.include_router(health_edu_router.router,   prefix="/api/v1", tags=["Health & Education"])
```

### Step 3: Frontend Files

```powershell
# Windows Desktop
Copy-Item ".\lib\screens\windows\home_screen.dart" -Destination "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\home_screen.dart" -Force

# Android Mobile
Copy-Item ".\lib\screens\android\home_screen.dart" -Destination "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\android\home_screen.dart" -Force
```

### Step 4: Restart App

```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter run -d windows
```

## New Features Available

### Health Track
- **X-Ray Analysis** - Upload chest X-rays for AI-powered analysis
- **EHR Assistant** - Query and update electronic health records

### Education Track  
- **Homework Grader** - OCR-based homework evaluation with rubrics
- **Quiz Generator** - Adaptive quizzes with cultural relevance

Both support English, Spanish, and Hindi languages.

## API Endpoints

After deployment, these endpoints will be available:

```
GET  /api/v1/health/status
POST /api/v1/health/analyze-xray
POST /api/v1/health/ehr/query
POST /api/v1/health/ehr/update

GET  /api/v1/education/status
POST /api/v1/education/grade-homework
POST /api/v1/education/generate-quiz
GET  /api/v1/education/progress/{student_id}
POST /api/v1/education/track-submission
```

## Troubleshooting

**Backend won't start:**
- Check that all Python files were copied correctly
- Verify `main.py` has the new import and router registration
- Look for import errors in the backend logs

**Frontend doesn't show new options:**
- Run `flutter clean` before restarting
- Make sure both `home_screen.dart` files were updated
- Hot reload may not be enough - do a full restart

**Import errors:**
- Ensure you're running from the correct directory
- Check file paths match your actual project structure
