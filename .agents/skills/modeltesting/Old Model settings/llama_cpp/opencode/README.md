# llama.cpp Configuration for OpenCode

This directory contains configuration examples for using llama.cpp with OpenCode.

## Model Files
Place your GGUF model files in this directory or specify the path in your configuration.

## Command Line Examples

### Basic Usage
```bash
./llama-cli -m /path/to/model.gguf -c 8192 --temp 0.7
```

### Interactive Mode
```bash
./llama-cli -m /path/to/model.gguf -c 8192 --temp 0.3 --repeat-penalty 1.1 -i
```

### Server Mode (for API integration)
```bash
./llama-server -m /path/to/model.gguf -c 8192 --port 8080 --host 127.0.0.1
```

## Recommended Parameters for OpenCode
- Context size (`-c`): 8192 tokens
- Temperature (`--temp`): 0.3 (for focused, deterministic code generation)
- Top-p: 0.9
- Repeat penalty: 1.1
- Threads: Match your CPU cores