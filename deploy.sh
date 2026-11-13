#!/bin/bash

VERSION="1.0.0"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
IMAGE_TAG="${VERSION}-${TIMESTAMP}"
VM_NAME="microk8s-buildkit"

# ============================================
# Select project via input from keyboard
# ============================================
echo "=========================================="
echo "  Select the project to deploy"
echo "=========================================="
echo "  1) app-py  (pyapi)"
echo "  2) app-nj  (njapi)"
echo "  3) Exit"
echo "=========================================="
read -rp "Choice [1-3]: " CHOICE

case "$CHOICE" in
    1)
        NAMESPACE="app-py"
        PROJECT_DIR="pyapi-project"
        RELEASE_NAME="pyapi"
        ;;
    2)
        NAMESPACE="app-nj"
        PROJECT_DIR="njapi-project"
        RELEASE_NAME="njapi"
        ;;
    3|q|Q)
        echo "👋 Exit."
        exit 0
        ;;
    *)
        echo "❌ CHOICE not valid: '$CHOICE'"
        exit 1
        ;;
esac

echo ""
echo "🚀 Deploying $RELEASE_NAME - Version: $IMAGE_TAG"
echo "   Namespace:   $NAMESPACE"
echo "   Project dir: $PROJECT_DIR"
echo ""

# 1. Create namespace if needed
echo "📦 Creating namespace..."
kubectl create namespace $NAMESPACE 2>/dev/null || echo "ℹ️  Namespace already exists"

# 2. Clean and prepare directory on VM
echo "📁 Cleaning directory on VM..."
multipass exec $VM_NAME -- bash -c "
rm -rf /home/ubuntu/$PROJECT_DIR
mkdir -p /home/ubuntu/$PROJECT_DIR
"

# 3. Transfer files to VM
echo "📤 Transferring files..."
multipass transfer ./src/$RELEASE_NAME $VM_NAME:/home/ubuntu/$PROJECT_DIR/ --recursive
multipass transfer ./helm/$RELEASE_NAME $VM_NAME:/home/ubuntu/$PROJECT_DIR/ --recursive

# 4. Build with BuildKit
echo "🛠️ Building with BuildKit..."
multipass exec $VM_NAME -- bash -c "
cd /home/ubuntu/$PROJECT_DIR
sudo buildctl build --frontend dockerfile.v0 \
  --local context=./$RELEASE_NAME/ \
  --local dockerfile=./$RELEASE_NAME/ \
  --output type=image,name=localhost:32000/$RELEASE_NAME:$IMAGE_TAG,push=true
"

# 5. Deploy with Helm
echo "⚙️ Deploying with Helm..."
export KUBECONFIG=./kubeconfig-microk8s
helm upgrade --install $RELEASE_NAME ./helm/$RELEASE_NAME \
  --namespace $NAMESPACE \
  --set image.tag=$IMAGE_TAG \
  --set traefik.enabled=true \
  --set observability.enabled=true \
  --set metrics.serviceMonitor.enabled=false \
  --wait \
  --timeout 5m

# 6. Verification
echo "✅ Deployment verification..."
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get ingress -n $NAMESPACE

echo "🎉 Deploy completed! Version: $IMAGE_TAG"