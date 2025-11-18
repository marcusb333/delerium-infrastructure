#!/bin/bash
# Build Client Script
# File: delerium-infrastructure/scripts/build-client.sh
# Version: 1.0.0
#
# This script builds the Delirium client (TypeScript to JavaScript)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENT_DIR="${CLIENT_DIR:-$ROOT_DIR/../delerium-client}"

echo ""
print_info "================================================"
print_info "Delirium Client Build Script"
print_info "================================================"
echo ""

# Check if client directory exists
if [ ! -d "$CLIENT_DIR" ]; then
    print_error "Client directory not found: $CLIENT_DIR"
    print_info "Please clone the client repository first:"
    print_info "  git clone https://github.com/marcusb333/delerium-client.git $(dirname "$CLIENT_DIR")/delerium-client"
    exit 1
fi

print_info "Client directory: $CLIENT_DIR"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed"
    print_info "Install Node.js from: https://nodejs.org/"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm is not installed"
    print_info "Install Node.js (includes npm) from: https://nodejs.org/"
    exit 1
fi

print_success "Node.js found: $(node --version)"
print_success "npm found: $(npm --version)"
echo ""

# Change to client directory
cd "$CLIENT_DIR" || {
    print_error "Failed to change to client directory"
    exit 1
}

# Check if package.json exists
if [ ! -f "package.json" ]; then
    print_error "package.json not found in $CLIENT_DIR"
    exit 1
fi

# Install dependencies
print_info "Installing dependencies..."
if npm install --no-audit --no-fund; then
    print_success "Dependencies installed"
else
    print_error "Failed to install dependencies"
    exit 1
fi

echo ""

# Build TypeScript to JavaScript
print_info "Building TypeScript to JavaScript..."
if npm run build; then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    exit 1
fi

echo ""

# Verify output
if [ -d "js" ]; then
    print_success "JavaScript files generated in js/ directory"
    
    # Count files
    JS_FILES=$(find js -name "*.js" -type f | wc -l)
    print_info "Generated $JS_FILES JavaScript files"
    
    # List main files
    echo ""
    print_info "Main files:"
    ls -lh js/*.js 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    
else
    print_warning "js/ directory not found after build"
fi

echo ""
print_info "================================================"
print_success "Client build complete!"
print_info "================================================"
echo ""

# Check if Docker containers need restart
if docker ps --filter name=delirium-web 2>/dev/null | grep -q delirium-web; then
    echo ""
    print_info "Docker container detected. To apply changes, restart the web container:"
    echo ""
    echo "  cd $ROOT_DIR/docker-compose"
    echo "  docker compose -f docker-compose.yml -f docker-compose.prod.yml restart web"
    echo ""
fi

exit 0
