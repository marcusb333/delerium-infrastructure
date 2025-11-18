# Client Build Guide

## Overview

The Delirium client is written in TypeScript and must be compiled to JavaScript before deployment. This guide explains why this is necessary and how to build the client.

## Why Build is Required

The client repository contains TypeScript source files in the `src/` directory:
```
delerium-client/
├── src/
│   ├── app.ts
│   ├── delete.ts
│   ├── security.ts
│   ├── core/
│   ├── features/
│   ├── infrastructure/
│   ├── ui/
│   └── utils/
└── index.html (references js/app.js)
```

The HTML files reference compiled JavaScript modules in the `js/` directory, which don't exist until you build:
```html
<script type="module" src="js/app.js"></script>
```

**Without building, the buttons and interactive features won't work!**

## Quick Build

### Option 1: Use the Build Script (Recommended)
```bash
./scripts/build-client.sh
```

This script will:
- Check for Node.js and npm
- Install dependencies
- Build TypeScript to JavaScript
- Verify the output
- Provide instructions for restarting Docker containers

### Option 2: Manual Build
```bash
cd ../delerium-client
npm install
npm run build
```

### Option 3: Integrated Setup
The setup script now includes client building:
```bash
cd .
./scripts/setup.sh
```

## Build Output

After building, you'll have:
```
delerium-client/
├── js/
│   ├── app.js
│   ├── app.js.map
│   ├── delete.js
│   ├── security.js
│   ├── core/
│   ├── features/
│   ├── infrastructure/
│   ├── ui/
│   │   ├── dom-helpers.js
│   │   └── ui-manager.js
│   └── utils/
└── src/ (original TypeScript files)
```

## Prerequisites

### Required
- **Node.js** 18+ (v20+ recommended)
- **npm** (comes with Node.js)

### Check Installation
```bash
node --version   # Should show v18.x.x or higher
npm --version    # Should show 9.x.x or higher
```

### Install Node.js
If Node.js is not installed:

**Ubuntu/Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**macOS:**
```bash
brew install node
```

**Or download from:** https://nodejs.org/

## Development Workflow

### Watch Mode
For active development, use watch mode to automatically rebuild on changes:
```bash
cd ../delerium-client
npm run watch
```

This will continuously monitor for file changes and rebuild automatically.

### After Making Changes
1. Edit TypeScript files in `src/`
2. Build: `npm run build` (or use watch mode)
3. Restart web container:
   ```bash
   cd ./docker-compose
   docker compose -f docker-compose.yml -f docker-compose.prod.yml restart web
   ```

## Troubleshooting

### Build Fails with "npm not found"
**Solution:** Install Node.js (see Prerequisites above)

### Build Fails with "Cannot find module"
**Solution:** Clean install dependencies
```bash
cd ../delerium-client
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Buttons Still Don't Work After Build
**Solution:** Restart the web container
```bash
cd ./docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart web
```

Then clear your browser cache (Ctrl+Shift+R or Cmd+Shift+R)

### "js/ directory not found" Error
**Solution:** The build didn't complete. Check for errors:
```bash
cd ../delerium-client
npm run build 2>&1 | tee build.log
```

Review `build.log` for specific errors.

### TypeScript Errors During Build
**Solution:** Check TypeScript version and fix errors
```bash
cd ../delerium-client
npm run typecheck  # Check for type errors without building
```

## Build Configuration

The build is configured in `tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "outDir": "./js",
    "rootDir": "./src",
    "sourceMap": true
  }
}
```

Key settings:
- **outDir**: Output directory for compiled JavaScript (`js/`)
- **rootDir**: Source directory for TypeScript files (`src/`)
- **sourceMap**: Generates `.map` files for debugging

## Automated Deployment

### Setup Script Integration
The `setup.sh` script now automatically:
1. Checks for Node.js
2. Installs dependencies
3. Builds the client
4. Deploys with Docker

### CI/CD Integration
For automated deployments, add to your CI/CD pipeline:
```yaml
- name: Build Client
  run: |
    cd delerium-client
    npm ci
    npm run build
```

## Production Considerations

### Pre-built Images
For production, consider building the client as part of your Docker image:
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/js /usr/share/nginx/html/js
COPY --from=builder /app/*.html /usr/share/nginx/html/
```

### Build Optimization
For production builds, you can:
1. Minify JavaScript (add to build script)
2. Remove source maps (set `sourceMap: false` in tsconfig.json)
3. Use tree-shaking to reduce bundle size

## Quick Reference

| Command | Purpose |
|---------|---------|
| `npm install` | Install dependencies |
| `npm run build` | Build TypeScript to JavaScript |
| `npm run watch` | Build and watch for changes |
| `npm run typecheck` | Check types without building |
| `./scripts/build-client.sh` | Automated build script |

## Related Documentation

- [Setup Guide](SETUP_GUIDE.md) - Complete setup instructions
- [Deployment Guide](DEPLOYMENT.md) - Production deployment
- [Button Fix Documentation](BUTTON_FIX.md) - Original issue resolution

---
Last updated: 2025-11-18
