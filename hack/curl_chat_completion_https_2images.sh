curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-2B-Instruct",
    "messages": [
      {
        "role": "user",
        "content": [
          { "type": "text", "text": "What is in these two images?" },
          {
            "type": "image_url",
            "image_url": { "url": "http://images.cocodataset.org/val2017/000000039769.jpg" }
          },
          {
            "type": "image_url",
            "image_url": { "url": "http://images.cocodataset.org/val2017/000000000139.jpg" }
          }
        ]
      }
    ]
  }'