# scripts/metallb-config.sh
#!/bin/bash
BASE=$(docker network inspect kind | jq -r '.[0].IPAM.Config[] | select(.Subnet | contains(".")) | .Subnet' | cut -d. -f1-3)
METALLB_IP_RANGE="${BASE}.200-${BASE}.250" envsubst < manifests/metallb/ipaddresspool.yaml.tpl | kubectl apply -f -