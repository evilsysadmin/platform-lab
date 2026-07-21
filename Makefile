ARGOCD_VERSION := v3.4.2
ENVOY_GATEWAY_VERSION := v1.8.2
METALLB_VERSION := v0.15.2
CERT_MANAGER_VERSION := v1.20.1

.PHONY: kind argocd/setup argocd/password argocd/ui envoy-gateway metallb hosts cert-manager bootstrap


dependencies:
	sudo nvidia-ctk runtime configure --runtime=docker --set-as-default --cdi.enabled
	sudo nvidia-ctk config --set accept-nvidia-visible-devices-as-volume-mounts=true --in-place
	sudo systemctl restart docker
	go install github.com/NVIDIA/nvkind/cmd/nvkind@latest
	helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
	helm repo update	

nvkind:
	nvkind cluster create --name platform-lab --config-template kind/nvkind-config.yaml

bootstrap: nvkind namespace cert-manager envoy-gateway metallb argocd/setup hosts rag/configure

registry/create:
	docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2 || true
	docker network connect kind kind-registry || true

namespace:
	kubectl apply -f manifests/namespace/

argocd/setup:
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl apply -f manifests/argocd/          # DESPUÉS del install — sobreescribe
	kubectl rollout restart deployment argocd-server -n argocd
	kubectl rollout status deployment argocd-server -n argocd
	kubectl apply -f manifests/cert-manager/argocd-cert.yaml
	kubectl apply -f argocd/apps/root.yaml

argocd/password:
	@kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo

argocd/ui:
	open http://argocd.lab

envoy-gateway:
	kubectl apply --server-side --force-conflicts \
		-f https://github.com/envoyproxy/gateway/releases/download/$(ENVOY_GATEWAY_VERSION)/install.yaml
	kubectl apply -f manifests/gateway/

metallb:
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/$(METALLB_VERSION)/config/manifests/metallb-native.yaml
	kubectl wait --for=condition=ready pod -l	 app=metallb -n metallb-system --timeout=100s
	kubectl apply -f manifests/metallb/l2advertisement.yaml
	./scripts/metallb-config.sh

hosts:
	sudo sed -i '/argocd.lab/d' /etc/hosts
	sudo sed -i '/rag.lab/d' /etc/hosts
	@echo "Waiting for argocd gateway..."
	kubectl wait --for=jsonpath='{.status.addresses[0].value}' \
		gateway/argocd-gateway -n argocd --timeout=120s
	@IP=$$(kubectl get gateway argocd-gateway -n argocd \
		-o jsonpath='{.status.addresses[0].value}') && \
	echo "$$IP argocd.lab" | sudo tee -a /etc/hosts
	@echo "Waiting for ArgoCD to create RAG app..."
	until kubectl get application rag -n argocd 2>/dev/null; do \
		echo "RAG app not yet created, waiting..."; \
		sleep 10; \
	done
	kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
		application/rag -n argocd --timeout=300s
	kubectl wait --for=jsonpath='{.status.addresses[0].value}' \
		gateway/rag-gateway -n rag --timeout=120s
	@IP=$$(kubectl get gateway rag-gateway -n rag \
		-o jsonpath='{.status.addresses[0].value}') && \
	echo "$$IP rag.lab" | sudo tee -a /etc/hosts

cert-manager:
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml
	kubectl wait --for=condition=established crd/certificates.cert-manager.io --timeout=60s
	kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
	kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
	kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s
	until kubectl apply -f manifests/cert-manager/clusterissuer.yaml 2>/dev/null; do \
		echo "Waiting for cert-manager webhook..."; \
		sleep 5; \
	done

wipe:
	kind delete cluster --name platform-lab

reset: wipe nvkind bootstrap

rag/build:
	docker build -t localhost:5001/rag-api:latest rag/
	docker push localhost:5001/rag-api:latest
	kubectl rollout restart deployment/rag-api -n rag

rag/deploy: rag/build
	kubectl apply -f rag/k8s/

rag/rollout: rag/build rag/deploy
	kubectl rollout restart deployment/rag-api -n rag

rag/configure:
	@OLLAMA_IP=$$(docker network inspect kind | jq -r '.[0].IPAM.Config[] | select(.Subnet | contains(".")) | .Gateway') && \
	echo "Ollama IP: $$OLLAMA_IP" && \
	kubectl create configmap rag-config -n rag \
		--from-literal=OLLAMA_URL="http://$$OLLAMA_IP:11434" \
		--from-literal=OLLAMA_MODEL="llama3.2:3b" \
		--from-literal=OLLAMA_EMBED_MODEL="nomic-embed-text" \
		--dry-run=client -o yaml | kubectl apply -f -
	make rag/rollout