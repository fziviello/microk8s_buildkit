#!/bin/bash

echo "🔄 Updating kubeconfig from VM..."

VM_IP=$(multipass info microk8s-buildkit | grep IPv4 | awk '{print $2}')
echo "VM IP: $VM_IP"

multipass exec microk8s-buildkit -- bash -c "sudo microk8s kubectl config view --raw | sed 's/127.0.0.1/$VM_IP/g' > /home/ubuntu/kubeconfig-microk8s"
multipass transfer microk8s-buildkit:/home/ubuntu/kubeconfig-microk8s ./kubeconfig-microk8s

if [ -f "./kubeconfig-microk8s" ]; then
    echo "✅ File copied successfully!"
    echo "File size: $(wc -l < ./kubeconfig-microk8s) lines"
    
    if grep -q "$VM_IP" ./kubeconfig-microk8s; then
        echo "✅ Correct IP in kubeconfig: $VM_IP"
        sleep 5
        KUBECONFIG=./kubeconfig-microk8s kubectl get nodes
        export KUBECONFIG=./kubeconfig-microk8s
        echo "🎉 KUBECONFIG set"
    else
        echo "❌ IP not updated in kubeconfig"
    fi
else
    echo "❌ Error: file not copied"
    exit 1
fi