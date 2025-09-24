#!/bin/bash

export KUBECONFIG=./kubeconfig-microk8s

echo "🚀 Starting ALL dashboards..."

# Stop any previous port-forward processes
pkill -f "port-forward"

# 1. Kubernetes Dashboard (port 443 → 8443)
echo "📊 Kubernetes Dashboard: https://localhost:8443"
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443 &

# 2. Grafana (port 80 → 3000)
echo "📈 Grafana: http://localhost:3000"
kubectl port-forward -n observability svc/kube-prom-stack-grafana 3000:80 &

# 3. Prometheus (port 9090 → 9090)  
echo "🎯 Prometheus: http://localhost:9090"
kubectl port-forward -n observability svc/kube-prom-stack-kube-prome-prometheus 9090:9090 &

# 4. Traefik (port 9000 → 9000)
echo "🌐 Traefik: http://localhost:9000/dashboard/"
TRAEFIK_POD=$(kubectl get pods -n traefik -o name | head -1)
kubectl port-forward -n traefik $TRAEFIK_POD 9000:9000 &

# 5. My Applications
echo "🚀 My Applications:"
if kubectl get svc -n app-py pyapi &>/dev/null; then
    echo "📦 pyapi: http://localhost:4000"
    kubectl port-forward -n app-py service/pyapi 4000:4000 &
else
    echo "ℹ️  pyapi service not found in app-py namespace"
fi

if kubectl get svc -n app-nj njapi &>/dev/null; then
    echo "📦 njapi: http://localhost:5000"
    kubectl port-forward -n app-nj service/njapi 5000:5000 &
else
    echo "ℹ️  njapi service not found in app-nj namespace"
fi

sleep 3

echo ""
echo "🎉 ALL dashboards are available!"
echo ""
echo "🔗 Dashboard URLs:"
echo "   - Kubernetes Dashboard: https://localhost:8443"
echo "   - Grafana:              http://localhost:3000"
echo "   - Prometheus:           http://localhost:9090"
echo "   - Traefik:              http://localhost:9000/dashboard/#"
echo ""
echo "🚀 Application URLs:"
echo "   - pyapi:                http://localhost:4000/health"
echo "   - njapi:                http://localhost:5000/health"
echo ""

# --- Kubernetes Dashboard token ---
echo "🔐 Kubernetes Dashboard Token:"
kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || echo "Run first: kubectl -n kubernetes-dashboard create token admin-user"

# --- Grafana Dashboard user ---
echo ""
log_info "🔐 Grafana Dashboard:"
echo "👤 User:"
kubectl get secret kube-prom-stack-grafana -n observability -o jsonpath="{.data.admin-user}" | base64 -d; echo
echo "🔐 Password:"
kubectl get secret kube-prom-stack-grafana -n observability -o jsonpath="{.data.admin-password}" | base64 -d; echo

echo ""
echo "⏹️  To stop everything: pkill -f 'port-forward'"