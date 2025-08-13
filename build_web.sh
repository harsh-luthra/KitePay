#!/bin/bash

echo "📦 Building Flutter Web..."
flutter build web

echo "🔧 Updating flutter_bootstrap.js version..."
#dart tools/update_bootstrap_version.dart
dart tools/version_assets.dart

echo "✅ Done. Web app is ready to deploy!"
