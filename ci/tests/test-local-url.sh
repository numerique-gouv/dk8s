#!/bin/bash
#
set -e -o pipefail

echo "Test local urls"

echo "# https://grafana.127.0.0.1.nip.io"
curl -Lsv https://grafana.127.0.0.1.nip.io 2>&1 |grep "<title>Grafana</title>"
echo "# https://argocd.127.0.0.1.nip.io"
curl -Lsv https://argocd.127.0.0.1.nip.io  2>&1 |grep "<title>Argo CD</title>"
