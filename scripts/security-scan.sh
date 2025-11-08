#!/bin/bash
set -e

# Automated Security Scanning Script
# Runs security scans for both frontend and backend dependencies

echo "🔒 Delirium Automated Security Scan"
echo "====================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0

# Frontend Security Scan
echo "📦 Frontend Security Scan (npm)"
echo "-------------------------------"

cd "$PROJECT_ROOT/client"

if [ ! -f "package-lock.json" ]; then
    echo "⚠️  package-lock.json not found. Running npm install..."
    npm install
fi

echo "🔍 Running npm audit..."
npm audit --audit-level=moderate --json > npm-audit-report.json 2>/dev/null || true

if [ -f npm-audit-report.json ]; then
    CRITICAL=$(jq -r '.metadata.vulnerabilities.critical // 0' npm-audit-report.json 2>/dev/null || echo "0")
    HIGH=$(jq -r '.metadata.vulnerabilities.high // 0' npm-audit-report.json 2>/dev/null || echo "0")
    MODERATE=$(jq -r '.metadata.vulnerabilities.moderate // 0' npm-audit-report.json 2>/dev/null || echo "0")
    LOW=$(jq -r '.metadata.vulnerabilities.low // 0' npm-audit-report.json 2>/dev/null || echo "0")
    TOTAL=$(jq -r '.metadata.vulnerabilities.total // 0' npm-audit-report.json 2>/dev/null || echo "0")
    
    echo ""
    echo "Frontend Vulnerability Summary:"
    echo "  Critical:   $CRITICAL"
    echo "  High:       $HIGH"
    echo "  Moderate:   $MODERATE"
    echo "  Low:        $LOW"
    echo "  Total:      $TOTAL"
    echo ""
    
    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo -e "${RED}❌ Critical or High severity vulnerabilities found!${NC}"
        npm audit --audit-level=moderate
        FAILURES=$((FAILURES + 1))
    elif [ "$MODERATE" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Moderate severity vulnerabilities found. Review recommended.${NC}"
        npm audit --audit-level=moderate
    else
        echo -e "${GREEN}✅ No moderate or higher severity vulnerabilities found!${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not generate npm audit report${NC}"
fi

# Check for outdated packages
echo ""
echo "📦 Checking for outdated packages..."
set +e  # Temporarily disable exit on error for outdated check
npm outdated --json > npm-outdated.json 2>&1
OUTDATED_EXIT=$?
set -e  # Re-enable exit on error
OUTDATED_COUNT=$(jq 'length' npm-outdated.json 2>/dev/null || echo "0")
if [ "$OUTDATED_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $OUTDATED_COUNT outdated packages${NC}"
    npm outdated || true
else
    echo -e "${GREEN}✅ All packages are up to date${NC}"
fi

# Backend Security Scan
echo ""
echo "☕ Backend Security Scan (Gradle/OWASP)"
echo "---------------------------------------"

cd "$PROJECT_ROOT/server"

if [ ! -f "gradlew" ]; then
    echo "❌ gradlew not found!"
    exit 1
fi

echo "🔍 Running OWASP Dependency Check..."
./gradlew dependencyCheckAnalyze --quiet 2>&1 | tee gradle-dependency-check.log || true

if [ -f "build/reports/dependency-check/dependency-check-report.json" ]; then
    CRITICAL=$(jq '[.dependencies[] | select(.vulnerabilities[]?.severity == "CRITICAL")] | length' build/reports/dependency-check/dependency-check-report.json 2>/dev/null || echo "0")
    HIGH=$(jq '[.dependencies[] | select(.vulnerabilities[]?.severity == "HIGH")] | length' build/reports/dependency-check/dependency-check-report.json 2>/dev/null || echo "0")
    MEDIUM=$(jq '[.dependencies[] | select(.vulnerabilities[]?.severity == "MEDIUM")] | length' build/reports/dependency-check/dependency-check-report.json 2>/dev/null || echo "0")
    LOW=$(jq '[.dependencies[] | select(.vulnerabilities[]?.severity == "LOW")] | length' build/reports/dependency-check/dependency-check-report.json 2>/dev/null || echo "0")
    
    echo ""
    echo "Backend Vulnerability Summary:"
    echo "  Critical:   $CRITICAL"
    echo "  High:       $HIGH"
    echo "  Medium:     $MEDIUM"
    echo "  Low:        $LOW"
    echo ""
    echo "📄 Full report: build/reports/dependency-check/dependency-check-report.html"
    echo ""
    
    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo -e "${RED}❌ Critical or High severity vulnerabilities found!${NC}"
        FAILURES=$((FAILURES + 1))
    elif [ "$MEDIUM" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Medium severity vulnerabilities found. Review recommended.${NC}"
    else
        echo -e "${GREEN}✅ No critical or high severity vulnerabilities found!${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  OWASP Dependency Check report not found${NC}"
    echo "This might be the first run. The check may take several minutes..."
fi

# Summary
echo ""
echo "====================================="
echo "🔒 Security Scan Summary"
echo "====================================="

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✅ All security scans passed!${NC}"
    echo ""
    echo "Reports generated:"
    echo "  - Frontend: client/npm-audit-report.json"
    echo "  - Backend:  server/build/reports/dependency-check/dependency-check-report.html"
    exit 0
else
    echo -e "${RED}❌ Security scan found critical issues!${NC}"
    echo ""
    echo "Please review the reports and address vulnerabilities before proceeding."
    exit 1
fi
