# Fixing ImagePullBackOff in Minikube with ArgoCD

## Problem

ArgoCD in Minikube cannot pull images from Docker Hub (`docker.io/fawaswebcastle/api-gateway:latest`), resulting in `ImagePullBackOff` errors.

## Root Causes

1. **Docker Hub Authentication**: Images may be private or require authentication
2. **Docker Hub Rate Limiting**: Anonymous pulls are rate-limited
3. **Minikube VM Isolation**: Minikube runs in a VM and doesn't have access to host Docker credentials

## Solutions

### Solution 1: Create Docker Registry Secret in Minikube (Recommended)

#### Step 1: Create Kubernetes Secret for Docker Hub

```bash
# Get your Docker Hub credentials
# Replace USERNAME and PASSWORD with your Docker Hub credentials
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_PASSWORD \
  --docker-email=YOUR_EMAIL \
  --namespace=default

# If using a different namespace (e.g., argocd)
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_PASSWORD \
  --docker-email=YOUR_EMAIL \
  --namespace=argocd
```

#### Step 2: Update GitOps Manifests to Use imagePullSecrets

In your GitOps repository (`notesverb-gitops`), update the deployment manifests to include `imagePullSecrets`.

For each service's deployment (in `base/deployment.yaml` or similar), add:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  template:
    spec:
      imagePullSecrets:
        - name: dockerhub-secret
      containers:
        - name: api-gateway
          image: docker.io/fawaswebcastle/api-gateway:latest
          # ... rest of config
```

#### Step 3: Apply to All Namespaces

If ArgoCD deploys to multiple namespaces, create the secret in each:

```bash
# List all namespaces
kubectl get namespaces

# Create secret in each namespace
for ns in default argocd production staging; do
  kubectl create secret docker-registry dockerhub-secret \
    --docker-server=docker.io \
    --docker-username=YOUR_DOCKERHUB_USERNAME \
    --docker-password=YOUR_DOCKERHUB_PASSWORD \
    --docker-email=YOUR_EMAIL \
    --namespace=$ns \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

### Solution 2: Configure Minikube to Use Host Docker Credentials

#### Option A: Use Minikube's Docker Daemon (Easier for Development)

```bash
# Configure Minikube to use host Docker daemon
minikube start --driver=docker

# Or if already running, restart with Docker driver
minikube stop
minikube start --driver=docker

# Load images directly into Minikube
minikube image load docker.io/fawaswebcastle/api-gateway:latest
minikube image load docker.io/fawaswebcastle/auth-service:latest
minikube image load docker.io/fawaswebcastle/notes-service:latest
minikube image load docker.io/fawaswebcastle/tags-service:latest
minikube image load docker.io/fawaswebcastle/user-service:latest
```

#### Option B: Copy Docker Config to Minikube

```bash
# Copy Docker config from host to Minikube
minikube cp ~/.docker/config.json /home/docker/.docker/config.json

# Or use minikube mount
minikube mount ~/.docker:/home/docker/.docker
```

### Solution 3: Use ImagePullPolicy and Local Registry

#### Configure Minikube with Local Registry

```bash
# Start Minikube with registry
minikube start --insecure-registry="localhost:5000"

# Or use Minikube's built-in registry addon
minikube addons enable registry

# Push images to Minikube registry
# First, get Minikube IP
MINIKUBE_IP=$(minikube ip)
REGISTRY_PORT=5000

# Tag and push to Minikube registry
docker tag docker.io/fawaswebcastle/api-gateway:latest $MINIKUBE_IP:$REGISTRY_PORT/api-gateway:latest
docker push $MINIKUBE_IP:$REGISTRY_PORT/api-gateway:latest
```

### Solution 4: Use ServiceAccount with imagePullSecrets (Best for Production)

#### Step 1: Create Secret

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_PASSWORD \
  --docker-email=YOUR_EMAIL
```

#### Step 2: Create ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
imagePullSecrets:
  - name: dockerhub-secret
```

#### Step 3: Update Deployments to Use ServiceAccount

In your GitOps manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  template:
    spec:
      serviceAccountName: app-service-account
      containers:
        - name: api-gateway
          image: docker.io/fawaswebcastle/api-gateway:latest
```

## Quick Fix for Immediate Testing

### Verify Image Exists

```bash
# Check if image exists on Docker Hub
docker pull docker.io/fawaswebcastle/api-gateway:latest

# If pull succeeds locally, the issue is Minikube authentication
```

### Temporary Workaround: Use imagePullPolicy: Never

**⚠️ Warning: Only for testing, not production**

```yaml
containers:
  - name: api-gateway
    image: docker.io/fawaswebcastle/api-gateway:latest
    imagePullPolicy: Never # Uses local image only
```

Then load images into Minikube:

```bash
minikube image load docker.io/fawaswebcastle/api-gateway:latest
```

## Recommended Approach for Production

1. **Create Docker Hub secret in all namespaces** (Solution 1)
2. **Update GitOps manifests** to include `imagePullSecrets` or use a `ServiceAccount`
3. **Use specific image tags** instead of `latest` for better version control
4. **Consider using a private registry** (Harbor, GitLab Registry, etc.) for production

## Updating GitOps Repository

After creating the secret, update your GitOps repository structure:

```
services/
├── api-gateway/
│   ├── base/
│   │   ├── deployment.yaml  # Add imagePullSecrets here
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml
│       └── prod/
│           └── kustomization.yaml
```

### Example deployment.yaml with imagePullSecrets

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      imagePullSecrets:
        - name: dockerhub-secret
      containers:
        - name: api-gateway
          image: docker.io/fawaswebcastle/api-gateway:latest
          ports:
            - containerPort: 8080
          env:
            - name: NODE_ENV
              value: "production"
```

## Troubleshooting

### Check Pod Events

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Look for events like:

- `Failed to pull image`: Authentication issue
- `ImagePullBackOff`: Rate limiting or authentication
- `ErrImagePull`: Image doesn't exist or network issue

### Verify Secret

```bash
# Check if secret exists
kubectl get secret dockerhub-secret

# Verify secret details (base64 encoded)
kubectl get secret dockerhub-secret -o yaml
```

### Test Image Pull Manually

```bash
# SSH into Minikube
minikube ssh

# Try pulling image manually
docker pull docker.io/fawaswebcastle/api-gateway:latest
```

### Check Docker Hub Rate Limits

Docker Hub allows:

- **Anonymous**: 100 pulls per 6 hours per IP
- **Authenticated**: 200 pulls per 6 hours per user

If you're hitting rate limits, use authentication (Solution 1).

## Next Steps

1. ✅ Create Docker Hub secret in Minikube
2. ✅ Update GitOps manifests to use `imagePullSecrets`
3. ✅ Commit and push changes to GitOps repo
4. ✅ Sync ArgoCD application
5. ✅ Verify pods are running: `kubectl get pods`
