# Cyborg — Complete Setup Guide

## Prerequisites

### Flutter (Frontend)
```
Flutter SDK ≥ 3.19.0
Dart SDK ≥ 3.2.0
```
Download: https://docs.flutter.dev/get-started/install

### Python (Backend)
```
Python 3.10, 3.11, or 3.12
```

### Android Build
```
Android Studio with SDK ≥ API 21
```

---

## Step 1 — Backend Setup

```bash
cd cyborg/backend
cp .env.example .env
```

Edit `.env` — minimum required:
```env
SECRET_KEY=******
FIREBASE_SERVICE_ACCOUNT_PATH=config/firebase-service-account.json
```

Download Firebase service account:
→ Firebase Console → Project Settings → Service Accounts → Generate new private key
→ Save as `backend/config/firebase-service-account.json`

Start backend:
```bash
./start.sh        # Linux/macOS
start.bat         # Windows
```

Backend runs at: `http://127.0.0.1:8765`
API docs: `http://127.0.0.1:8765/api/docs`

---

## Step 2 — Frontend Setup

```bash
cd cyborg/frontend
flutter pub get
```

### Android
Place `google-services.json` (already provided) in:
```
frontend/android/app/google-services.json
```

Build/run:
```bash
flutter run -d android
flutter build apk --release
```

### Windows
```bash
flutter run -d windows
flutter build windows --release
```

### macOS
```bash
flutter run -d macos
flutter build macos --release
```

### Linux
```bash
flutter run -d linux
flutter build linux --release
```

---

## Step 3 — Load an LLM Model

1. Open the app → **Models** tab
2. Browse catalog → click **Download** on any model
3. After download → click **Load** to activate
4. Return to **Chat** tab and start chatting

### GPU Acceleration (Windows)
```bat
cd backend
.venv\Scripts\activate
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu121
```

### No GPU / CPU Only
```bash
pip install llama-cpp-python
```

---

## Step 4 — Optional: JetBrains Mono Font

1. Download from: https://www.jetbrains.com/legalterms/jetbrains-mono/
2. Place in `frontend/assets/fonts/`:
   - `JetBrainsMono-Regular.ttf`
   - `JetBrainsMono-Bold.ttf`
3. Uncomment font section in `pubspec.yaml`
4. Uncomment `fontFamily` lines in `lib/core/theme/app_theme.dart`

---

## Step 5 — GitHub Integration (Optional)

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Generate token with `repo` scope
3. In Cyborg app → **GitHub** tab → paste token → Connect

Your Cyborg config and knowledge base will sync to a private repo.

---

## Troubleshooting

### Backend won't start
```bash
cd backend && python -m uvicorn main:app --port 8765 --reload
```
Check for Python version: `python --version` (needs 3.10+)

### Flutter pub get fails
```bash
flutter clean && flutter pub get
```

### Android Gradle errors
```bash
cd frontend/android && ./gradlew clean
flutter run -d android
```

### `llama-cpp-python` install fails on Windows
Install Visual Studio Build Tools first:
https://visualstudio.microsoft.com/visual-cpp-build-tools/
Then: `pip install llama-cpp-python`

### Firebase auth not working
Ensure `config/firebase-service-account.json` exists in backend.
For local dev without Firebase, the middleware logs a warning and continues.

---

## Windows Build Setup (Required First-Time)

Flutter does **not** include the Windows runner in our source (it's machine-generated).
You must regenerate it on your machine:

```powershell
cd cyborg\frontend
flutter create --platforms=windows .
```

This generates `windows\runner\` and `windows\CMakeLists.txt` for your machine.
Then run normally:

```powershell
flutter run -d windows
flutter build windows --release
```

> Do this once. The `windows\` folder is git-ignored because it's machine-specific.

## Android Build Setup (Required First-Time)

Similarly for Android:
```bash
cd cyborg/frontend
flutter create --platforms=android .
```

Place your `google-services.json` in `android/app/` after creating.
