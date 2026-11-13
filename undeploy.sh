#!/bin/bash

VM_NAME="microk8s-buildkit"
DELETE_NAMESPACE=false

# ============================================
# Select project via input from keyboard
# ============================================
echo "=========================================="
echo "  Select the project to UNDEPLOY"
echo "=========================================="
echo "  1) app-py  (pyapi)"
echo "  2) app-nj  (njapi)"
echo "  3) Exit"
echo "=========================================="
read -rp "Choice [1-3]: " CHOICE

case "$CHOICE" in
    1)
        NAMESPACE="pyapi-namespace"
        PROJECT_DIR="pyapi-project"
        RELEASE_NAME="pyapi"
        ;;
    2)
        NAMESPACE="njapi-namespace"
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
echo "💥 COMPLETE UNDEPLOY of $RELEASE_NAME"
echo "   Namespace:   $NAMESPACE"
echo "   Project dir: $PROJECT_DIR"
echo "   Delete NS:   $DELETE_NAMESPACE"
echo ""

export KUBECONFIG=./kubeconfig-microk8s

# 1. Uninstall Helm release
echo "❌ Force uninstall Helm release..."
helm uninstall $RELEASE_NAME -n $NAMESPACE 2>/dev/null || echo "⚠️  Helm release not found or already removed"

# 2. Delete all resources in the namespace
echo "🗑️  Force deletion of all resources..."
kubectl delete all --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || echo "⚠️  No resources to delete"

# 3. Delete ingress, pvc, secrets, configmaps
echo "🧹 Cleaning additional resources..."
kubectl delete ingress,secret,configmap,pvc --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true

# 4. Delete namespace (only if DELETE_NAMESPACE=true)
if [ "$DELETE_NAMESPACE" = true ]; then
    echo "🔥 Force namespace deletion..."
    kubectl delete namespace $NAMESPACE --force --grace-period=0 2>/dev/null || echo "⚠️  Namespace not found or already deleted"
else
    echo "ℹ️  Namespace deletion skipped (DELETE_NAMESPACE=false)"
fi

# 5. Clean Docker images in the VM
echo "🐳 Force Docker images cleanup..."
multipass exec $VM_NAME -- bash -c "
# Remove $RELEASE_NAME images
sudo docker rmi -f \$(sudo docker images -q '$RELEASE_NAME*' 2>/dev/null) 2>/dev/null || true
# Remove images from local registry
sudo docker rmi -f \$(sudo docker images -q 'localhost:32000/$RELEASE_NAME*' 2>/dev/null) 2>/dev/null || true
# Remove dangling images
sudo docker rmi -f \$(sudo docker images -f 'dangling=true' -q 2>/dev/null) 2>/dev/null || true
echo '✅ Docker images cleaned'
"

# 6. Clean project directory in the VM
echo "📁 Cleaning project directory in VM..."
multipass exec $VM_NAME -- bash -c "
if [ -d '/home/ubuntu/$PROJECT_DIR' ]; then
    echo '🗑️  Deleting directory $PROJECT_DIR...'
    rm -rf /home/ubuntu/$PROJECT_DIR
    echo '✅ Directory $PROJECT_DIR deleted'
else
    echo 'ℹ️  Directory $PROJECT_DIR not found'
fi
"

# 7. Final verification
echo "🔍 Final status verification..."
if [ "$DELETE_NAMESPACE" = true ]; then
    kubectl get namespaces | grep "$NAMESPACE" || echo "✅ Namespace $NAMESPACE removed"
else
    echo "ℹ️  Namespace $NAMESPACE maintained"
fi

kubectl get pods -A | grep "$RELEASE_NAME" || echo "✅ No $RELEASE_NAME pod found"

# VM cleanup verification
echo "🔍 VM cleanup verification..."
multipass exec $VM_NAME -- bash -c "
echo '=== Remaining directories ==='
ls -la /home/ubuntu/ | grep '$PROJECT_DIR' || echo '✅ No $PROJECT_DIR directory found'
echo '=== Remaining Docker images ==='
sudo docker images | grep '$RELEASE_NAME' || echo '✅ No $RELEASE_NAME image found'
"

echo "💣 COMPLETE UNDEPLOY AND CLEANUP FINISHED!"