.PHONY: kind

kind:
	kind create cluster --config kind/kind-config.yaml
