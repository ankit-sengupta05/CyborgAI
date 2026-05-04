# 🚀 Gemma 4 Frontend Deployment Guide

## ✅ What's Been Updated

### Backend (Python) - All in `assets/backend/`
- **Health Services**: `assets/backend/services/health/`
  - `inference.py` - MedGemma 4B X-ray analysis
  - `ehr_functions.py` - FHIR-compatible EHR function calling
  - `prompts.py` - Medical prompt templates
  
- **Education Services**: `assets/backend/services/education/`
  - `grader.py` - OCR homework grader with rubric support
  - `quiz_generator.py` - Adaptive quiz generation
  - `progress_tracker.py` - Student progress tracking

- **API Routes**: `assets/backend/api/routes/health_edu.py`
  - `/api/v1/health/status` - Check health service status
  - `/api/v1/health/analyze-xray` - Upload & analyze chest X-ray
  - `/api/v1/health/ehr/query` - Query EHR data
  - `/api/v1/education/status` - Check education service status
  - `/api/v1/education/grade-homework` - Grade homework submission
  - `/api/v1/education/generate-quiz` - Generate adaptive quiz
  - `/api/v1/education/progress/{student_id}` - Get student progress

### Frontend (Flutter) - Ready to Deploy
- **API Constants**: `lib/core/constants/api_constants.dart`
- **Service Layer**: `lib/core/services/health_edu_service.dart`
- **Windows UI**: `lib/screens/windows/home_screen.dart` (1,274 lines)
  - Health Track sidebar navigation
  - X-Ray Analysis panel with file upload & results display
  - EHR Assistant panel
  - Homework Grader panel with OCR upload
  - Quiz Generator panel with adaptive questions

## 📋 Deployment Steps

### Option A: PowerShell (Recommended for Windows)

```powershell
# Run the deployment script
.\DEPLOY_WINDOWS_FRONTEND.ps1

# Then navigate to your project and run
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter run -d windows
```

### Option B: Manual Copy

Copy these 3 files to your Flutter project:

1. **API Constants**
   ```
   From: /workspace/lib/core/constants/api_constants.dart
   To:   C:\Users\ankit\Projects\Android\CyborgAI-main\lib\core\constants\api_constants.dart
   ```

2. **HealthEdu Service**
   ```
   From: /workspace/lib/core/services/health_edu_service.dart
   To:   C:\Users\ankit\Projects\Android\CyborgAI-main\lib\core\services\health_edu_service.dart
   ```

3. **Windows Home Screen**
   ```
   From: /workspace/lib/screens/windows/home_screen.dart
   To:   C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\home_screen.dart
   ```

Then run:
```bash
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter run -d windows
```

## 🎯 What You'll See

### Desktop Sidebar Navigation
```
├── Neural Interface
├── Devices
├── GPU
├── Vector DB
│
├── 🏥 Health Track (Category)
│   ├── X-Ray Analysis
│   └── EHR Assistant
│
├── 📚 Education Track (Category)
│   ├── Homework Grader
│   └── Quiz Generator
│
└── Logs
```

### X-Ray Analysis Panel
1. Click "UPLOAD X-RAY" button
2. Select chest X-ray image (PNG/JPG)
3. View analysis results:
   - Findings with confidence score
   - Plain-language explanation
   - Recommendations
   - Medical disclaimer

### Homework Grader Panel
1. Click "UPLOAD HOMEWORK" button
2. Select homework image
3. View grading results:
   - Score percentage
   - Subject & grade level
   - Detailed feedback

### Quiz Generator Panel
1. Click "GENERATE QUIZ" button
2. View generated quiz:
   - Topic & grade level
   - Number of questions
   - Sample questions preview

## 🔧 Backend Requirements

Make sure your backend has the required models:

```bash
# In assets/backend/models/llm/
- Qwen2.5-1.5B-Instruct-Q4_K_M.gguf (already present)

# For full Gemma 4 features, download:
- medgemma-4b-q4_k_m.gguf (for X-ray analysis)
- gemma-2-2b-it-q4_k_m.gguf (for education features)
```

Download models from Hugging Face:
```bash
huggingface-cli download google/gemma-2-2b-it-gguf --local-dir assets/backend/models/llm/
```

## 🧪 Testing the Features

### Test X-Ray Analysis
1. Run the app: `flutter run -d windows`
2. Navigate to "X-Ray Analysis" in sidebar
3. Upload a chest X-ray image (sample images available online)
4. Wait for analysis (5-30 seconds depending on model size)
5. View structured results with confidence scores

### Test Homework Grader
1. Navigate to "Homework Grader"
2. Upload any handwritten math/science homework
3. View OCR results and automated grading
4. Supports English, Spanish, Hindi

### Test Quiz Generator
1. Navigate to "Quiz Generator"
2. Click generate (pre-configured for Algebra, Grade 10)
3. View adaptive quiz with cultural relevance
4. Questions adjust based on difficulty

## 📝 API Documentation

Full API docs available at: http://127.0.0.1:8765/api/docs

Key endpoints:
- `GET /api/v1/health/status`
- `POST /api/v1/health/analyze-xray`
- `POST /api/v1/health/ehr/query`
- `GET /api/v1/education/status`
- `POST /api/v1/education/grade-homework`
- `POST /api/v1/education/generate-quiz`

## ⚠️ Important Notes

1. **Medical Disclaimer**: X-ray analysis is for educational purposes only, NOT diagnosis
2. **Offline First**: All processing happens locally on your machine
3. **GPU Acceleration**: CUDA 13.2 detected - models will use your RTX 5060
4. **Multi-language**: Supports English (en), Spanish (es), Hindi (hi)

## 🐛 Troubleshooting

### "Health services not available"
- Ensure backend is running: check logs for `[OK] All services ready`
- Verify models are downloaded in `assets/backend/models/llm/`

### File picker not opening
- Check `file_picker` package is in `pubspec.yaml`
- Run `flutter pub get`

### Analysis taking too long
- First run downloads model weights (one-time)
- Subsequent runs should be 5-30 seconds
- Check GPU utilization in Task Manager

## 📞 Support

For issues or questions:
1. Check backend logs in terminal
2. Verify API endpoints at http://127.0.0.1:8765/api/docs
3. Review PRD v18.0 for feature specifications
