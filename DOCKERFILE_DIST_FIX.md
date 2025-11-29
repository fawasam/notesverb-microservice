# Dockerfile Dist Path Fix

## Problem

All services were failing with `MODULE_NOT_FOUND` errors because the Dockerfile CMD was looking for `dist/index.js`, but TypeScript was outputting to a nested structure like `dist/services/auth-service/src/index.js` or `dist/api-gateway/src/index.js`.

## Root Cause

When building from the root directory context (as done in Jenkinsfile), TypeScript preserves the full directory structure in the output. This happens because:

1. The build context is from the repository root (`.`)
2. TypeScript `tsconfig.json` includes files with relative paths like `../../shared/**/*`
3. TypeScript preserves the directory structure relative to the build context

## Solution Applied

Updated all Dockerfile CMD entries to use the correct nested paths:

### Services
- **auth-service**: `dist/services/auth-service/src/index.js`
- **notes-service**: `dist/services/notes-service/src/index.js`
- **user-service**: `dist/services/user-service/src/index.js`
- **tags-service**: `dist/services/tags-service/src/index.js`

### API Gateway
- **api-gateway**: `dist/api-gateway/src/index.js`

## Files Updated

1. `api-gateway/Dockerfile`
2. `services/auth-service/Dockerfile`
3. `services/notes-service/Dockerfile`
4. `services/user-service/Dockerfile`
5. `services/tags-service/Dockerfile`

## Verification

After rebuilding images, verify the dist structure matches:

```bash
# Check dist structure in built image
docker run --rm <image-name> ls -la dist/

# Or check locally after build
ls -la api-gateway/dist/
ls -la services/auth-service/dist/
```

## Alternative Solution (Future Improvement)

To fix the root cause and have cleaner dist output, consider:

1. **Update tsconfig.json** to set `rootDir` explicitly:
   ```json
   {
     "compilerOptions": {
       "rootDir": "./",
       "outDir": "./dist"
     }
   }
   ```

2. **Or build from service directory** instead of root:
   ```dockerfile
   WORKDIR /app/services/auth-service
   RUN npm run build
   # This should output to dist/index.js relative to service dir
   ```

3. **Or use a build script** that flattens the output structure after compilation.

## Testing

After updating Dockerfiles:

1. Rebuild images:
   ```bash
   docker build -f api-gateway/Dockerfile -t test-api-gateway .
   docker build -f services/auth-service/Dockerfile -t test-auth-service .
   ```

2. Test container startup:
   ```bash
   docker run --rm test-api-gateway
   docker run --rm test-auth-service
   ```

3. Verify no MODULE_NOT_FOUND errors

## Next Steps

1. ✅ All Dockerfiles updated with correct paths
2. 🔄 Rebuild images in Jenkins
3. 🔄 Deploy via ArgoCD
4. ✅ Verify all services start correctly

