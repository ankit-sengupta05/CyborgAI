# 🚀 Quick Deploy - Gemma 4 Health & Education Features

## ⚡ Fastest Method (Recommended)

**Option A: Double-click the batch file**
```
/workspace/APPLY_FIX.bat
```

**Option B: Run PowerShell script**
```powershell
cd C:\path\to\workspace
powershell -ExecutionPolicy Bypass -File DEPLOY_AUTOMATIC.ps1
```

Both scripts will automatically:
1. ✅ Copy Python backend services to `assets/backend/services/`
2. ✅ Add new API routes (`health_edu.py`)
3. ✅ Update Flutter UI files (Windows + Android)
4. ✅ Clean Flutter build
5. ✅ Show you what to do next

## 📋 What Gets Deployed

### Backend (Python)
```
assets/backend/services/health/
  ├── inference.py      (MedGemma X-ray analysis)
  ├── ehr_functions.py  (EHR function calling)
  └── prompts.py        (Medical prompts)

assets/backend/services/education/
  ├── grader.py              (Homework OCR grading)
  ├── quiz_generator.py      (Adaptive quizzes)
  └── progress_tracker.py    (Student analytics)

assets/backend/api/routes/
  └── health_edu.py     (REST API endpoints)
```

### Frontend (Flutter/Dart)
```
lib/screens/windows/home_screen.dart   (Desktop UI)
lib/screens/android/home_screen.dart   (Mobile UI)
```

## 🎯 After Running the Script

1. **Restart your app:**
   ```powershell
   cd C:\Users\ankit\Projects\Android\CyborgAI-main
   flutter run -d windows
   ```

2. **Look for new options in the sidebar:**
   - Health Track → X-Ray Analysis, EHR Assistant
   - Education Track → Homework Grader, Quiz Generator

3. **Test the API endpoints:**
   - Open browser: `http://127.0.0.1:8765/api/docs`
   - Try `/api/v1/health/status` and `/api/v1/education/status`

## 🔧 Manual Fix (If Auto-Deploy Fails)

### Step 1: Copy Backend Files

Open PowerShell as Administrator and run:

```powershell
$src = "C:\path\to\workspace"
$dst = "C:\Users\ankit\Projects\Android\CyborgAI-main"

# Backend services
Copy-Item "$src\assets\backend\services\health" -Destination "$dst\assets\backend\services\" -Recurse -Force
Copy-Item "$src\assets\backend\services\education" -Destination "$dst\assets\backend\services\" -Recurse -Force
Copy-Item "$src\assets\backend\api\routes\health_edu.py" -Destination "$dst\assets\backend\api\routes\" -Force
```

### Step 2: Update main.py Manually

Edit: `C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\main.py`

**Add import** (line ~43):
```python
from api.routes import (
    vault,
    worldmonitor,
    codeflow,
    gsd_engine as gsd_engine_router,
    ingest as ingest_router,
    voice,
    health_edu as health_edu_router,  # ← ADD THIS LINE
)
```

**Add router** (line ~187):
```python
app.include_router(health_edu_router.router, prefix="/api/v1", tags=["Health & Education"])
```

### Step 3: Copy Frontend Files

```powershell
Copy-Item "$src\lib\screens\windows\home_screen.dart" -Destination "$dst\lib\screens\windows\home_screen.dart" -Force
Copy-Item "$src\lib\screens\android\home_screen.dart" -Destination "$dst\lib\screens\android\home_screen.dart" -Force
```

### Step 4: Restart

```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter run -d windows
```

## ✅ Verification Checklist

After deployment, verify:

- [ ] Backend starts without import errors
- [ ] New sidebar categories appear (Health, Education)
- [ ] Can click on X-Ray Analysis panel
- [ ] Can click on Homework Grader panel
- [ ] API docs show new endpoints at `/api/docs`

## 🐛 Troubleshooting

**Error: "Module not found: health_edu"**
→ Make sure `health_edu.py` is in `assets/backend/api/routes/`
→ Check `main.py` has the correct import

**Frontend doesn't show new options:**
→ Run `flutter clean` (hot reload isn't enough)
→ Verify both `home_screen.dart` files were overwritten

**Backend won't start:**
→ Check Python console for import errors
→ Ensure all service files are in correct folders
→ Try running `py assets/backend/main.py` directly to see errors

## 📞 Need Help?

Check these files for detailed instructions:
- `DEPLOY_README.md` - Full deployment guide
- `DEPLOY_AUTOMATIC.ps1` - PowerShell automation script
- `APPLY_FIX.bat` - Windows batch script

---

**Created:** May 4, 2025  
**Version:** 18.0 (Gemma 4 Extension)  
**Status:** Ready for Deployment
