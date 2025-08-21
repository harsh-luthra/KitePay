#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Move into the Flutter project root (same as script location)
cd "$SCRIPT_DIR" || exit

# Ensure Flutter is available in PATH when running from Finder
export PATH="$PATH:$HOME/flutter/bin"

echo "📦 Building Flutter Web..."
flutter build web

echo "🔧 Updating flutter_bootstrap.js version..."
dart tools/version_assets.dart

echo "✅ Done. Web app is ready to deploy!"

# Pause so terminal window doesn't close immediately
read -p "Press Enter to exit..."
