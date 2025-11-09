#!/bin/bash
set -e  # Exit on any error

echo "=========================================="
echo "🔍 Running Frontend CI Verification"
echo "=========================================="

cd client

# Check if node_modules exists and package-lock.json hasn't changed
if [ -d "node_modules" ] && [ -f "package-lock.json" ]; then
  echo ""
  echo "📦 Checking if dependencies need updating..."
  if [ "package-lock.json" -nt "node_modules/.package-lock.json" ] 2>/dev/null || [ ! -f "node_modules/.package-lock.json" ]; then
    echo "📦 Installing dependencies..."
    npm ci
  else
    echo "✅ Using existing node_modules (package-lock.json unchanged)"
  fi
else
  echo ""
  echo "📦 Installing dependencies..."
  npm ci
fi

# Cache Playwright browsers installation
PLAYWRIGHT_BROWSERS="$HOME/.cache/ms-playwright"
if [ ! -d "$PLAYWRIGHT_BROWSERS" ] || [ -z "$(ls -A $PLAYWRIGHT_BROWSERS 2>/dev/null)" ]; then
  echo ""
  echo "🎭 Installing Playwright browsers..."
  npx playwright install --with-deps
else
  echo ""
  echo "✅ Using cached Playwright browsers"
  # Still install system dependencies if needed
  npx playwright install-deps || true
fi

echo ""
echo "🔍 Running ESLint..."
npx eslint src/**/*.ts --cache --cache-location .eslintcache || npx eslint src/**/*.ts

echo ""
echo "🔍 Running TypeScript type check..."
npx tsc --noEmit --incremental || npx tsc --noEmit

echo ""
echo "🧪 Running unit tests..."
npx jest --testPathIgnorePatterns=/integration/ --testPathIgnorePatterns=/e2e/ --cache || npx jest --testPathIgnorePatterns=/integration/ --testPathIgnorePatterns=/e2e/

echo ""
echo "🎭 Running E2E tests..."
npx playwright test

echo ""
echo "📊 Generating coverage report..."
npx jest --coverage --cache || npx jest --coverage

echo ""
echo "🔒 Running security audit..."
npm audit --audit-level=moderate

echo ""
echo "✅ All frontend checks passed!"
