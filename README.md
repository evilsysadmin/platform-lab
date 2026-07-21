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
