# 📋 Gemma 4 Frontend Update Instructions

## ⚠️ Important: Manual File Copy Required

The workspace files have been updated with Gemma 4 Health & Education track UI components, but they need to be copied to your local Flutter project.

## 📁 Files to Copy

### 1. Windows Desktop Home Screen
**Source:** `/workspace/lib/screens/windows/home_screen.dart`  
**Destination:** `C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\home_screen.dart`

### 2. Android Mobile Home Screen  
**Source:** `/workspace/lib/screens/android/home_screen.dart`  
**Destination:** `C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\android\home_screen.dart`

## 🔧 How to Copy

### Option A: Using File Explorer
1. Open File Explorer
2. Navigate to this workspace folder
3. Copy the two files mentioned above
4. Paste them into your CyborgAI project folder (overwrite existing files)

### Option B: Using PowerShell (Run as Administrator)
```powershell
# Copy Windows home screen
Copy-Item "C:\path\to\workspace\lib\screens\windows\home_screen.dart" `
          "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\windows\home_screen.dart" `
          -Force

# Copy Android home screen
Copy-Item "C:\path\to\workspace\lib\screens\android\home_screen.dart" `
          "C:\Users\ankit\Projects\Android\CyborgAI-main\lib\screens\android\home_screen.dart" `
          -Force
```

### Option C: Using Git (Recommended)
If your workspace is a Git repository:
```bash
cd C:\Users\ankit\Projects\Android\CyborgAI-main
git add lib/screens/windows/home_screen.dart
git add lib/screens/android/home_screen.dart
git commit -m "feat: Add Gemma 4 Health & Education track UI"
git push
```

## ✅ After Copying

1. **Stop** the currently running Flutter app (press `q` in terminal)
2. **Clean** the build:
   ```bash
   flutter clean
   flutter pub get
   ```
3. **Rebuild** and run:
   ```bash
   flutter run -d windows
   ```

## 🎯 What You'll See

After rebuilding, you'll have new sidebar navigation items:

### Windows Desktop Sidebar:
- **Health Track** (category header)
  - X-Ray Analysis
  - EHR Assistant
- **Education Track** (category header)
  - Homework Grader
  - Quiz Generator

### Android Mobile Chips:
- Category chips: "Health", "Education"
- Feature chips: "X-Ray", "EHR", "Grader", "Quiz"

Each feature has its own dedicated panel with:
- Feature description
- Action buttons (upload, connect, generate)
- Medical disclaimers (for health features)
- Multi-language support info (for education features)

## 🔗 Backend Integration

The UI buttons currently show status messages. To fully integrate with the Python demos:

1. Start the Python demos:
   ```bash
   # Health demo (port 7860)
   python assets/demos/health_demo.py
   
   # Education demo (port 7861)
   python assets/demos/education_demo.py
   ```

2. The Flutter app will need HTTP API integration to call these services (future enhancement)

## ❓ Troubleshooting

If the new options don't appear:
1. Make sure you overwrote the existing files (not created duplicates)
2. Run `flutter clean` to clear cached builds
3. Check that both files were copied successfully
4. Restart VS Code/Flutter IDE

---

**Status:** ✅ Files ready in workspace | ⏳ Waiting for manual copy to Flutter project
