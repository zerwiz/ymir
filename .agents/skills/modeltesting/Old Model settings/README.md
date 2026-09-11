# Model Hosting Configuration Knowledge Base

This repository serves as a knowledge base for storing configuration files for different model hosting services and tools.

## Directory Structure

- `ollama/` - Configurations for Ollama model hosting
  - `opencode/` - Ollama configurations for OpenCode
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files (Modelfile, etc.)
  - `pi/` - Ollama configurations for Pi (Raspberry Pi or similar)
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files (Modelfile, etc.)
  - `zed/` - Ollama configurations for Zed editor
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files (Modelfile, etc.)

- `llama_cpp/` - Configurations for llama.cpp based hosting
  - `opencode/` - llama.cpp configurations for OpenCode
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files
  - `pi/` - llama.cpp configurations for Pi
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files
  - `zed/` - llama.cpp configurations for Zed
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files

- `docker/` - Configurations for Docker-based model hosting
  - `opencode/` - Docker configurations for OpenCode
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files (Dockerfile, docker-compose.yml, etc.)
  - `pi/` - Docker configurations for Pi
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files
  - `zed/` - Docker configurations for Zed
    - `WORKING.md` - Verified working configurations
    - `NOT_WORKING.md` - Configurations needing testing or with issues
    - `README.md` - General documentation
    - Configuration files

## Purpose

This project aims to centralize and organize model configuration files across different hosting services and development tools. By maintaining separate folders for each hosting service (Ollama, llama.cpp, Docker) and subfolders for each target environment/tool (OpenCode, Pi, Zed), users can easily find and manage the appropriate configurations for their specific use cases.

Each service/tool combination includes:
- README.md: General documentation about the configuration
- WORKING.md: Documented configurations verified to work
- NOT_WORKING.md: Configurations needing testing or with known issues
- Actual configuration files (Modelfile, Dockerfile, etc.)

## Usage

Navigate to the appropriate service and tool directory to find configuration files:
- For Ollama + OpenCode: `ollama/opencode/`
- For llama.cpp + Pi: `llama_cpp/pi/`
- For Docker + Zed: `docker/zed/`

In each directory, consult:
- README.md for general documentation
- WORKING.md for verified working configurations
- NOT_WORKING.md for configurations needing testing or with known issues