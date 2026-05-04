# 🚀 Gemma 4 Health & Education Deployment Guide

## ✅ What's Been Created

### New Dedicated Screens (Windows Desktop)

1. **`lib/screens/windows/health_screen.dart`** - Complete Health Track UI
   - **Tab 1: X-Ray Analysis**
     - File picker for chest X-ray images (JPG, PNG, DICOM)
     - Patient age and symptoms input fields
     - Real-time analysis with MedGemma 4B
     - Results display: findings, confidence %, recommendations
     - Medical disclaimer footer
   
   - **Tab 2: EHR Assistant**
     - Patient ID input
     - Query type dropdown (summary, medications, allergies, lab results, vitals)
     - FHIR-compatible data retrieval
     - Results display with formatted JSON

2. **`lib/screens/windows/education_screen.dart`** - Complete Education Track UI
   - **Tab 1: Homework Grader**
     - File picker for homework images (JPG, PNG, PDF with OCR)
     - Subject name input
     - Grade level slider (1-12)
     - Real-time grading with rubric-based evaluation
     - Results: score %, feedback, strengths, areas for improvement
   
   - **Tab 2: Quiz Generator**
     - Topic input field
     - Grade level slider (1-12)
     - Number of questions slider (1-20)
     - Cultural context input (optional)
     - Adaptive quiz generation
     - Results: questions with options, answers, difficulty adaptation
     - Multi-language info (en, es, hi)

### Key Features

✅ **Working File Picker** - Uses `file_picker` package to select files from your computer
✅ **Backend API Integration** - All features call the Python backend via REST API
✅ **Loading States** - Shows progress indicators during analysis/generation
✅ **Error Handling** - Displays user-friendly error messages
✅ **Results Display** - Beautiful cards showing analysis results with confidence scores
✅ **Safety First** - Medical disclaimers prominently displayed
✅ **Responsive Design** - Matches existing app theme and colors

## 📋 Deployment Steps

### Option 1: Run the Batch Script (Easiest)

```batch
Double-click: DEPLOY_HEALTH_EDU.bat
```

This will automatically copy both screen files to your Flutter project.

### Option 2: Manual Copy (PowerShell)

```powershell
# Navigate to workspace
cd C:\path\to\workspace

# Copy files manually
Copy-Item "lib\screens\windows\health_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\health_screen.dart" -Force
Copy-Item "lib\screens\windows\education_screen.dart" "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\education_screen.dart" -Force

# Clean and rebuild
cd C:\Users\ankit\Projects\Android\CyborgAI-main
flutter clean
flutter pub get
flutter run -d windows
```

### Option 3: Manual Copy (File Explorer)

1. Open File Explorer
2. Navigate to `/workspace/lib/screens/windows/`
3. Copy `health_screen.dart` and `education_screen.dart`
4. Paste into `C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\`
5. Overwrite if prompted
6. Run `flutter clean && flutter run -d windows`

## 🎯 How to Access the Features

After deployment and running the app:

### Method 1: Add Navigation Buttons (Recommended)

Add these buttons to your existing home screen sidebar or navigation menu:

```dart
// In your home_screen.dart sidebar
_sideButton("Health Track", Icons.medical_services, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HealthScreen()),
  );
}),
_sideButton("Education Track", Icons.school, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EducationScreen()),
  );
}),
```

### Method 2: Replace Existing Panels

Replace the existing health/education panels in `home_screen.dart` with full-screen navigation:

```dart
// Instead of showing panel content, navigate to dedicated screen
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HealthScreen()),
  );
}
```

## 🔧 Backend Requirements

Make sure your backend has the following endpoints running:

- `POST /api/v1/health/analyze-xray` - X-ray analysis
- `POST /api/v1/health/ehr/query` - EHR queries
- `POST /api/v1/education/grade-homework` - Homework grading
- `POST /api/v1/education/generate-quiz` - Quiz generation

The backend should already have these from the PRD v18.0 implementation in:
- `assets/backend/services/health/`
- `assets/backend/services/education/`
- `assets/backend/api/routes/health_edu.py`

## 🧪 Testing the Features

### Test X-Ray Analysis:
1. Click "Health Track" → "X-Ray Analysis" tab
2. Click "Browse Files" button
3. Select a chest X-ray image (or any test image)
4. Optionally enter age and symptoms
5. Click "Analyze X-Ray"
6. Wait for results with confidence score

### Test Homework Grading:
1. Click "Education Track" → "Homework Grader" tab
2. Click "Browse Files" button
3. Select homework image (math problems, essays, etc.)
4. Enter subject name (e.g., "Mathematics")
5. Adjust grade level slider
6. Click "Grade Homework"
7. View score, feedback, and recommendations

### Test Quiz Generation:
1. Click "Education Track" → "Quiz Generator" tab
2. Enter topic (e.g., "Photosynthesis")
3. Adjust grade level and number of questions
4. Optionally add cultural context
5. Click "Generate Quiz"
6. View generated questions with answers

## 🎨 UI/UX Features

- **Color Scheme**: Uses existing `AppColors` theme
  - Health: Purple accent (`accentPurple`)
  - Education: Orange/Green accents
  - Success states: Green
  - Errors: Orange
  
- **Icons**: Material Design icons throughout
  - Medical: `medical_services`, `add_chart`, `folder_shared`
  - Education: `school`, `assignment_turned_in`, `quiz`
  
- **Layout**: Clean, modern card-based design
  - Upload cards with drag-and-drop feel
  - Tabbed interface for organizing features
  - Scrollable content areas
  - Responsive button sizing

## ⚠️ Important Notes

1. **Medical Disclaimer**: Always displayed at bottom of Health screen
2. **File Formats**: 
   - X-Ray: JPG, PNG, DICOM
   - Homework: JPG, PNG, PDF (OCR enabled)
3. **Offline Mode**: All processing happens locally via backend
4. **Privacy**: No data leaves your device without explicit action

## 🐛 Troubleshooting

### File Picker Not Working?
- Ensure `file_picker` is in `pubspec.yaml`
- Check Windows permissions for file access
- Try restarting the app

### Backend Not Responding?
- Verify backend is running on port 8765
- Check logs for Python errors
- Ensure all dependencies are installed

### Results Not Showing?
- Check backend console for errors
- Verify API endpoints are registered
- Look for network errors in Flutter console

## 📞 Support

For issues related to:
- **Backend Python code**: Check `assets/backend/services/`
- **Frontend Flutter code**: Check `lib/screens/windows/`
- **API integration**: Check `lib/core/services/health_edu_service.dart`

---

**Ready to deploy?** Just run `DEPLOY_HEALTH_EDU.bat` and restart your Flutter app!
