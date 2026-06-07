#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://localhost:8080}"
IMAGE_URL="${IMAGE_URL:-http://images.cocodataset.org/val2017/000000039769.jpg}"
IMAGE_URL2="${IMAGE_URL2:-https://placedog.net/300/200}"
MODEL="${MODEL:-Qwen/Qwen3-VL-2B-Instruct}"
PROMPT="${PROMPT:-What animal is shown in these images?}"

fetch_data_url() {
  local url="$1" tmp mime b64
  tmp=$(mktemp)
  curl -sSL "${url}" -o "${tmp}"
  mime=$(file -b --mime-type "${tmp}")
  b64=$(base64 < "${tmp}" | tr -d '\n')
  rm -f "${tmp}"
  printf 'data:%s;base64,%s' "${mime}" "${b64}"
}

DATA_URL=$(fetch_data_url "${IMAGE_URL}")
DATA_URL2=$(fetch_data_url "${IMAGE_URL2}")

PAYLOAD=$(jq -n \
  --arg model "${MODEL}" \
  --arg prompt "${PROMPT}" \
  --arg url "${DATA_URL}" \
  --arg url2 "${DATA_URL2}" \
  '{
    model: $model,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: $prompt },
          { type: "image_url", image_url: { url: $url } },
          { type: "image_url", image_url: { url: $url2 } }
        ]
      }
    ]
  }')


#echo ${PAYLOAD} | jq > ttt.log


# curl -v -sS "${ENDPOINT}/v1/chat/completions" \
#   -H "Content-Type: application/json" \
#   -d "${PAYLOAD}"


curl -v "${ENDPOINT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"

# curl -v "localhost:8080/v1/chat/completions" \
#   -H "Content-Type: application/json" \
#   --data-binary @- <<<"${PAYLOAD}"
