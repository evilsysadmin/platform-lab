# platform-lab

A local Kubernetes platform built for learning and experimentation,
covering the full stack from infrastructure to AI workloads.

## Stack

- **Kind** — local Kubernetes cluster (GPU support via nvkind)
- **ArgoCD** — GitOps, App of Apps pattern
- **Envoy Gateway** — Gateway API (replacing deprecated ingress-nginx)
- **MetalLB** — LoadBalancer for bare-metal/local clusters
- **cert-manager** — TLS certificate management
- **Ollama** — Local LLM inference with GPU acceleration
- **RAG API** — FastAPI + LangChain + ChromaDB document Q&A
- **RAG UI** — nginx reverse proxy + chat interface
- **OpenTelemetry + Grafana + Loki + Tempo** — full observability stack _(coming)_
- **Envoy AI Gateway** — LLM traffic management _(coming)_

## Architecture

Browser
↓
Envoy Gateway (MetalLB LoadBalancer)
↓
rag-ui (nginx — security headers, rate limiting, reverse proxy)
↓
rag-api (FastAPI + LangChain — internal ClusterIP only)
↓
Ollama (host, GPU) + ChromaDB (PVC)


ArgoCD manages all workloads via App of Apps pattern from this repo.

## Getting started

### Prerequisites

```bash
# One-time host setup (NVIDIA GPU support)
make dependencies
```

### Bootstrap

```bash
# Create cluster and deploy full stack
make bootstrap

# Get ArgoCD password
make argocd/password

# Configure RAG (dynamic Ollama host IP)
make rag/configure
```

### Local registry

```bash
# Start local registry (survives cluster resets)
make registry
```

### Build and deploy RAG

```bash
make rag/build      # build + push rag-api image
make rag-ui/rollout # build + push rag-ui image
```

### Reset everything

```bash
make reset  # wipe + recreate cluster + bootstrap
```

## Services

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.lab |
| RAG Chat | http://rag.lab |

Add to `/etc/hosts` via `make hosts`.

## Ollama Setup

Ollama runs on the host machine with GPU acceleration.

```bash
# Install
curl -fsSL https://ollama.com/install.sh | sh

# Configure to listen on all interfaces
sudo mkdir -p /etc/systemd/system/ollama.service.d/
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=24h"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# Pull models
ollama pull llama3.2:3b
ollama pull nomic-embed-text  # required for embeddings
```

## Roadmap

- [v0.1 Foundation](https://github.com/evilsysadmin/platform-lab/milestone/1)
- [v0.2 Observability](https://github.com/evilsysadmin/platform-lab/milestone/2)
- [v0.3 AI Stack](https://github.com/evilsysadmin/platform-lab/milestone/3) 