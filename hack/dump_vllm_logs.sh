#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE must be set}"
PREFIX="${PREFIX:-epd-nvidia-gpu-vllm}"
SINCE="${SINCE:-5m}"
OUT_DIR="${OUT_DIR:-./vllm-logs-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "${OUT_DIR}"

for ROLE in encode prefill decode; do
  DEPLOY="${PREFIX}-${ROLE}"
  echo "==> ${ROLE}: collecting logs (since=${SINCE}) for deployment ${DEPLOY}"

  PODS=$(kubectl get pods -n "${NAMESPACE}" \
    -l "llm-d.ai/role=${ROLE}" \
    -o jsonpath='{.items[*].metadata.name}')

  if [[ -z "${PODS}" ]]; then
    echo "    (no pods found for ${DEPLOY})"
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

echo "Logs written to ${OUT_DIR}"
