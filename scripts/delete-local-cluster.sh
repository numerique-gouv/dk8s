#!/bin/sh

set -o errexit

# remove helm repo
HELM_REPO="prometheus-community grafana argo-cd"
helm repo remove "${HELM_REPO}" || true

# delete cluster
cluster_name="dk8s"
kind delete cluster -n "${cluster_name}" || true

# 1. Create registry container unless it already exists
reg_name="kind-registry"
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" == 'true' ]; then
	docker rm -v -f "${reg_name}" || true
fi

# remove network
docker network rm kind || true

cat <<EOF
=======================================

Your local ${cluster_name} cluster is destroyed...

=======================================
EOF
