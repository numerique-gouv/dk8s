#!/bin/bash
#
#
set -e -o pipefail

if ! type "curl" > /dev/null; then
    echo "curl is required"
    exit 1
fi

# initArch discovers the architecture for this system.
initArch() {
  ARCH=$(uname -m)
  case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
  esac
}

# initOS discovers the operating system for this system.
initOS() {
  OS=$(uname|tr '[:upper:]' '[:lower:]')
}

# runs the given command as root (detects if we are root already)
runAsRoot() {
  if [ $EUID -ne 0 -a "$USE_SUDO" = "true" ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

# detect OS ARCH
initArch
initOS

# default version
export INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
export HELM_INSTALL_DIR="${HELM_INSTALL_DIR:-$INSTALL_DIR}"
export USE_SUDO="${USE_SUDO:-true}"

FORCE_INSTALL="${FORCE_INSTALL:-false}"

KIND_VERSION="${KIND_VERSION:-v0.22.0}"
KIND_BINARY="kind-${OS}-${ARCH}"
KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/${KIND_BINARY}"

KUBECTL_VERSION="${KUBECTL_VERSION:-v1.29.2}"
KUBECTL_RELEASE_VERSION="https://dl.k8s.io/release"
case "$KUBECTL_VERSION" in
    stable) KUBECTL_VERSION="$(curl -Lfs $KUBECTL_RELEASE_VERSION/stable.txt)" ;;
esac
KUBECTL_URL=${KUBECTL_RELEASE_VERSION}/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl

HELM_VERSION="${HELM_VERSION:-v3.14.2}"
HELM_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"

HELMFILE_VERSION="${HELMFILE_VERSION:-0.162.0}"
HELMFILE_URL="https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz"

MKCERT_VERSION="${MKCERT_VERSION:-v1.4.4}"
MKCERT_BINARY="mkcert-${MKCERT_VERSION}-${OS}-${ARCH}"
MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/${MKCERT_BINARY}"

AGE_VERSION="${AGE_VERSION:-v1.1.1}"
AGE_URL="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${OS}-${ARCH}.tar.gz"

SOPS_VERSION="${SOPS_VERSION:-v3.8.1}"
SOPS_BINARY="sops-${SOPS_VERSION}.${OS}.${ARCH}"
SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/${SOPS_BINARY}"

#
# default
docker_is_installed="false"
kind_is_installed="false"
kubectl_is_installed="false"
helm_is_installed="false"
helmfile_is_installed="false"
mkcert_is_installed="false"
age_is_installed="false"
sops_is_installed="false"

type docker && docker_is_installed="true"

if [[ "${FORCE_INSTALL}" == "false" ]]; then
  # check if exist
  type kind && kind_is_installed="true"
  type kubectl && kubectl_is_installed="true"
  type helm && helm_is_installed="true"
  type helmfile && helmfile_is_installed="true"
  type mkcert && mkcert_is_installed="true"
  type age && age_is_installed="true"
  type sops && sops_is_installed="true"
else
    echo "# force install ${FORCE_INSTALL}"
fi

if [[ "$docker_is_installed" == "false" ]];then
  echo "# Please install docker > 20.10.5"
  exit 1
fi
docker version

if [[ "$kind_is_installed" == "false" ]];then
  echo "# Install kind ${KIND_VERSION} from ${KIND_URL}"
  curl -LOs ${KIND_URL}
  runAsRoot mv ${KIND_BINARY} ${INSTALL_DIR}/kind
  runAsRoot chmod 755 ${INSTALL_DIR}/kind
fi
echo "# kind"
kind version

if [[ "$kubectl_is_installed" == "false" ]];then
  echo "# Install kubectl ${KUBECTL_VERSION} from ${KUBECTL_URL}"
  curl -LOs ${KUBECTL_URL}
  chmod +x kubectl
  runAsRoot mv kubectl ${INSTALL_DIR}/kubectl
  runAsRoot chmod 755 ${INSTALL_DIR}/kubectl
fi
echo "# kubectl"
kubectl version --client

if [[ "$helm_is_installed" == "false" ]];then
  echo "# Install helm ${HELM_VERSION} from ${HELM_URL}"
  curl -Ls ${HELM_URL} | bash -s -- -v ${HELM_VERSION}
  runAsRoot chmod 755 ${INSTALL_DIR}/helm
fi
echo "# helm"
helm version

if [[ "$helmfile_is_installed" == "false" ]];then
  echo "# Install helmfile ${HELMFILE_VERSION} from ${HELMFILE_URL}"
  curl -Ls ${HELMFILE_URL} | tar zxvf - helmfile
  runAsRoot mv helmfile ${INSTALL_DIR}/helmfile
  runAsRoot chmod 755 ${INSTALL_DIR}/helmfile
fi
echo "# helmfile"
helmfile --no-color -v

echo "# helmfile init"
helmfile init --force

if [[ "$mkcert_is_installed" == "false" ]];then
  echo "# Install mkcert ${MKCERT_VERSION} from ${MKCERT_URL}"
  curl -LOs ${MKCERT_URL}
  chmod +x ${MKCERT_BINARY}
  runAsRoot mv ${MKCERT_BINARY} ${INSTALL_DIR}/mkcert
  runAsRoot chmod 755 ${INSTALL_DIR}/mkcert
fi
echo "# mkcert"
mkcert -version

if [[ "$age_is_installed" == "false" ]];then
  echo "# Install age ${AGE_VERSION} from ${AGE_URL}"
  curl -Ls ${AGE_URL} | tar zxvf - age/age age/age-keygen
  runAsRoot mv age/age ${INSTALL_DIR}/age
  runAsRoot mv age/age-keygen ${INSTALL_DIR}/age-keygen
  runAsRoot chmod 755 ${INSTALL_DIR}/age ${INSTALL_DIR}/age-keygen
  rm -rf age
fi
echo "# age"
age --version
age-keygen --version

if [[ "$sops_is_installed" == "false" ]];then
  echo "# Install sops ${SOPS_VERSION} from ${SOPS_URL}"
  curl -LOs ${SOPS_URL}
  chmod +x ${SOPS_BINARY}
  runAsRoot mv ${SOPS_BINARY} ${INSTALL_DIR}/sops
  runAsRoot chmod 755 ${INSTALL_DIR}/sops
fi
echo "# sops"
sops -version

echo "# Install done"
