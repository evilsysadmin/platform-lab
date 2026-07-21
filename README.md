# platform-lab

A local Kubernetes platform built for learning and experimentation, 
covering the full stack from infrastructure to AI workloads.

## Stack

- **Kind** — local Kubernetes cluster
- **ArgoCD** — GitOps, App of Apps pattern
- **Envoy Gateway** — Gateway API (replacing deprecated ingress-nginx)
- **MetalLB** — LoadBalancer for bare-metal/local clusters
- **cert-manager** — TLS certificate management
- **OpenTelemetry + Grafana + Loki + Tempo** — full observability stack _(coming)_
- **Ollama + RAG** — local LLM inference and retrieval _(coming)_
- **Envoy AI Gateway** — LLM traffic management _(coming)_

## Ollama (Local LLM)

Ollama runs on the host machine with GPU acceleration, accessible from the Kind cluster at `http://172.21.0.1:11434`.

### Setup

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Configure to listen on all interfaces
sudo mkdir -p /etc/systemd/system/ollama.service.d/
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# Pull model
ollama pull llama3.2:3b
```

## Getting started

```bash
# Create the cluster and bootstrap the full stack
make bootstrap

# Get ArgoCD UI password
make argocd/password
```

ArgoCD UI available at https://argocd.lab (add to /etc/hosts via `make hosts` - done automatically with `make bootstrap`)

## GPU Support (WIP)

GPU support via [nvkind](https://github.com/NVIDIA/nvkind) is work in progress.
Currently investigating NVML library mounting in Kind nodes.

## Roadmap

- [v0.1 Foundation](https://github.com/evilsysadmin/platform-lab/milestone/1) ✅
- [v0.2 Observability](https://github.com/evilsysadmin/platform-lab/milestone/2)
- [v0.3 AI Stack](https://github.com/evilsysadmin/platform-lab/milestone/3)
