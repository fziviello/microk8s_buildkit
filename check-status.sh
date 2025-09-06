#!/bin/bash

echo "🔍 Cluster status:"

echo -e "\n📦 Namespaces:"
kubectl get namespaces

echo -e "\n🐳 Pods:"
kubectl get pods -A

echo -e "\n🌐 Traefik:"
kubectl get pods -n kube-system | grep traefik || echo "ℹ️  Traefik not found"
kubectl get service -n kube-system | grep traefik || echo "ℹ️  Traefik Service not found"

echo -e "\n📊 Observability:"
kubectl get pods -n observability 2>/dev/null || echo "ℹ️  observability namespace not found"
kubectl get all -n observability 2>/dev/null || echo "ℹ️  observability resources not found"

echo -e "\n📈 Monitoring:"
kubectl get pods -n monitoring 2>/dev/null || echo "ℹ️  monitoring namespace not found"
kubectl get all -n monitoring 2>/dev/null || echo "ℹ️  monitoring resources not found"

echo -e "\n🔎 Observability Components:"
kubectl get pods -A | grep -E "(prometheus|grafana|loki|tempo|observability)" || echo "ℹ️  Observability components not found"
kubectl get svc -A | grep -E "(prometheus|grafana|loki|tempo|observability)" || echo "ℹ️  Observability services not found"

echo -e "\n🚀 pyapi:"
kubectl get all -n pyapi-namespace 2>/dev/null || echo "ℹ️  pyapi-namespace not found"

echo -e "\n🔗 Ingress:"
kubectl get ingress -A

echo -e "\n📡 Services with metrics:"
kubectl get svc -A -o=jsonpath='{range .items[?(@.metadata.annotations.prometheus\.io/scrape)]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' || echo "ℹ️  No services with metrics enabled"