#!/bin/bash

# Script to fix ImagePullBackOff in Minikube
# Usage: ./fix-minikube-imagepull.sh [namespace]

set -e

NAMESPACE=${1:-default}
SECRET_NAME="dockerhub-secret"

echo "🔧 Fixing ImagePullBackOff in Minikube"
echo "📦 Namespace: $NAMESPACE"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "❌ Minikube is not running. Please start minikube first:"
    echo "   minikube start"
    exit 1
fi

# Check if namespace exists, create if not
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "📝 Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
    else
        echo "✅ Using existing secret"
        exit 0
    fi
fi

# Prompt for Docker Hub credentials
echo "🔐 Please provide Docker Hub credentials:"
read -p "Docker Hub Username: " DOCKER_USERNAME
read -sp "Docker Hub Password: " DOCKER_PASSWORD
echo
read -p "Docker Hub Email: " DOCKER_EMAIL

# Create the secret
echo ""
echo "📝 Creating Docker registry secret..."
kubectl create secret docker-registry "$SECRET_NAME" \
  --docker-server=docker.io \
  --docker-username="$DOCKER_USERNAME" \
  --docker-password="$DOCKER_PASSWORD" \
  --docker-email="$DOCKER_EMAIL" \
  --namespace="$NAMESPACE"

if [ $? -eq 0 ]; then
    echo "✅ Secret created successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Update your GitOps manifests to include imagePullSecrets:"
    echo "   imagePullSecrets:"
    echo "   - name: $SECRET_NAME"
    echo ""
    echo "2. Or create a ServiceAccount with imagePullSecrets"
    echo ""
    echo "3. Sync your ArgoCD application"
    echo ""
    echo "💡 To create secret in multiple namespaces, run:"
    echo "   ./fix-minikube-imagepull.sh <namespace>"
else
    echo "❌ Failed to create secret"
    exit 1
fi



