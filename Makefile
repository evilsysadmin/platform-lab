ARGOCD_VERSION := v3.4.2
ENVOY_GATEWAY_VERSION := v1.8.2
METALLB_VERSION := v0.15.2
CERT_MANAGER_VERSION := v1.20.1

.PHONY: kind argocd/setup argocd/password argocd/ui envoy-gateway metallb hosts cert-manager bootstrap

kind:
	kind create cluster --config kind/kind-config.yaml

bootstrap: namespace cert-manager envoy-gateway metallb argocd/setup hosts

namespace:
	kubectl apply -f manifests/namespace/

argocd/setup: namespace
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl apply -f manifests/argocd/
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
	kubectl wait --for=condition=ready pod -l	 app=metallb -n metallb-system --timeout=90s
	kubectl apply -f manifests/metallb/l2advertisement.yaml
	./scripts/metallb-config.sh

hosts:
	sudo sed -i '/argocd.lab/d' /etc/hosts
	@IP=$$(kubectl get gateway argocd-gateway -n argocd -o jsonpath='{.status.addresses[0].value}') && \
	echo "$$IP argocd.lab" | sudo tee -a /etc/hosts

cert-manager:
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=90s
	kubectl apply -f manifests/cert-manager/clusterissuer.yaml

wipe:
	kind delete cluster --name platform-lab

reset: wipe kind bootstrap
