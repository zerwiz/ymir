# Docker Configuration for Zed Editor with Ollama/Llama.cpp

This directory contains Docker configurations for integrating local LLMs with the Zed editor.

## Option 1: Ollama Container for Zed

Run Ollama with settings optimized for code assistance in Zed:

```bash
docker run -d \
  --name ollama-zed \
  -p 11434:11434 \
  -v ollama-zed-data:/root/.ollama \
  -e OLLAMA_HOST=0.0.0.0 \
  -e OLLAMA_NUM_PARALLEL=2 \
  ollama/ollama
```

Pull coding-optimized models:
```bash
docker exec ollama-zed ollama pull qwen2.5-coder:7b
docker exec ollama-zed ollama pull codellama:7b
```

## Option 2: llama.cpp Container for Zed (Lower Latency)

For potentially lower latency and better control:

```dockerfile
# Dockerfile.llama.cpp-zed
FROM ghcr.io/ggerganov/llama.cpp:latest

# Set up environment for coding assistance
ENV MODEL_PATH=/models/qwen2.5-coder-7b.q4_k_m.gguf
ENV HOST=0.0.0.0
ENV PORT=8080
ENV CTX_SIZE=4096
ENV THREADS=4
ENV BATCH_SIZE=512
ENV TEMPERATURE=0.2
ENV TOP_P=0.95
ENV REPEAT_PENALTY=1.05

# Expose API port
EXPOSE 8080

# Default command
CMD ["llama-server", \
     "--model", "$MODEL_PATH", \
     "--host", "$HOST", \
     "--port", "$PORT", \
     "--ctx-size", "$CTX_SIZE", \
     "--threads", "$THREADS", \
     "--batch-size", "$BATCH_SIZE", \
     "--temp", "$TEMPERATURE", \
     "--top-p", "$TOP_P", \
     "--repeat-penalty", "$REPEAT_PENALTY", \
     "--log-disable"]
```

Build and run:
```bash
docker build -t llama-zed-server -f Dockerfile.llama.cpp-zed .
docker run -d \
  --name llama-zed \
  -p 8080:8080 \
  -v ~/models:/models \
  llama-zed-server
```

## Option 3: Docker Compose for Zed Development

```yaml
# docker-compose.yml
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama-zed
    ports:
      - "11434:11434"
    volumes:
      - ollama-zed-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=2
    restart: unless-stopped

volumes:
  ollama-zed-data:
```

## Zed Configuration
In Zed's AI assistant settings:
- For Ollama: Set custom endpoint to `http://localhost:11434`
- For llama.cpp: Set custom endpoint to `http://localhost:8080`
- API path: `/v1/chat/completions` (OpenAI compatible)
- Model: [your model name]

## Recommended Models for Zed Coding Assistance
- qwen2.5-coder:7b (Ollama) / qwen2.5-coder-7b.q4_k_m.gguf (llama.cpp)
- codellama:7b (Ollama) / codellama-7b-instruct.q4_k_m.gguf (llama.cpp)
- phi3:medium (Ollama) / phi-3-medium-4k-instruct.q4_k_m.gguf (llama.cpp)

## Performance Optimization for Zed
1. Keep models loaded (avoid frequent pulling/unloading)
2. Use quantized models (Q4_K_M, Q5_K_M) for faster response
3. Match thread count to physical CPU cores
4. Consider GPU acceleration if available (--gpus all for Ollama, -ngl for llama.cpp)
5. Monitor memory usage and adjust context size as needed