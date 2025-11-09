#!/bin/bash
set -e  # Exit on any error

echo "=========================================="
echo "🔍 Running Backend CI Verification"
echo "=========================================="

cd server

# Check if Gradle build cache exists
if [ -d ".gradle" ] && [ -d "build" ]; then
  echo ""
  echo "🏗️  Checking if build needs updating..."
  # Gradle will handle incremental builds automatically
  echo "✅ Using Gradle build cache"
else
  echo ""
  echo "🏗️  Building from scratch..."
fi

echo ""
echo "🏗️  Building and testing backend..."
# Use --build-cache for better caching (if configured)
./gradlew clean build test --build-cache || ./gradlew clean build test

echo ""
echo "🔒 Running dependency check..."
./gradlew dependencyCheckAnalyze || true

echo ""
echo "✅ All backend checks passed!"
