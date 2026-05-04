#!/bin/bash
# Automatic deployment script for Gemma 4 Health & Education features

PROJECT_DIR="C:/Users/ankit/Projects/Android/CyborgAI-main"

echo "🚀 Deploying Gemma 4 Health & Education Features..."
echo ""

# Check if project directory exists (Windows path)
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Project directory not found: $PROJECT_DIR"
    echo "Please update PROJECT_DIR in this script"
    exit 1
fi

echo "✅ Found project at: $PROJECT_DIR"
echo ""

# Copy Python backend files
echo "📦 Copying backend services..."
cp -r assets/backend/services/health "$PROJECT_DIR/assets/backend/services/" 2>/dev/null || true
cp -r assets/backend/services/education "$PROJECT_DIR/assets/backend/services/" 2>/dev/null || true
echo "✅ Health services copied"
echo "✅ Education services copied"

# Copy API routes
echo "📦 Copying API routes..."
cp assets/backend/api/routes/health_edu.py "$PROJECT_DIR/assets/backend/api/routes/" 2>/dev/null || true
echo "✅ API routes copied"

# Copy main.py (updated with health_edu router)
echo "📦 Updating main.py..."
cp assets/backend/main.py "$PROJECT_DIR/assets/backend/" 2>/dev/null || true
echo "✅ main.py updated"

# Copy Flutter frontend files
echo "📦 Copying Flutter UI updates..."
cp lib/screens/windows/home_screen.dart "$PROJECT_DIR/lib/screens/windows/" 2>/dev/null || true
cp lib/screens/android/home_screen.dart "$PROJECT_DIR/lib/screens/android/" 2>/dev/null || true
echo "✅ Windows home screen updated"
echo "✅ Android home screen updated"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Navigate to your project: cd \"$PROJECT_DIR\""
echo "2. Clean and rebuild: flutter clean && flutter pub get"
echo "3. Run the app: flutter run -d windows"
echo ""
echo "The new Health & Education features will appear in the sidebar!"
