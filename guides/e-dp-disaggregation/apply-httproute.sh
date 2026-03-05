#!/bin/bash
set -e

NAMESPACE="${1:-default}"
RELEASE_NAME="${2:-e-dp-disaggregation}"

echo "Applying HTTPRoute to namespace: $NAMESPACE with release name: $RELEASE_NAME"

kubectl apply -f - -n "$NAMESPACE" <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-d-${RELEASE_NAME}
spec:
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: infra-${RELEASE_NAME}-inference-gateway
  rules:
  - backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: gaie-${RELEASE_NAME}
      port: 8000
      weight: 1
    matches:
    - path:
        type: PathPrefix
        value: /
    timeouts:
      backendRequest: 0s
      request: 0s
EOF

echo "HTTPRoute llm-d-${RELEASE_NAME} applied successfully"

# Made with Bob
