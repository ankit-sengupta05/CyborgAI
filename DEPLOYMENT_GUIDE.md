# 🚀 Gemma 4 Health & Education Deployment Guide

## ✅ What's Been Implemented

### Backend (Python - FastAPI)
All Python files are in `assets/backend/`:

**Services:**
- `assets/backend/services/health/inference.py` - MedGemma 4B X-ray analysis
- `assets/backend/services/health/ehr_functions.py` - EHR function calling (FHIR-compatible)
- `assets/backend/services/health/prompts.py` - Medical prompts & disclaimers
- `assets/backend/services/education/grader.py` - Homework OCR grader
- `assets/backend/services/education/quiz_generator.py` - Adaptive quiz generator
- `assets/backend/services/education/progress_tracker.py` - Student progress tracking

**API Routes:**
- `assets/backend/api/routes/health_edu.py` - 10+ REST endpoints for health & education

**Updated Main:**
- `assets/backend/main.py` - Registered health_edu router at `/api/v1`

### Frontend (Flutter - Dart)
UI files ready in `lib/screens/`:

- `lib/screens/windows/home_screen.dart` - Desktop sidebar with Health/Education tracks
- `lib/screens/android/home_screen.dart` - Mobile chip navigation

## 🔧 Automatic Deployment (Recommended)

### Option 1: Double-click DEPLOY.bat (Windows)
```
1. Navigate to C:\path\to\workspace
2. Double-click: DEPLOY.bat
3. Wait for "Deployment Complete!" message
```

### Option 2: Run PowerShell Script
```powershell
cd C:\path\to\workspace
.\DEPLOY.ps1
```

### Option 3: Manual Copy (If scripts fail)

**Step 1: Copy Backend Services**
```powershell
# Health services
Copy-Item -Recurse -Force "C:\path\to\workspace\assets\backend\services\health" "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\"

# Education services
Copy-Item -Recurse -Force "C:\path\to\workspace\assets\backend\services\education" "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\"
```

**Step 2: Copy API Routes**
```powershell
Copy-Item -Force "C:\path\to\workspace\assets\backend\api\routes\health_edu.py" "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\api\routes\"
```

**Step 3: Update main.py**
```powershell
Copy-Item -Force "C:\path\to\workspace\assets\backend\main.py" "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\"
```

**Step 4: Copy Flutter UI**
```powershell
# Windows desktop
Copy-Item -Force "C:\path\to\workspace\lib\screens\windows\home_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\"

# Android mobile
Copy-Item -Force "C:\path\to\workspace\lib\screens\android\home_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\android\"
```

## 🏃 Run the App

After deployment, run these commands in your project directory:

```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main

# Clean and rebuild
flutter clean
flutter pub get

# Run on Windows
flutter run -d windows
```

## 🎯 What You'll See

### Windows Desktop Sidebar
```
├── Dashboard
├── Chat
├── Agents
├── Health Track          ← NEW!
│   ├── X-Ray Analysis
│   └── EHR Assistant
├── Education Track       ← NEW!
│   ├── Homework Grader
│   └── Quiz Generator
├── ...
```

### New Features
1. **X-Ray Analysis** - Upload chest X-rays for MedGemma analysis
2. **EHR Assistant** - Query/update patient records (FHIR-compatible)
3. **Homework Grader** - OCR-based grading with rubrics (en, es, hi)
4. **Quiz Generator** - Adaptive quizzes with cultural relevance

## 🔗 API Endpoints

Once running, access:
- **Health Status**: `GET http://127.0.0.1:8765/api/v1/health/status`
- **Education Status**: `GET http://127.0.0.1:8765/api/v1/education/status`
- **API Docs**: `http://127.0.0.1:8765/api/docs`

### Example API Calls

**Analyze X-Ray:**
```bash
curl -X POST http://127.0.0.1:8765/api/v1/health/analyze-xray \
  -F "image=@chest_xray.png" \
  -F "age=45" \
  -F "symptoms=cough,fever" \
  -F "language=en"
```

**Grade Homework:**
```bash
curl -X POST http://127.0.0.1:8765/api/v1/education/grade-homework \
  -F "image=@homework.jpg" \
  -F "subject=math" \
  -F "grade_level=8" \
  -F "language=en"
```

## ⚠️ Troubleshooting

### "Module not found" errors
Make sure all files were copied to the correct locations:
```powershell
# Verify backend services exist
Test-Path "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\health\inference.py"
Test-Path "C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend\services\education\grader.py"
```

### UI not showing new options
1. Ensure `home_screen.dart` was overwritten
2. Run `flutter clean` before rebuilding
3. Check for compilation errors in VS Code terminal

### Backend import errors
The routes file uses try/except for imports, so it will gracefully degrade if models aren't installed. To enable full functionality:
```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend
.\.venv\Scripts\activate
pip install pillow pytesseract transformers torch torchvision
```

## 📦 Model Requirements (Optional)

For full functionality, download these models:

**MedGemma 4B (Health):**
```bash
huggingface-cli download google/gemma-4b-medical --local-dir assets/backend/models/health
```

**Tesseract OCR (Education):**
```bash
# Download from: https://github.com/tesseract-ocr/tessdata
# Place in: assets/backend/models/ocr/tessdata/
```

## ✅ Verification Checklist

- [ ] Backend services copied to `assets/backend/services/`
- [ ] API route `health_edu.py` in `assets/backend/api/routes/`
- [ ] `main.py` updated with health_edu router
- [ ] Flutter UI files copied to `lib/screens/`
- [ ] `flutter clean && flutter pub get` completed
- [ ] App runs without errors
- [ ] Sidebar shows Health & Education tracks
- [ ] API docs accessible at `/api/docs`

---

**Need Help?** Check the backend logs for import errors or run:
```powershell
cd C:\Users\ankit\Projects\Android\CyborgAI-main\assets\backend
python -c "from services.health.inference import MedGemmaPipeline; print('Health OK')"
python -c "from services.education.grader import HomeworkGrader; print('Education OK')"
```
