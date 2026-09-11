# llama.cpp Configuration for Zed Editor

This directory contains configuration examples for using llama.cpp with the Zed editor.

## Integration Methods

### 1. Using llama-server as a backend
Zed can connect to a locally running llama-server instance for AI-assisted coding.

### 2. Direct integration via Zed's API (if available)
Some versions of Zed may support direct model loading.

## Example: Running llama-server for Zed

```bash
# Start the server with a coding-optimized model
./llama-server -m /path/to/qwen2.5-coder-7b.q4_k_m.gguf \
  -c 4096 \
  --temp 0.2 \
  --top-p 0.95 \
  --repeat-penalty 1.05 \
  --port 8080 \
  --host 127.0.0.1 \
  --threads 4
```

## Zed Configuration Example
In Zed's settings, you would configure the AI assistant to point to:
- Host: http://127.0.0.1:8080
- API endpoint: /v1/chat/completions (OpenAI compatible)
- Model: [your model name]

## Recommended Parameters for Zed
- Context size (`-c`): 4096 tokens (good balance for code context)
- Temperature (`--temp`): 0.2 (for precise, deterministic code suggestions)
- Top-p: 0.95
- Repeat penalty: 1.05
- Stop sequences: ["\n\n", "```"] to prevent excessive generation
- Threads: Match your CPU cores minus one for system responsiveness

## Model Recommendations for Zed
- qwen2.5-coder-7b (excellent for coding tasks)
- codellama-7b (good alternative)
- phi-3-mini (if you need very low resource usage)

## Performance Tips
1. Use quantized models (Q4_K_M, Q5_K_M) for better speed/RAM tradeoff
2. Consider offloading layers to GPU if available (`-ngl` parameter)
3. Monitor memory usage and adjust context size accordingly