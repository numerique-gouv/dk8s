#!/bin/sh

KUBE_VERSION="${KUBE_VERSION:-v1.27.3}"
ARGOCD_VERSION="6.4.1"
KUBE_PROM_STACK_VERSION="56.9.0"
LOKI_VERSION="5.43.3"
PROMTAIL_VERSION="6.15.5"

set -o errexit

cd /tmp

# 0. Create ca
mkcert -install
mkcert "127.0.0.1.nip.io" "*.127.0.0.1.nip.io"

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
	docker run \
		-d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
		registry:2
fi

# 2. Create kind cluster with containerd registry config dir enabled
# TODO: kind will eventually enable this by default and this patch will
# be unnecessary.
#
# See:
# https://github.com/kubernetes-sigs/kind/issues/2875
# https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration
# See: https://github.com/containerd/containerd/blob/main/docs/hosts.md
cat <<EOF | kind create cluster -n dk8s --image "kindest/node:${KUBE_VERSION}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes); do
	docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
	cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
	docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx create secret tls mkcert --key 127.0.0.1.nip.io+1-key.pem --cert 127.0.0.1.nip.io+1.pem
kubectl -n ingress-nginx patch deployments.apps ingress-nginx-controller --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value":"--default-ssl-certificate=ingress-nginx/mkcert"}]'

sleep 30

kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo-cd https://argoproj.github.io/argo-helm

helm repo update

cat <<EOF | helm upgrade --install --version $LOKI_VERSION loki grafana/loki -f -
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'
singleBinary:
  replicas: 1
EOF
cat <<EOF | helm upgrade --install --version $KUBE_PROM_STACK_VERSION kube-prom-stack prometheus-community/kube-prometheus-stack -f -
grafana:
  ingress:
    enabled: true
    hosts:
      - grafana.127.0.0.1.nip.io
  additionalDataSources:
    - name: loki
      type: loki
      access: proxy
      url: http://loki:3100
EOF
cat <<EOF | helm upgrade --install --version $PROMTAIL_VERSION promtail grafana/promtail
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
EOF

cat <<EOF | helm upgrade --install --version $ARGOCD_VERSION argocd argocd/argo-cd -f -
global:
  domain: argocd.127.0.0.1.nip.io
configs:
  params:
    server.insecure: true
  secret:
    # admin / admin
    argocdServerAdminPassword: \$2a\$10\$y8BqLqjTaOyfKu3xv9L/UO3mi9NnpSeX8R.HQqWH9XDla0YLHDxW6
    argocdServerAdminPasswordMtime: "2023-12-01T10:11:12Z"
server:
  ingress:
    enabled: true
EOF

cat <<EOF
=======================================


Your local dk8s cluster is starting...

in few minutes you will be able to connect to :

https://grafana.127.0.0.1.nip.io -> admin / prom-operator
https://argocd.127.0.0.1.nip.io -> admin / admin



=======================================
EOF
