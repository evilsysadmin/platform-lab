# manifests/metallb/ipaddresspool.yaml.tpl
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
    - ${METALLB_IP_RANGE}
