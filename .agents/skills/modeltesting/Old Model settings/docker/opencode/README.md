# Docker Configuration for OpenCode with Ollama

This directory contains Docker configurations for running Ollama with OpenCode.

## Option 1: Simple Ollama Container

Run Ollama with default settings:
```bash
docker run -d \
  --name ollama-opencode \
  -p 11434:11434 \
  -v ollama-opencode-data:/root/.ollama \
  ollama/ollama
```

Then pull your preferred coding model:
```bash
docker exec ollama-opencode ollama pull qwen2.5-coder:7b
```

## Option 2: Pre-loaded Ollama Container (Recommended)

Create a Dockerfile to pre-load models:

```dockerfile
# Dockerfile.ollama-opencode
FROM ollama/ollama

# Start Ollama server, pull model, then stop
RUN ollama serve & \
    sleep 5 && \
    ollama pull qwen2.5-coder:7b && \
    ollama pull qwen3.5:9b && \
    pkill ollama

# Expose Ollama API port
EXPOSE 11434

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_NUM_PARALLEL=2

# Start Ollama server
CMD ["ollama", "serve"]
```

Build and run:
```bash
docker build -t ollama-opencode-custom -f Dockerfile.ollama-opencode .
docker run -d \
  --name ollama-opencode \
  -p 11434:11434 \
  -v ollama-opencode-data:/root/.ollama \
  ollama-opencode-custom
```

## Option 3: Docker Compose (Recommended for Development)

```yaml
# docker-compose.yml
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama-opencode
    ports:
      - "11434:11434"
    volumes:
      - ollama-opencode-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=2
    restart: unless-stopped

volumes:
  ollama-opencode-data:
```

Run with: `docker-compose up -d`

## Model Recommendations for OpenCode
- qwen2.5-coder:7b (excellent for coding)
- qwen3.5:9b (strong reasoning and coding)
- deepseek-coder-v2:latest (specialized for code)
- glm-agent:latest (good general purpose)

## Usage with OpenCode
Once Ollama is running, configure OpenCode to use:
- Host: http://localhost:11434
- API endpoint: /api/generate
- Model: [your chosen model name]