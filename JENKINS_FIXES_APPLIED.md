# Jenkins Pipeline Fixes Applied

This document summarizes all the fixes applied to get your Jenkins CI/CD pipeline working.

---

## Issues Encountered & Fixes

### 1. ✅ Docker Permission Denied

**Error:**
```
ERROR: permission denied while trying to connect to the Docker daemon socket
```

**Root Cause:** Jenkins user didn't have permission to access Docker daemon

**Fix Applied:**
```bash
sudo usermod -aG docker jenkins
sudo chmod 666 /var/run/docker.sock
sudo systemctl restart jenkins
```

**Status:** ✅ RESOLVED

---

### 2. ✅ Docker Build Context Error

**Error:**
```
ERROR: failed to calculate checksum: "/shared": not found
ERROR: failed to calculate checksum: "/api-gateway": not found
```

**Root Cause:** Jenkinsfile was running `docker build` from inside service directories, but Dockerfiles needed access to parent directories (`shared/` and service directories)

**Fix Applied:**
Changed Jenkinsfile build command from:
```groovy
dir(svc) {
  sh "docker build -t ${image} ."
}
```

To:
```groovy
sh "docker build -f ${svc}/Dockerfile -t ${image} ."
```

**Files Modified:**
- `Jenkinsfile` (line 26-38)

**Status:** ✅ RESOLVED

---

### 3. ✅ NPM Peer Dependency Conflicts

**Error:**
```
npm error ERESOLVE could not resolve
npm error Conflicting peer dependency: @types/express@4.17.25
```

**Root Cause:** `http-proxy-middleware@2.0.6` expects `@types/express@^4.17.13`, but project uses `@types/express@5.0.3`

**Fix Applied:**
Added `--legacy-peer-deps` flag to all `npm ci` commands in Dockerfiles

**Files Modified:**
- `api-gateway/Dockerfile` (line 16)
- `services/auth-service/Dockerfile` (line 16)
- `services/notes-service/Dockerfile` (line 16)
- `services/user-service/Dockerfile` (line 16)
- `services/tags-service/Dockerfile` (line 16)

**Status:** ✅ RESOLVED

---

## Summary of Changes

### Modified Files (7 total)

1. **Jenkinsfile**
   - Changed Docker build to use root context with `-f` flag
   - Allows Dockerfiles to access both `shared/` and service directories

2. **api-gateway/Dockerfile**
   - Added `--legacy-peer-deps` to `npm ci`

3. **services/auth-service/Dockerfile**
   - Added `--legacy-peer-deps` to `npm ci`

4. **services/notes-service/Dockerfile**
   - Added `--legacy-peer-deps` to `npm ci`

5. **services/user-service/Dockerfile**
   - Added `--legacy-peer-deps` to `npm ci`

6. **services/tags-service/Dockerfile**
   - Added `--legacy-peer-deps` to `npm ci`

7. **Server Configuration**
   - Jenkins user added to docker group
   - Docker socket permissions updated

---

## Next Steps

### 1. Commit Your Changes

```bash
git add Jenkinsfile api-gateway/Dockerfile services/*/Dockerfile
git commit -m "Fix Jenkins pipeline: Docker context and npm peer deps"
git push
```

### 2. Re-run Jenkins Pipeline

The pipeline should now:
- ✅ Build all Docker images successfully
- ✅ Push images to Docker Hub
- ✅ Update GitOps repository with new image tags

### 3. Monitor the Build

Watch for these stages to complete:
1. Checkout
2. Build & Push Images (all 5 services)
3. Update GitOps Repo - Dev
4. Update GitOps Repo - Staging/Prod (if on staging/main branch)

---

## Still TODO (From JENKINS_SETUP.md)

If you haven't done these yet:

- [ ] Add Docker Hub credentials to Jenkins
  - Credential ID: `docker-registry-credentials`
  - Add Docker login stage to Jenkinsfile

- [ ] Verify GitOps SSH key is configured
  - Credential ID: `gitops-ssh-key`
  - Deploy key added to GitHub with write access

- [ ] Install `yq` on Jenkins server
  ```bash
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
  ```

---

## Troubleshooting

### If Build Still Fails

1. **Check Docker Hub Authentication**
   - Verify credentials are correct
   - Consider adding explicit Docker login stage

2. **Check GitOps SSH Access**
   ```bash
   ssh -T git@github.com
   ```

3. **Verify yq Installation**
   ```bash
   yq --version
   ```

4. **Check Jenkins Logs**
   - Go to build → Console Output
   - Look for specific error messages

---

## Long-term Improvements

### Option 1: Fix Peer Dependencies Properly

Instead of using `--legacy-peer-deps`, update `api-gateway/package.json`:

```json
{
  "devDependencies": {
    "@types/express": "^4.17.21",  // Downgrade from 5.0.3
    // ... other deps
  }
}
```

Then remove `--legacy-peer-deps` from Dockerfiles.

### Option 2: Upgrade http-proxy-middleware

Update to a version that supports Express 5:
```json
{
  "dependencies": {
    "http-proxy-middleware": "^3.0.0",  // Upgrade from 2.0.6
    // ... other deps
  }
}
```

### Option 3: Add Docker Login to Pipeline

Add this stage after Checkout in Jenkinsfile:

```groovy
stage('Docker Login') {
  steps {
    script {
      withCredentials([usernamePassword(
        credentialsId: 'docker-registry-credentials',
        usernameVariable: 'DOCKER_USER',
        passwordVariable: 'DOCKER_PASS'
      )]) {
        sh 'echo $DOCKER_PASS | docker login docker.io -u $DOCKER_USER --password-stdin'
      }
    }
  }
}
```

---

## Reference Documents

- [JENKINS_SETUP.md](./JENKINS_SETUP.md) - Complete setup guide
- [Jenkinsfile](./Jenkinsfile) - CI/CD pipeline definition
- [Docker Documentation](https://docs.docker.com/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
