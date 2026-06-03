#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE must be set}"
SINCE="${SINCE:-10m}"
OUT_DIR="${OUT_DIR:-../coord-logs-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "${OUT_DIR}"

echo "==> coordinator: collecting logs (since=${SINCE})"
PODS=$(kubectl get pods -n "${NAMESPACE}" \
  -l "app=llm-d-coordinator" \
  -o jsonpath='{.items[*].metadata.name}')

if [[ -z "${PODS}" ]]; then
  echo "    (no coordinator pods found)"
  exit 1
fi

for POD in ${PODS}; do
  OUT="${OUT_DIR}/coordinator_${POD}.log"
  echo "    -> ${OUT}"
  kubectl logs -n "${NAMESPACE}" "${POD}" \
    -c coordinator \
    --since="${SINCE}" > "${OUT}" 2>&1 || true
done

echo "Logs written to ${OUT_DIR}"
