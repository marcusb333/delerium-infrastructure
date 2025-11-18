# Button Fix - JavaScript Build Issue

## Problem
The buttons on the website were not working because the TypeScript source files were not compiled to JavaScript.

## Root Cause
The `delerium-client` repository contains TypeScript source files in the `src/` directory, but the HTML files reference compiled JavaScript files in the `js/` directory. The client was not built before deployment.

## Solution Applied

1. **Installed Dependencies**
   ```bash
   cd ../delerium-client
   npm install
   ```

2. **Built TypeScript to JavaScript**
   ```bash
   npm run build
   ```
   This compiled all TypeScript files from `src/` to JavaScript in `js/`

3. **Restarted Web Container**
   ```bash
   cd ./docker-compose
   docker compose -f docker-compose.yml -f docker-compose.prod.yml restart web
   ```

## Verification
All endpoints now return HTTP 200:
- ✅ Main page: https://delerium.cc
- ✅ JavaScript: https://delerium.cc/js/app.js
- ✅ API: https://delerium.cc/api/pow

## Files Created
The build process created the following structure:
```
../delerium-client/js/
├── app.js
├── delete.js
├── security.js
├── core/
├── features/
├── infrastructure/
├── ui/
│   ├── dom-helpers.js
│   └── ui-manager.js
└── utils/
```

## Future Deployments
When updating the client code, always run:
```bash
cd ../delerium-client
git pull
npm install
npm run build
docker compose -f ./docker-compose/docker-compose.yml \
  -f ./docker-compose/docker-compose.prod.yml restart web
```

---
Fixed: 2025-11-18
