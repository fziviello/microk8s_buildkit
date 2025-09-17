# MicroK8s + BuildKit VM Setup

This guide explains how to create and configure a **Multipass VM** with **MicroK8s** and **BuildKit**, using **NFS for persistent volumes**, in order to build a **multi-language development environment**.

The structure of this project is designed to support multiple services:
- **src/** → source code of your applications (e.g., `njapi/`, `pyapi/`).
- **helm/** → corresponding Helm charts for deployment.

You can easily add new projects by creating folders in both `src/` and `helm/`, then updating `deploy.sh` with the project parameters. This allows you to scaffold, deploy, and manage **N projects** consistently.

👉 Multipass official page: [https://multipass.run](https://multipass.run)

---

## Table of Contents

- [MicroK8s + BuildKit VM Setup](#microk8s--buildkit-vm-setup)
  - [Table of Contents](#table-of-contents)
  - [VM Creation with Cloud-Init](#vm-creation-with-cloud-init)
  - [Manual Installation (Without Cloud-Init)](#manual-installation-without-cloud-init)
    - [Create the VM](#create-the-vm)
    - [Access the VM](#access-the-vm)
    - [Update System](#update-system)
    - [Install MicroK8s](#install-microk8s)
    - [Configure User](#configure-user)
    - [Enable Essential Addons](#enable-essential-addons)
    - [Expose Dashboards](#expose-dashboards)
      - [Traefik Dashboard](#traefik-dashboard)
      - [Kubernetes Dashboard (Admin Access)](#kubernetes-dashboard-admin-access)
    - [Install BuildKit](#install-buildkit)
    - [Create Systemd Service for BuildKit](#create-systemd-service-for-buildkit)
    - [Configure BuildKit Runtime](#configure-buildkit-runtime)
    - [Configure Aliases](#configure-aliases)
    - [Configure Kubeconfig](#configure-kubeconfig)
    - [OpenTelemetry Collector](#opentelemetry-collector)
  - [Local Machine Setup](#local-machine-setup)
    - [Export Kubeconfig](#export-kubeconfig)
    - [Load Kubeconfig](#load-kubeconfig)
    - [Verify Cluster](#verify-cluster)
  - [Deployments](#deployments)
    - [Deploy](#deploy)
    - [Check Status](#check-status)
    - [Undeploy](#undeploy)
    - [Verify Images](#verify-images)
  - [Port Forwarding \& API Test](#port-forwarding--api-test)
    - [Port Forward Services](#port-forward-services)
    - [Test APIs](#test-apis)
  - [Dashboards](#dashboards)
  - [Notes on NFS Volumes](#notes-on-nfs-volumes)

---

## VM Creation with Cloud-Init

```bash
multipass launch --name microk8s-buildkit --cpus 4 --memory 8G --disk 40G --cloud-init cloud-init.yaml --timeout 900
```

---

## Manual Installation (Without Cloud-Init)

### Create the VM
```bash
multipass launch --name microk8s-buildkit --cpus 4 --memory 8G --disk 20G
```

### Access the VM
```bash
multipass shell microk8s-buildkit
```

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Install MicroK8s
```bash
sudo snap install microk8s --classic --channel=1.28
```

### Configure User
```bash
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
sudo chown -f -R $USER ~/.kube
```

### Enable Essential Addons
```bash
sudo microk8s enable community
sudo microk8s enable dns
sudo microk8s enable storage
sudo microk8s enable registry
sudo microk8s enable traefik
sudo microk8s enable observability
```

### Expose Dashboards

#### Traefik Dashboard
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  ports:
  - name: dashboard
    port: 9000
    targetPort: 9000
  selector:
    app.kubernetes.io/name: traefik
EOF
```

#### Kubernetes Dashboard (Admin Access)
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

### Install BuildKit
```bash
BUILDKIT_VERSION="v0.12.2"
wget https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz
sudo tar -xzf buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz -C /usr/local --strip-components=1
rm buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz

sudo mv /usr/local/buildctl /usr/local/bin/
sudo mv /usr/local/buildkitd /usr/local/bin/
sudo chmod +x /usr/local/bin/buildctl
sudo chmod +x /usr/local/bin/buildkitd
```

### Create Systemd Service for BuildKit
```bash
sudo tee /etc/systemd/system/buildkit.service > /dev/null <<EOF
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --containerd-worker=true --containerd-worker-addr=/var/snap/microk8s/common/run/containerd.sock
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo apt install -y runc containerd
sudo systemctl daemon-reload
sudo systemctl enable buildkit
sudo systemctl start buildkit
sudo systemctl status buildkit
```

### Configure BuildKit Runtime
```bash
sudo mkdir -p /run/buildkit
sudo chown $USER:$USER /run/buildkit
sudo chmod 755 /run/buildkit
sudo buildkitd --oci-worker=true --containerd-worker=false --root /run/buildkit &
sudo buildctl --addr unix:///run/buildkit/buildkitd.sock debug workers
```

### Configure Aliases
```bash
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
echo "alias helm='microk8s helm'" >> ~/.bashrc
source ~/.bashrc
```

### Configure Kubeconfig
```bash
sudo microk8s kubectl config view --raw > ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
newgrp microk8s
```

### OpenTelemetry Collector
```bash
kubectl apply -f otel-collector.yaml
```

---

## Local Machine Setup

### Export Kubeconfig
```bash
./kubeconfig.sh
```

### Load Kubeconfig
```bash
KUBECONFIG=./kubeconfig-microk8s kubectl get nodes
export KUBECONFIG=./kubeconfig-microk8s
```

### Verify Cluster
```bash
kubectl config get-contexts
kubectl cluster-info
kubectl get nodes
```

---

## Deployments

### Deploy
```bash
./deploy.sh
```

### Check Status
```bash
./check-status.sh
```

### Undeploy
```bash
./undeploy.sh
```

### Verify Images
```bash
kubectl describe pods -n app-nj | grep Image:
kubectl describe pods -n app-py | grep Image:
```

---

## Port Forwarding & API Test

### Port Forward Services
```bash
kubectl port-forward -n app-py service/pyapi 4000:4000 &
kubectl port-forward -n app-nj service/njapi 5000:5000 &
```

### Test APIs
```bash
curl http://localhost:4000/health
curl http://localhost:4000/api/test-otel
curl http://localhost:5000/health
curl http://localhost:5000/api/test-otel
```

---

## Dashboards

To expose dashboards:
```bash
./dashboards.sh
```

---

## Notes on NFS Volumes

- MicroK8s uses **NFS-backed persistent volumes** to store data and models.
- Ensure the NFS server is running and accessible by all MicroK8s nodes.
- PVCs for each microservice are defined in the Helm charts and automatically mounted.