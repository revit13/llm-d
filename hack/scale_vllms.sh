#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE must be set}"
PREFIX="${PREFIX:-epd-nvidia-gpu-vllm}"
REPLICAS="${REPLICAS:-1}"

for ROLE in encode prefill decode; do
  DEPLOY="${PREFIX}-${ROLE}"
  echo "==> scaling ${DEPLOY} to ${REPLICAS}"
  kubectl scale deployment/"${DEPLOY}" -n "${NAMESPACE}" --replicas="${REPLICAS}"
done

for ROLE in encode prefill decode; do
  DEPLOY="${PREFIX}-${ROLE}"
  kubectl rollout status deployment/"${DEPLOY}" -n "${NAMESPACE}"
done
