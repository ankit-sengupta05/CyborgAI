# 🚀 ONE-CLICK DEPLOYMENT - Gemma 4 Health & Education

## ⚡ Quick Deploy (Choose ONE method)

### Method 1: Double-Click DEPLOY.bat (Easiest)
```
1. Open File Explorer
2. Go to: C:\path\to\workspace
3. Double-click: DEPLOY.bat
4. Wait for "Deployment Complete!"
5. Run: flutter run -d windows
```

### Method 2: PowerShell Script
```powershell
cd C:\path\to\workspace
.\DEPLOY.ps1
```

### Method 3: Manual Commands (If scripts fail)
```powershell
$SRC = "C:\path\to\workspace"
$DST = "C:\Users\ankit\Projects\Android\CyborgAI-main"

# Copy backend services
Copy-Item -Recurse -Force "$SRC\assets\backend\services\health" "$DST\assets\backend\services\"
Copy-Item -Recurse -Force "$SRC\assets\backend\services\education" "$DST\assets\backend\services\"

# Copy API routes
Copy-Item -Force "$SRC\assets\backend\api\routes\health_edu.py" "$DST\assets\backend\api\routes\"

# Update main.py
Copy-Item -Force "$SRC\assets\backend\main.py" "$DST\assets\backend\"

# Copy Flutter UI
Copy-Item -Force "$SRC\lib\screens\windows\home_screen.dart" "$DST\lib\screens\windows\"
Copy-Item -Force "$SRC\lib\screens\android\home_screen.dart" "$DST\lib\screens\android\"

# Rebuild
cd $DST
flutter clean && flutter pub get
flutter run -d windows
```

## ✅ What Gets Deployed

### Backend (Python/FastAPI)
| File | Location | Purpose |
|------|----------|---------|
| `inference.py` | `assets/backend/services/health/` | MedGemma X-ray analysis |
| `ehr_functions.py` | `assets/backend/services/health/` | EHR function calling |
| `prompts.py` | `assets/backend/services/health/` | Medical prompts |
| `grader.py` | `assets/backend/services/education/` | Homework OCR grader |
| `quiz_generator.py` | `assets/backend/services/education/` | Adaptive quiz generator |
| `progress_tracker.py` | `assets/backend/services/education/` | Student progress |
| `health_edu.py` | `assets/backend/api/routes/` | REST API endpoints |
| `main.py` | `assets/backend/` | Updated router config |

### Frontend (Flutter/Dart)
| File | Location | Purpose |
|------|----------|---------|
| `home_screen.dart` | `lib/screens/windows/` | Desktop UI with sidebar |
| `home_screen.dart` | `lib/screens/android/` | Mobile UI with chips |

## 🎯 After Deployment

You'll see in the app:
- **Health Track** → X-Ray Analysis, EHR Assistant
- **Education Track** → Homework Grader, Quiz Generator

API available at: `http://127.0.0.1:8765/api/docs`

## 🔧 Troubleshooting

**UI not showing?**
```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter pub get
flutter run -d windows
```

**Backend import errors?**
```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend
.\.venv\Scripts\activate
pip install pillow pytesseract
```

**Verify files copied:**
```powershell
Test-Path "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\health\inference.py"
Test-Path "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\home_screen.dart"
```

## 📞 Need Help?

See full guide: `DEPLOYMENT_GUIDE.md`
