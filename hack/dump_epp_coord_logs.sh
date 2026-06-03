#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE must be set}"
GUIDE_NAME="${GUIDE_NAME:-epd}"
SINCE="${SINCE:-10m}"
OUT_DIR="${OUT_DIR:-./epp-logs-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "${OUT_DIR}"

for ROLE in encode prefill decode; do
  EPP="${GUIDE_NAME}-${ROLE}-epp"
  echo "==> ${ROLE}: collecting logs (since=${SINCE}) for EPP ${EPP}"

  PODS=$(kubectl get pods -n "${NAMESPACE}" \
    -l "llm-d-router-gateway=${EPP}" \
    -o jsonpath='{.items[*].metadata.name}')

  if [[ -z "${PODS}" ]]; then
    echo "    (no pods found for ${EPP})"
    continue
  fi

  for POD in ${PODS}; do
    OUT="${OUT_DIR}/${ROLE}_${POD}.log"
    echo "    -> ${OUT}"
    kubectl logs -n "${NAMESPACE}" "${POD}" \
      --all-containers=true --prefix=true \
      --since="${SINCE}" > "${OUT}" 2>&1 || true
  done
done

echo "==> coordinator: collecting logs (since=${SINCE})"
COORD_PODS=$(kubectl get pods -n "${NAMESPACE}" \
  -l "app=llm-d-coordinator" \
  -o jsonpath='{.items[*].metadata.name}')

if [[ -z "${COORD_PODS}" ]]; then
  echo "    (no coordinator pods found)"
else
  for POD in ${COORD_PODS}; do
    OUT="${OUT_DIR}/coordinator_${POD}.log"
    echo "    -> ${OUT}"
    kubectl logs -n "${NAMESPACE}" "${POD}" \
      --all-containers=true --prefix=true \
      --since="${SINCE}" > "${OUT}" 2>&1 || true
  done
fi

echo "Logs written to ${OUT_DIR}"
