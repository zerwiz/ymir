# Docker Configuration for Raspberry Pi with Ollama/Llama.cpp

This directory contains Docker configurations optimized for Raspberry Pi hardware.

## Option 1: Ollama on Raspberry Pi (64-bit OS Required)

Note: Raspberry Pi requires a 64-bit OS (Raspberry Pi OS 64-bit) to run Ollama.

```bash
docker run -d \
  --name ollama-pi \
  -p 11434:11434 \
  -v ollama-pi-data:/root/.ollama \
  --restart unless-stopped \
  ollama/ollama
```

Then pull smaller models suitable for Pi:
```bash
docker exec ollama-pi ollama pull phi3:mini
docker exec ollama-pi ollama pull tinyllama:1.1b
```

## Option 2: llama.cpp on Raspberry Pi (More Pi-Friendly)

For better performance on Pi, consider using llama.cpp directly:

```dockerfile
# Dockerfile.llama.cpp-pi
FROM ghcr.io/ggerganov/llama.cpp:latest

# Copy a small model (you would mount this or build it in)
# COPY ./models/phi-3-mini-4k-instruct.q4_k_m.gguf /models/

# Set default command
CMD ["llama-server", "--model", "/models/phi-3-mini-4k-instruct.q4_k_m.gguf", "--host", "0.0.0.0", "--port", "8080", "--ctx-size", "2048", "--threads", "2"]
```

Build and run (adjust for your Pi's CPU architecture):
```bash
# For Raspberry Pi 4 (arm64/v8)
docker build -t llama-pi-server -f Dockerfile.llama.cpp-pi .
docker run -d \
  --name llama-pi \
  -p 8080:8080 \
  -v ~/models:/models \
  llama-pi-server
```

## Option 3: Docker Compose for Pi

```yaml
# docker-compose.yml
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama-pi
    ports:
      - "11434:11434"
    volumes:
      - ollama-pi-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=1  # Limit parallelism for Pi
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G  # Constrain memory usage on Pi

volumes:
  ollama-pi-data:
```

## Model Recommendations for Raspberry Pi
- phi3:mini (3.8B parameters, very efficient)
- tinyllama:1.1b (extremely lightweight)
- llama3.2:1b (if available)
- quantized GGUF models for llama.cpp (Q4_K_M, Q5_K_M)

## Performance Tips for Pi
1. Use 64-bit OS for better Docker support
2. Limit context size (-c 2048 or less) to conserve RAM
3. Limit parallelism (OLLAMA_NUM_PARALLEL=1)
4. Consider using swap storage if needed
5. Monitor temperature and throttle if necessary