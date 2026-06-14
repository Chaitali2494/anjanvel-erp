#!/bin/bash
# Anjanvel ERP — One-time Setup Script
# Run this from the Anjanvel_App folder after filling in your .env

set -e

echo "=============================="
echo "  Anjanvel ERP Setup"
echo "=============================="

# Check Flutter
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found. Install from https://flutter.dev/docs/get-started/install"
  exit 1
fi
echo "✅ Flutter: $(flutter --version | head -1)"

# Enter flutter app directory
cd "$(dirname "$0")/flutter_app"

# Check .env is filled in
if grep -q "YOUR_PROJECT_REF" .env; then
  echo ""
  echo "⚠️  Please fill in your .env file first:"
  echo "   Open: flutter_app/.env"
  echo "   Replace YOUR_PROJECT_REF and YOUR_ANON_KEY_HERE with real values"
  echo "   (From Supabase dashboard → Project Settings → API)"
  echo ""
  exit 1
fi
echo "✅ .env looks filled in"

# Install dependencies
echo ""
echo "📦 Running flutter pub get..."
flutter pub get

# Code generation
echo ""
echo "⚙️  Running build_runner..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "=============================="
echo "✅ Setup complete!"
echo ""
echo "To run the app:"
echo "  cd flutter_app"
echo "  flutter run"
echo ""
echo "To build an APK:"
echo "  flutter build apk --release"
echo "=============================="
