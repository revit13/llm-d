#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://localhost:8080}"
IMAGE_URL="${IMAGE_URL:-http://images.cocodataset.org/val2017/000000039769.jpg}"
IMAGE_FILE="${IMAGE_FILE:-}"
MODEL="${MODEL:-Qwen/Qwen3-VL-2B-Instruct}"
PROMPT="${PROMPT:-What animal is shown in this image?}"

if [[ -n "${IMAGE_FILE}" ]]; then
  SRC="${IMAGE_FILE}"
  MIME=$(file -b --mime-type "${IMAGE_FILE}")
  B64=$(base64 < "${IMAGE_FILE}" | tr -d '\n')
else
  SRC="${IMAGE_URL}"
  TMP=$(mktemp)
  trap 'rm -f "${TMP}"' EXIT
  curl -sSL "${IMAGE_URL}" -o "${TMP}"
  MIME=$(file -b --mime-type "${TMP}")
  B64=$(base64 < "${TMP}" | tr -d '\n')
fi

DATA_URL="data:${MIME};base64,${B64}"

PAYLOAD=$(jq -n \
  --arg model "${MODEL}" \
  --arg prompt "${PROMPT}" \
  --arg url "${DATA_URL}" \
  '{
    model: $model,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: $prompt },
          { type: "image_url", image_url: { url: $url } }
        ]
      }
    ]
  }')


#echo ${PAYLOAD} | jq > ttt.log


echo ENDPOINT=$ENDPOINT

# curl -v -sS "${ENDPOINT}/v1/chat/completions" \
#   -H "Content-Type: application/json" \
#   -d "${PAYLOAD}"


curl -v "${ENDPOINT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"

# curl -v "localhost:8080/v1/chat/completions" \
#   -H "Content-Type: application/json" \
#   --data-binary @- <<<"${PAYLOAD}"
