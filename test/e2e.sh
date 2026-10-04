#!/usr/bin/env bash
# End-to-end test of the repository: build and publish every recipe to a
# local registry, serve the index, and install every package into a bare
# kind cluster with the kubepkg CLI and operator.
#
# Needs docker, kind, kubectl, go, python3 and a kubepkg checkout
# (KUBEPKG_DIR, default ../kubepkg). Leaves nothing behind unless KEEP=1.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
KUBEPKG_DIR=$(cd "${KUBEPKG_DIR:-${ROOT}/../kubepkg}" && pwd)
WORK=$(mktemp -d)
CLUSTER=kubepkg-recipes
REG_NAME=kubepkg-recipes-registry
REG_PORT=${REG_PORT:-5003}
WWW_PORT=${WWW_PORT:-5004}
KCTX=kind-${CLUSTER}
K="kubectl --context ${KCTX}"
KP=("${KUBEPKG_DIR}/bin/kubepkg" --context "${KCTX}")
OPLOG=${WORK}/operator.log

step() { printf '\n=== %s\n' "$*"; }
fail() { echo "FAIL: $*"; echo "--- operator log (tail)"; tail -n 60 "${OPLOG}" || true; exit 1; }
cleanup() {
  [[ -n "${OP_PID:-}" ]] && kill "${OP_PID}" 2>/dev/null || true
  [[ -n "${WWW_PID:-}" ]] && kill "${WWW_PID}" 2>/dev/null || true
  if [[ "${KEEP:-0}" != 1 ]]; then
    kind delete cluster --name "${CLUSTER}" >/dev/null 2>&1 || true
    docker rm -f "${REG_NAME}" >/dev/null 2>&1 || true
    rm -rf "${WORK}"
  else
    echo "kept: cluster ${CLUSTER}, registry localhost:${REG_PORT}, workdir ${WORK}"
  fi
}
trap cleanup EXIT

ready() {
  local pkg=$1 timeout=${2:-900}
  for ((i = 0; i < timeout; i += 5)); do
    [[ "$(${K} get packages.kubepkg.dev "${pkg}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" == True ]] && { echo "  ${pkg}: ready"; return 0; }
    sleep 5
  done
  fail "${pkg} not ready: $(${K} get packages.kubepkg.dev "${pkg}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')"
}

step "build kubepkg"
(cd "${KUBEPKG_DIR}" && go build -o bin/ ./cmd/...)

step "publish every recipe to a local registry"
docker rm -f "${REG_NAME}" >/dev/null 2>&1 || true
docker run -d --restart=no -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" registry:2 >/dev/null
REGISTRY="oci://localhost:${REG_PORT}/kubepkg-packages" KUBEPKG="${KUBEPKG_DIR}/bin/kubepkg" KUBEPKG_FLAGS=--plain-http \
  OUT="${WORK}/site" "${ROOT}/scripts/build-all.sh" >"${WORK}/build.log" 2>&1 || { cat "${WORK}/build.log"; fail "build"; }
python3 -m http.server "${WWW_PORT}" --bind 127.0.0.1 --directory "${WORK}/site" >/dev/null 2>&1 &
WWW_PID=$!

step "bare cluster with the kubepkg operator"
kind delete cluster --name "${CLUSTER}" >/dev/null 2>&1 || true
kind create cluster --name "${CLUSTER}" --wait 120s >/dev/null
${K} apply -f "${KUBEPKG_DIR}/config/crd" >/dev/null
kind get kubeconfig --name "${CLUSTER}" > "${WORK}/kubeconfig"
"${KUBEPKG_DIR}/bin/kubepkg-operator" --kubeconfig "${WORK}/kubeconfig" --plain-http --cache-dir "${WORK}/cache" \
  --metrics-bind-address 0 --health-probe-bind-address 0 >"${OPLOG}" 2>&1 &
OP_PID=$!
sleep 3
kill -0 "${OP_PID}" || fail "operator did not start"

step "subscribe and look around"
for ((i = 0; i < 20; i++)); do curl -sf "http://127.0.0.1:${WWW_PORT}/index.yaml" >/dev/null && break; sleep 0.5; done
"${KP[@]}" repo add main "http://127.0.0.1:${WWW_PORT}/index.yaml"
"${KP[@]}" search
"${KP[@]}" plan virtualization

step "install everything"
"${KP[@]}" install cert-manager metrics-server kube-state-metrics virtualization --yes
# kind has no /dev/kvm and its kubelets serve self-signed certificates.
${K} patch packages.kubepkg.dev kubevirt --type merge -p '{"spec":{"components":{"kubevirt":{"values":{"emulation":true}}}}}' >/dev/null
${K} patch packages.kubepkg.dev metrics-server --type merge -p '{"spec":{"components":{"metrics-server":{"values":{"args":["--kubelet-insecure-tls"]}}}}}' >/dev/null
for p in cert-manager metrics-server kube-state-metrics cdi kubevirt virtualization; do ready "${p}"; done
[[ "$(${K} get packages.kubepkg.dev kubevirt -o jsonpath='{.spec.version}')" == "~1.9" ]] || fail "kubevirt does not follow the constraint of the virtualization meta package"
${K} -n kubevirt wait kubevirt/kubevirt --for=condition=Available --timeout=15m >/dev/null || fail "KubeVirt not Available"
${K} wait cdi/cdi --for=condition=Available --timeout=15m >/dev/null || fail "CDI not Available"
for ((i = 0; i < 60; i++)); do ${K} top nodes >/dev/null 2>&1 && break; sleep 5; done
${K} top nodes >/dev/null 2>&1 || fail "metrics-server does not serve metrics"
"${KP[@]}" list

step "remove everything"
${K} delete packages.kubepkg.dev virtualization kubevirt cdi kube-state-metrics metrics-server cert-manager --wait --timeout 900s >/dev/null || fail "packages not removed"

echo
echo "PASS"
