# Updating GitOps Manifests for Image Pull Secrets

## Quick Fix: Add imagePullSecrets to Deployments

After creating the Docker Hub secret in Minikube (see `MINIKUBE_IMAGEPULL_FIX.md`), update your GitOps repository.

## Option 1: Add imagePullSecrets Directly to Deployment

In your GitOps repo (`notesverb-gitops`), for each service's base deployment:

**File:** `services/api-gateway/base/deployment.yaml` (or similar)

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
      # Add this section
      imagePullSecrets:
      - name: dockerhub-secret
      containers:
      - name: api-gateway
        image: docker.io/fawaswebcastle/api-gateway:latest
        ports:
        - containerPort: 8080
        # ... rest of config
```

## Option 2: Use Kustomize to Add imagePullSecrets (Recommended)

This approach allows you to add imagePullSecrets without modifying base manifests.

**File:** `services/api-gateway/overlays/dev/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

images:
- name: docker.io/fawaswebcastle/api-gateway
  newTag: latest

# Add imagePullSecrets using patches
patches:
- patch: |-
    - op: add
      path: /spec/template/spec/imagePullSecrets
      value:
      - name: dockerhub-secret
  target:
    kind: Deployment
    name: api-gateway
```

Or using a simpler approach with `patchesStrategicMerge`:

**File:** `services/api-gateway/overlays/dev/imagepullsecret-patch.yaml`

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
```

**File:** `services/api-gateway/overlays/dev/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

images:
- name: docker.io/fawaswebcastle/api-gateway
  newTag: latest

patchesStrategicMerge:
- imagepullsecret-patch.yaml
```

## Option 3: Create ServiceAccount (Best for Multiple Services)

### Step 1: Create ServiceAccount Base

**File:** `services/api-gateway/base/serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway-sa
imagePullSecrets:
- name: dockerhub-secret
```

### Step 2: Reference in Kustomization

**File:** `services/api-gateway/base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- serviceaccount.yaml  # Add this
```

### Step 3: Update Deployment to Use ServiceAccount

**File:** `services/api-gateway/base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  template:
    spec:
      serviceAccountName: api-gateway-sa  # Add this
      containers:
      - name: api-gateway
        image: docker.io/fawaswebcastle/api-gateway:latest
        # ... rest of config
```

## Option 4: Global ServiceAccount (For All Services)

If you want to use the same ServiceAccount for all services:

**File:** `services/base/serviceaccount.yaml` (in GitOps repo root)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: default  # or use namespace overlay
imagePullSecrets:
- name: dockerhub-secret
```

Then reference it in each service's deployment.

## Apply to All Services

You need to update these services:
- `api-gateway`
- `auth-service`
- `notes-service`
- `tags-service`
- `user-service`

### Quick Script to Update All Services

```bash
# In your GitOps repository
cd services

for service in api-gateway auth-service notes-service tags-service user-service; do
  echo "Updating $service..."
  
  # Create patch file if using Option 2
  cat > $service/overlays/dev/imagepullsecret-patch.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service
spec:
  template:
    spec:
      imagePullSecrets:
      - name: dockerhub-secret
EOF
  
  # Update kustomization.yaml to include patch
  # (Manual step - add patchesStrategicMerge entry)
done
```

## Verify Changes

After updating GitOps manifests:

1. **Commit and push to GitOps repo:**
   ```bash
   git add .
   git commit -m "Add imagePullSecrets for Docker Hub authentication"
   git push origin main
   ```

2. **Sync ArgoCD application:**
   ```bash
   # Via ArgoCD CLI
   argocd app sync <app-name>
   
   # Or via ArgoCD UI: Click "Sync" button
   ```

3. **Verify pods are running:**
   ```bash
   kubectl get pods
   kubectl describe pod <pod-name>  # Check events
   ```

## Troubleshooting

### Secret Not Found Error

If you see `secrets "dockerhub-secret" not found`:

1. Verify secret exists in the namespace:
   ```bash
   kubectl get secret dockerhub-secret -n <namespace>
   ```

2. Ensure namespace matches between secret and deployment

3. Create secret in the correct namespace:
   ```bash
   kubectl create secret docker-registry dockerhub-secret \
     --docker-server=docker.io \
     --docker-username=YOUR_USERNAME \
     --docker-password=YOUR_PASSWORD \
     --docker-email=YOUR_EMAIL \
     --namespace=<namespace>
   ```

### Still Getting ImagePullBackOff

1. **Check secret credentials:**
   ```bash
   kubectl get secret dockerhub-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
   ```

2. **Verify image exists:**
   ```bash
   docker pull docker.io/fawaswebcastle/api-gateway:latest
   ```

3. **Check Docker Hub rate limits:**
   - Anonymous: 100 pulls/6 hours
   - Authenticated: 200 pulls/6 hours

4. **Test manual pull in Minikube:**
   ```bash
   minikube ssh
   docker login -u YOUR_USERNAME -p YOUR_PASSWORD
   docker pull docker.io/fawaswebcastle/api-gateway:latest
   ```

## Best Practices

1. ✅ **Use ServiceAccount** for multiple services (Option 3)
2. ✅ **Use specific image tags** instead of `latest` in production
3. ✅ **Create secret in each namespace** where services run
4. ✅ **Use Kustomize overlays** to manage different environments
5. ✅ **Consider private registry** (Harbor, GitLab Registry) for production




