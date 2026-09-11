# llama.cpp Configuration for Raspberry Pi

This directory contains configuration examples for using llama.cpp on Raspberry Pi.

## Model Files
Place your GGUF model files in this directory or specify the path in your configuration.
For Pi, consider using smaller quantized models (Q4_K_M, Q5_K_M) to fit in limited RAM.

## Command Line Examples

### Basic Usage (Optimized for Pi)
```bash
./llama-cli -m /path/to/model.gguf -c 2048 --temp 0.5 --threads 2 --batch_size 512
```

### Interactive Mode
```bash
./llama-cli -m /path/to/model.gguf -c 2048 --temp 0.3 --repeat_penalty 1.1 -i --threads 2
```

### Server Mode (for lightweight API)
```bash
./llama-server -m /path/to/model.gguf -c 2048 --port 8080 --host 127.0.0.1 --threads 2
```

## Recommended Parameters for Raspberry Pi
- Context size (`-c`): 2048 tokens (to conserve RAM)
- Temperature (`--temp`): 0.5 (balanced for general use on Pi)
- Top-p: 0.9
- Repeat penalty: 1.1
- Threads: 2-4 (depending on Pi model, leave some for system)
- Batch size: 512 (adjust based on available RAM)