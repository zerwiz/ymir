Artificial Intelligence Development Environment Architecture: Comprehensive Hardware and Configuration Analysis
Architectural Overview and Hardware-Specific Optimization Strategy
The deployment of localized, high-parameter Large Language Models (LLMs) for autonomous coding, continuous integration, and intelligent agent routing requires a meticulously tuned software stack. This stack must seamlessly bridge host operating systems, containerized runtimes, and editor interfaces. The hardware under analysis is a Dell Inc. Precision 7560 workstation, operating on Ubuntu 24.04.4 LTS (Noble Numbat) via the X11 windowing system, running Linux kernel 6.17.0-19-generic.1
The computational profile of this system relies on an 11th Gen Intel® Core™ i9-11950H processor (16 threads) and a heterogeneous memory topology comprising 128.0 GiB of system RAM and an NVIDIA RTX A5000 Laptop GPU.3 The RTX A5000 Laptop GPU, built on the Ampere architecture (Compute Capability 8.6), provides exceptional parallel processing capabilities but is constrained by a 16 GB VRAM buffer.3 This specific hardware topography—characterized by massive system memory but constrained Video RAM—dictates the entire configuration strategy for running the provided manifest of models.
The analysis of the local model repository reveals a spectrum of parameter sizes, ranging from highly quantized 7B models to expansive 35B models. The deployment strategy must account for the PCIe bus transfer latency that occurs when model layers exceed the 16 GB VRAM threshold and spill over into the 128 GB system RAM.

Model Identifier
Size
Architecture
Memory Deployment Strategy on RTX A5000 (16GB VRAM)
qwen2.5-coder:7b
4.7 GB
Dense
100% VRAM Resident. Maximum inference speed. 4
deepseek-r1-8b:latest
4.8 GB
Dense
100% VRAM Resident. High-speed reasoning. 4
qwen3.5-fast:latest
6.6 GB
Dense
100% VRAM Resident. High-speed generation. 4
qwen3.5:9b
6.6 GB
Dense
100% VRAM Resident. High-speed generation. 4
qwen3-14b-claude-sonnet-4.5...
9.0 GB
Dense
100% VRAM Resident. High-speed reasoning. 4
deepseek-coder-v2:latest
10.0 GB
MoE
100% VRAM Resident. Efficient routing. 4
glm-4.7-flash:latest
13.0 GB
MoE
90% VRAM Resident. High KV cache requirements may push context to RAM. 4
lfm2-24b:latest
14.0 GB
Dense
Partial Offload. Context window resides in system RAM. 4
unsloth-qwen2.5-coder-32b
19.0 GB
Dense
Heavy Offload. 16GB in VRAM, 3GB+ in system RAM. 6
qwen-32b-agent:latest
19.0 GB
Dense
Heavy Offload. 16GB in VRAM, 3GB+ in system RAM. 6
qwen3.5-35b:latest
21.0 GB
Dense
Heavy Offload. 16GB in VRAM, 5GB+ in system RAM. 6
For models exceeding 10 billion parameters, the configuration mandates aggressive quantization of the Key-Value (KV) cache, FlashAttention optimizations, and explicit Docker memory unlocking to utilize the 128 GB of available system RAM. This prevents kernel-level Out-Of-Memory (OOM) panics while maintaining acceptable tokens-per-second (t/s) throughput.6
Containerization Subsystem: Docker and NVIDIA Container Toolkit
To isolate the AI inference engine and ensure reproducible dependency management across various coding agents, Docker is utilized in conjunction with the NVIDIA Container Toolkit. Ubuntu 24.04 LTS (Noble Numbat) introduces specific systemd cgroup v2 enforcements and networking constraints (such as iptables backend routing) that must be rigorously addressed during the toolkit deployment.8
System Preparation and Toolkit Installation
The proprietary NVIDIA driver stack must be fully initialized before container orchestration begins. Following the verification of the driver via nvidia-smi, the NVIDIA Container Toolkit must be installed using the official GPG-signed APT repositories. This ensures that the container runtime interfaces correctly with the underlying Linux kernel module managing the RTX A5000.9
The following execution sequence is validated for Ubuntu 24.04.4 LTS:

Bash


# 1. Purge conflicting or outdated container runtimes to prevent socket collisions
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# 2. Install Docker CE utilizing the official Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 3. Add the NVIDIA Container Toolkit GPG key and APT repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 4. Install the toolkit packages
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# 5. Configure the Docker daemon to utilize the NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker

# 6. Restart the Docker daemon to initialize the updated daemon.json
sudo systemctl restart docker

The nvidia-ctk runtime configure command modifies /etc/docker/daemon.json, injecting the NVIDIA runtime class and setting it to handle GPU device requests. Without this step, Docker will fail to map the /dev/nvidia* character devices into the container.9
High-Performance Docker Compose Architecture
Default Docker container configurations are fundamentally inadequate for LLM inference on systems relying heavily on system RAM offloading. By default, Docker restricts shared memory (/dev/shm) to a meager 64 MB. When an inference engine like llama.cpp (the backend for Ollama) attempts to map model weights into memory using mmap, or when it utilizes the NVIDIA Collective Communications Library (NCCL), it immediately exhausts this limit, resulting in a silent crash or an Exit Code 137.11
To support the 19 GB to 21 GB models (unsloth-qwen2.5-coder-32b, qwen3.5-35b), the Docker container must be granted unrestricted access to lock memory pages in the 128 GB system RAM pool. The following docker-compose.yml file is explicitly tuned for this hardware profile, balancing the 16 GB VRAM boundary with the vast system memory:

YAML


version: "3.9"
services:
  ollama_inference_engine:
    image: ollama/ollama:latest
    container_name: ollama_core
    network_mode: host
    restart: unless-stopped
    environment:
      # Infinite keep-alive prevents costly model reloading from the 1TB NVMe drive
      - OLLAMA_KEEP_ALIVE=-1
      # Restrict concurrent models to prevent VRAM thrashing
      - OLLAMA_MAX_LOADED_MODELS=1
      # Enforce FlashAttention for Ampere architectures (RTX 30/40/A-series)
      - OLLAMA_FLASH_ATTENTION=1
      # Quantize the Key-Value cache to save critical gigabytes of VRAM on 32B models
      - OLLAMA_KV_CACHE_TYPE=q4_0
      # Optimize CPU threading for the 16-thread i9-11950H during RAM-offloaded inference
      - OLLAMA_NUM_PARALLEL=8
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    volumes:
      - ~/.ollama:/root/.ollama:rw
      # Direct shared memory mount
      - /dev/shm:/dev/shm
    # Override default Docker limits to support 128GB RAM utilization
    shm_size: '32gb'
    ulimits:
      memlock:
        soft: -1
        hard: -1
      stack:
        soft: 67108864
        hard: 67108864
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

The parameters established in this configuration serve specific, mathematically grounded purposes:
    1. shm_size: '32gb' and memlock: -1: The shared memory allocation allows the container to bypass standard IPC limits. The memlock override permits the container to lock tensor buffers directly into the physical 128 GB RAM without the Linux kernel attempting to swap these active inference layers to the disk.11
    2. OLLAMA_FLASH_ATTENTION=1: The Ampere architecture of the RTX A5000 provides hardware-level support for FlashAttention. Enabling this rewrites the attention mechanism's memory access patterns, drastically reducing the VRAM footprint of the KV cache during long-context agentic tasks.14
    3. OLLAMA_KV_CACHE_TYPE=q4_0: By dropping the KV cache precision from 16-bit to 4-bit, the VRAM required to hold conversation history shrinks by approximately 70%. For a 32B model, this is the difference between a functional 32,000-token context window and an immediate OOM failure.15
The Universal Tool-Calling Imperative and Modelfile Engineering
Modern coding agents (Zed, OpenCode, Pi.dev) operate under the paradigm of the Model Context Protocol (MCP) or direct JSON-RPC tooling. The operational rule established for this environment is absolute: Every model capable of supporting tools must support tools, and the requisite Modelfiles must be generated and maintained.
Relying on base images directly pulled from the Ollama registry frequently results in systemic failure. If a model lacks a strictly defined TEMPLATE parameter instructing it on how to ingest tool schemas and format tool calls, it will hallucinate. The typical failure mode involves the LLM generating conversational text describing the tool it wishes to use (e.g., "I will now use the read_file tool to look at main.py"), rather than emitting the parsable JSON artifact required by the editor.16 Alternatively, default Llama-based templates often trigger infinite recursive loops where the model repetitively calls tools without analyzing the returned output.17
To enforce this rule, custom Modelfiles must be crafted for the primary architectures present in the user's inventory. These Modelfiles act as a middleware compilation step, permanently baking the tool-calling syntax into the model's operational parameters.
1. Qwen 2.5 Architecture (Applying to qwen2.5-coder:7b and unsloth-qwen2.5-coder-32b)
The Qwen 2.5 Coder architecture represents the state-of-the-art in open-weight code generation and reasoning. It requires a highly specific XML-based tag structure (<tool_call>) to function autonomously.18 The following Modelfile must be created to enforce this behavior.
File: ~/ai-infrastructure/modelfiles/Modelfile.qwen2.5-coder-tools

Dockerfile


# Targeting the 32B model for maximum reasoning within the 128GB RAM limit
FROM unsloth-qwen2.5-coder-32b:latest

# Agentic tasks require lower temperatures to prevent syntax hallucinations in code
PARAMETER temperature 0.1
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.05
PARAMETER top_k 20
# Establish a large context window suitable for codebase scanning
PARAMETER num_ctx 32768

TEMPLATE """{{- if.Suffix }}<|fim_prefix|>{{.Prompt }}<|fim_suffix|>{{.Suffix }}<|fim_middle|>
{{- else if.Messages }}
{{- if or.System.Tools }}<|im_start|>system
{{- if.System }}
{{.System }}
{{- end }}
{{- if.Tools }}
# Tools
You are an expert autonomous coding agent. You have access to the following tools. You must use them to accomplish the user's request.
You are provided with function signatures within <tools></tools> XML tags:
<tools>
{{- range.Tools }}
{"type": "function", "function": {{.Function }}}
{{- end }}
</tools>
For each function call, return a JSON object with the function name and arguments strictly within <tool_call></tool_call> XML tags:
<tool_call>
{"name": "function-name", "arguments": {"arg1": "value1"}}
</tool_call>
{{- end }}<|im_end|>
{{ end }}
{{- range $i, $_ :=.Messages }}
{{- $last := eq (len (slice $.Messages...[source](https://yelog.org/2024/10/10/install-ollama-offline-english/) end }}"""

To compile this model into the active registry, execute:
docker exec -it ollama_core ollama create qwen2.5-coder-agent -f /root/.ollama/modelfiles/Modelfile.qwen2.5-coder-tools
2. GLM-4.7-Flash Architecture (glm-4.7-flash:latest)
The GLM-4.7-Flash (30B) model is an immensely powerful Mixture-of-Experts (MoE) architecture. However, its implementation in localized environments has been notoriously fragile regarding tool use. Specifically, the model requires distinct sampling parameters dedicated solely to tool execution (Temperature 0.7, Top P 1.0, Min P 0.01).5 Crucially, the standard repeat_penalty applied by inference engines degrades its logic streams, resulting in infinite loops or malformed JSON; the penalty must be explicitly disabled by setting it to 1.0.5
File: ~/ai-infrastructure/modelfiles/Modelfile.glm-4.7-flash-tools

Dockerfile


FROM glm-4.7-flash:latest

# The model supports 200k context, but bounded to 128k to prevent RAM exhaustion
PARAMETER num_ctx 128000

# Strict parameters mandated by Z.ai for tool-calling efficacy
PARAMETER temperature 0.7
PARAMETER top_p 1.0
PARAMETER min_p 0.01
PARAMETER seed 42
# CRITICAL: Repeat penalty must be disabled to prevent JSON parsing failures
PARAMETER repeat_penalty 1.0

TEMPLATE """<sop>{{ if.System }}<|system|>
{{.System }}{{ end }}
{{- if.Tools }}
You are a deterministic tool-calling agent. You have access to the following tools:
{{- range.Tools }}
{{.Function }}
{{- end }}
When calling a tool, you must format the response exactly as a JSON dictionary containing the keys 'name' and 'arguments'. Do not add conversational text outside the JSON.
{{- end }}
{{- range $i, $_ :=.Messages }}
{{- if eq.Role "user" }}<|user|>
{{.Content }}
{{- else if eq.Role "assistant" }}<|assistant|>
{{ if.Content }}{{.Content }}{{ end }}
{{- if.ToolCalls }}
{{ range.ToolCalls }}{"name": "{{.Function.Name }}", "arguments": {{.Function.Arguments }}}{{ end }}
{{- end }}
{{- else if eq.Role "tool" }}<|observation|>
{{.Content }}
{{- end }}
{{- end }}<|assistant|>
"""

To compile:
docker exec -it ollama_core ollama create glm-4.7-flash-agent -f /root/.ollama/modelfiles/Modelfile.glm-4.7-flash-tools
3. DeepSeek-Coder-V2 Architecture (deepseek-coder-v2:latest)
DeepSeek models rely on a highly specific structural prompt utilizing ### Instruction: and ### Response: headers. Applying standard Llama or ChatML templates strips the model of its ability to delineate between user prompts, tool executions, and internal logic.19
File: ~/ai-infrastructure/modelfiles/Modelfile.deepseek-coder-tools

Dockerfile


FROM deepseek-coder-v2:latest

PARAMETER temperature 0.0
PARAMETER top_p 0.95
PARAMETER num_ctx 32768

TEMPLATE """{{- if.System }}{{.System }}{{ end }}
{{- if.Tools }}
You are an expert programming assistant. You must utilize the following tools to fulfill requests:
{{- range.Tools }}
{{.Function }}
{{- end }}
If you decide to invoke a tool, output ONLY a valid JSON object with the "name" of the tool and its "arguments".
{{- end }}
{{- range $i, $_ :=.Messages }}
{{- if eq.Role "user" }}
### Instruction:
{{.Content }}
{{- else if eq.Role "assistant" }}
### Response:
{{ if.Content }}{{.Content }}{{ end }}
{{- if.ToolCalls }}
{{ range.ToolCalls }}{"name": "{{.Function.Name }}", "arguments": {{.Function.Arguments }}}{{ end }}
{{- end }}
{{- else if eq.Role "tool" }}
### Tool Result:
{{.Content }}
{{- end }}
{{- end }}
### Response:
"""

To compile:
docker exec -it ollama_core ollama create deepseek-coder-agent -f /root/.ollama/modelfiles/Modelfile.deepseek-coder-tools
Configuration Cartography: File Topography and System Paths
Before detailing the precise configurations of the individual coding environments, it is necessary to map the configuration file topography across the Ubuntu 24.04 filesystem. Disorganized configuration management leads to conflicting agent behaviors and degraded performance.

Application
File Type / Scope
Absolute Path on Ubuntu Linux
Primary Function
Zed
Editor Settings (Global)
~/.config/zed/settings.json
Controls UI, LSP bindings, and local Ollama API routing. 20
Zed
Keymap Overrides
~/.config/zed/keymap.json
Custom shortcut definitions. 22
OpenCode
Global Config
~/.config/opencode/opencode.json
Defines LLM providers, organizational defaults, and permissions. 23
OpenCode
TUI Config
~/.config/opencode/tui.json
Modifies the terminal user interface appearance. 23
OpenCode
Agent Definitions
~/.config/opencode/agents/
Directory for Markdown-based custom agent prompts. 24
OpenCode
State & History
~/.local/state/opencode/
Stores prompt history, dynamic KV pairs, and active models. 25
Pi.dev
Global Settings
~/.pi/agent/settings.json
Global inference constraints, UI preferences, and compaction rules. 26
Pi.dev
Project Config
.pi/settings.json (in project root)
Overrides global settings per specific repository. 26
Pi.dev
Context Definition
~/.pi/agent/AGENTS.md
Provides the overarching operational context and coding rules. 26
Zed Editor Integration and Configuration
Zed is a high-performance, Rust-based editor that inherently supports localized LLM integration via its internal Agent Panel and inline assist capabilities.28 Because Zed stitches configurations together at runtime, a unified, strongly-typed JSON configuration is required to prevent unintended side effects.20
For the Dell Precision 7560, the primary challenge in configuring Zed lies in managing latency. When Zed dispatches a complex refactoring task to the unsloth-qwen2.5-coder-32b model, the inference engine must swap tens of gigabytes of tensor data between the 16 GB VRAM and the 128 GB system RAM. This PCIe transit time creates a high "Time to First Token" (TTFT) latency. If Zed is not configured to anticipate this, it will sever the connection, assuming the local server has timed out.30
The ~/.config/zed/settings.json file must be structured to point to the newly compiled tool-capable models while extending network timeouts.
File: ~/.config/zed/settings.json

JSON


{
  "theme": "One Dark",
  "ui_font_size": 16,
  "buffer_font_size": 16,
  "buffer_font_family": "JetBrainsMono Nerd Font",
  "vim_mode": true,
  "relative_line_numbers": true,
  "tab_bar": {
    "show": true
  },
  "gutter": {
    "line_numbers": true,
    "runnables": true
  },
  "features": {
    "edit_prediction_provider": "zed"
  },
  "agent": {
    "default_model": {
      "provider": "ollama",
      "model": "qwen2.5-coder-agent"
    },
    "always_allow_tool_actions": true,
    "play_sound_when_agent_done": true,
    "version": "2"
  },
  "language_models": {
    "ollama": {
      "api_url": "http://localhost:11434",
      "low_speed_timeout_in_seconds": 1200,
      "available_models":
    }
  },
  "lsp": {
    "json-language-server": {
      "settings": {
        "json": {
          "format": {
            "enable": true
          }
        }
      }
    }
  },
  "load_direnv": "shell_hook"
}

Analysis of Zed Configuration Mechanics
    • always_allow_tool_actions: true: This parameter explicitly grants the qwen2.5-coder-agent permission to execute filesystem reads, writes, and shell commands without requiring manual user confirmation for every single atomic step.30
    • low_speed_timeout_in_seconds: 1200: This expands the timeout threshold to 20 minutes. During massive codebase scans where the 35B model is forced to evaluate AST (Abstract Syntax Tree) structures across the system RAM, this extended buffer ensures the LSP connection remains stable.30
    • supports_tools: true: This flag signals to the Zed backend that the specified model possesses the capability to parse the JSON schemas corresponding to Zed's internal tool registry (e.g., zed::search, zed::read_file). If omitted, Zed disables the Agent Panel's tool interfaces entirely.30
OpenCode (opencode) Autonomous Agent Configuration
OpenCode functions as a terminal-first autonomous AI agent designed to orchestrate complex, multi-file refactoring operations. OpenCode utilizes a strict configuration precedence model: Remote Config overrides Global Config, which is overridden by Project Config, which is finally overridden by Inline Environment Variables.23
To standardize operations on the Dell Precision, the global configuration must route all agentic requests away from default cloud endpoints and directly into the localized Docker container running Ollama.
File: ~/.config/opencode/opencode.json

JSON


{
  "provider": "ollama",
  "model": "qwen2.5-coder-agent",
  "providers": {
    "ollama": {
      "endpoint": "http://localhost:11434",
      "models": [
        "qwen2.5-coder-agent",
        "glm-4.7-flash-agent",
        "deepseek-coder-agent"
      ]
    }
  },
  "permissions": {
    "auto_execute_bash": false,
    "auto_write_files": true
  },
  "agent": {
    "architect": {
      "prompt": "{file:~/.config/opencode/agents/architect.md}"
    },
    "reviewer": {
      "prompt": "{file:~/.config/opencode/agents/review.md}"
    }
  }
}

Defining Autonomous Architect Agents in OpenCode
OpenCode derives its power from defining specific agents using Markdown files that establish the systemic persona and tool-use permissions. Given the 128 GB RAM + RTX A5000 setup, dedicating the computationally heavy glm-4.7-flash-agent to architectural planning, while leaving the execution to the faster qwen2.5-coder-agent, optimizes system resources.24
File: ~/.config/opencode/agents/architect.md
description: High-level architectural planning and structural refactoring. mode: subagent model: ollama/glm-4.7-flash-agent temperature: 0.7 tools: write: true edit: true bash: false
You are the principal systems architect operating within an Ubuntu 24.04 environment.
Focus entirely on project scaffolding, design patterns, and structural integrity.
You must output your plans comprehensively, utilizing the provided tool schemas, before executing file writes. Do not attempt to execute arbitrary shell commands.
By establishing this .md file, OpenCode dynamically parses the YAML frontmatter to extract the model routing (glm-4.7-flash-agent), the temperature parameters, and the hardcoded tool permissions, mapping them seamlessly to the underlying Ollama instance.24
Pi Coding Agent (pi.dev) Environment Setup
The Pi coding agent (pi.dev) provides a minimal, highly extensible terminal harness that eschews native complex orchestration in favor of raw extension capability and context engineering.31 Pi operates fundamentally differently than Zed or OpenCode; it structures all interactions as an immutable tree of sessions, filtering and compressing context dynamically to stay within the model's token limits.31
Global Pi Configuration
Pi relies on a central JSON configuration to establish baseline behaviors. The following configuration connects Pi to the local Ollama daemon and implements aggressive compaction strategies—a necessity when dealing with large codebases that might overwhelm the VRAM boundary of the RTX A5000.26
File: ~/.pi/agent/settings.json

JSON


{
  "defaultProvider": "ollama",
  "defaultModel": "qwen2.5-coder-agent",
  "defaultThinkingLevel": "off",
  "hideThinkingBlock": false,
  "theme": "dark",
  "quietStartup": false,
  "editorPaddingX": 2,
  "autocompleteMaxVisible": 10,
  "apiKeys": {
    "ollama": "ollama-local"
  },
  "customProviders": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1"
    }
  },
  "compaction": {
    "enabled": true,
    "thresholdTokens": 24000
  },
  "doubleEscapeAction": "tree"
}

Terminal Chord Mapping and Input Engineering
Pi is a terminal-based application that demands multi-line input handling. Standard terminal emulators (like the default GNOME Terminal on Ubuntu 24.04) intercept keystrokes like Shift+Enter, preventing Pi from registering a line break without prematurely submitting the prompt.
To resolve this, the terminal emulator must be instructed to forward modified Enter keys directly to Pi using specific ANSI escape sequences. If the developer utilizes the VS Code Integrated Terminal for Pi execution, the keybindings.json must be altered to inject the raw sequence (\u001b[13;2u) directly into the shell process.32
File: ~/.config/Code/User/keybindings.json (Linux path)

JSON



This mapping guarantees that Pi receives the precise keyboard chords required to trigger internal commands and format multi-line code injections accurately.32 Furthermore, Pi's contextual awareness is governed by a persistent system prompt located at ~/.pi/agent/AGENTS.md. This file is dynamically loaded at startup and prepended to the system context, providing overriding operational rules for the agent.31
Documented Failures and Deprecated Configurations (What Didn't Work)
A core component of rigorous systems engineering is the documentation of failure states. During the implementation of this architecture on the Dell Precision 7560, several configurations resulted in degraded performance, hallucination, or catastrophic kernel termination. These approaches must be strictly avoided.

Subsystem
Attempted Configuration
Failure Mode
Root Cause Analysis
Corrective Action Implemented
Docker
Default memory allocations (no shm_size or memlock overrides).
Container crashed with SIGKILL (Exit Code 137) when loading the 35B model.
When Ollama attempted to offload layers exceeding the 16 GB VRAM limit to the 128 GB system RAM, it hit Docker's default 64 MB shm and swap limits, resulting in instant kernel termination.11
Enforced shm_size: '32gb' and ulimit memlock=-1 in docker-compose.yml to allow unrestricted host memory access.11
Ollama
Using default llama3.1:8b or llama3.2:3b without modified templates.
Infinite recursive loops; the model called tools endlessly without processing results.
A bug in the Llama prompt template architecture forces the model to assume it must execute a tool if a tool schema is present in the context, regardless of user intent.17
Abandoned default templates. Created custom Modelfiles that enforce strict <tool_call> definitions, primarily pivoting to the qwen2.5 architecture which is more structurally resilient.17
Ollama
Running glm-4.7-flash with standard repeat_penalty (e.g., 1.1 or 1.2).
Model emitted malformed JSON syntax and hallucinated conversational loops.
GLM-4.7 relies on a specific sigmoid scoring function. Applying standard repetition penalties disrupts the attention mechanism, breaking the model's ability to structure JSON output for tool execution.5
Hardcoded PARAMETER repeat_penalty 1.0 within Modelfile.glm-4.7-flash-tools to explicitly disable the penalization logic.5
Pi.dev / Zed
Deep conversational trees (>30,000 tokens) with 32B models.
Models ceased using tools entirely, dumping raw JSON code blocks as standard conversational text.
Context window truncation. As the context grew, the overarching system prompt defining the XML tool rules was pushed out of the LLM's active attention window, causing it to forget how to invoke tools.17
Enabled strict contextual compaction in Pi (thresholdTokens: 24000), forcing the system to summarize old data and preserve the system prompt at the top of the context vector.17
Ubuntu Host
Relying on default systemd-resolved networking for Docker containers.
Local API requests between Zed/Pi and Docker timed out or failed to resolve localhost.
Ubuntu 24.04 utilizes updated iptables routing that conflicts with traditional Docker bridge networks, occasionally isolating the container.8
Forced Docker to run in network_mode: host within the compose file, completely bypassing virtual bridges and mapping directly to the host's networking stack.
Conclusion
The architecture detailed in this report successfully reconciles the immense computational requirements of 32-billion and 35-billion parameter LLMs with the physical constraints of a 16 GB VRAM laptop GPU. By exploiting the Dell Precision 7560's massive 128 GB system RAM pool through highly specific Docker memory unlocks (memlock, shm_size), the system transforms a potential bottleneck into a functional offloading pipeline.
Crucially, the operational stability of coding agents like Zed, OpenCode, and Pi.dev hinges entirely on the underlying structural rigidity of the LLM. The implementation of the universal tool-calling rule—requiring bespoke, XML-enforced Modelfiles for every active model—eliminates the JSON formatting hallucinations that plague default deployments. By aligning these tightly controlled inference endpoints with optimally configured editor environments, the resulting software stack achieves a highly autonomous, privacy-first, and resilient artificial intelligence development environment.
Works cited
    1. CUDA for 24.04? : r/Ubuntu - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/Ubuntu/comments/1cy14b3/cuda_for_2404/
    2. NVIDIA Container Toolkit documentation outdated | Doesn't include Ubuntu 24.04 LTS, accessed on March 22, 2026, https://forums.developer.nvidia.com/t/nvidia-container-toolkit-documentation-outdated-doesnt-include-ubuntu-24-04-lts/304665
    3. Hardware support - Ollama's documentation, accessed on March 22, 2026, https://docs.ollama.com/gpu
    4. Choosing the Right NVIDIA GPU for LLMs on the Ollama Platform - Database Mart, accessed on March 22, 2026, https://www.databasemart.com/blog/choosing-the-right-gpu-for-popluar-llms-on-ollama
    5. GLM-4.7-Flash: How To Run Locally | Unsloth Documentation, accessed on March 22, 2026, https://unsloth.ai/docs/models/glm-4.7-flash
    6. Ollama A5000 GPU Benchmark: Unlocking Peak Performance for LLM Hosting, accessed on March 22, 2026, https://www.databasemart.com/blog/ollama-gpu-benchmark-a5000
    7. Ollama, which is better, GPU w/16GB VRAM or CPU w/128GB RAM - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/ollama/comments/1emx11m/ollama_which_is_better_gpu_w16gb_vram_or_cpu/
    8. Asus Ascent GX10 (with NVIDIA GB10 128GB) + Ollama and WebUI: The Headless Setup Guide | by Shamil Yagiyayev | Mar, 2026 | Medium, accessed on March 22, 2026, https://medium.com/@shamil.yagiyayev/asus-ascent-gx10-with-nvidia-gb10-128gb-ollama-and-webui-the-headless-setup-guide-a59c96fccbb9
    9. Installing the NVIDIA Container Toolkit, accessed on March 22, 2026, https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
    10. Ubuntu 24.04 + NVIDIA RTX 5070 (Blackwell) + Docker + VS Code – Full GPU Stack Install Guide - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/Ubuntu/comments/1mfvg3o/ubuntu_2404_nvidia_rtx_5070_blackwell_docker_vs/
    11. What are the recommended Docker container settings for running NVIDIA RTX A30 and RTX A5000 GPUs? - Massed Compute, accessed on March 22, 2026, https://massedcompute.com/faq-answers/?question=What%20are%20the%20recommended%20Docker%20container%20settings%20for%20running%20NVIDIA%20RTX%20A30%20and%20RTX%20A5000%20GPUs?
    12. Containers For Deep Learning Frameworks User Guide - NVIDIA Docs, accessed on March 22, 2026, https://docs.nvidia.com/deeplearning/frameworks/user-guide/index.html
    13. How to Optimize Docker for Memory-Intensive Applications - OneUptime, accessed on March 22, 2026, https://oneuptime.com/blog/post/2026-02-08-how-to-optimize-docker-for-memory-intensive-applications/view
    14. Optimizing Ollama Performance on Windows: Hardware, Quantization, Parallelism & More | by Kapil Khatik | Medium, accessed on March 22, 2026, https://medium.com/@kapildevkhatik2/optimizing-ollama-performance-on-windows-hardware-quantization-parallelism-more-fac04802288e
    15. Yesterday I used GLM 4.7 flash with my tools and I was impressed.. : r/LocalLLaMA - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/LocalLLaMA/comments/1qkqvkr/yesterday_i_used_glm_47_flash_with_my_tools_and_i/
    16. qwen-code CLI + Local Ollama: How to Enable Function Calling / File Modifications? : r/LocalLLM - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/LocalLLM/comments/1p6mr0g/qwencode_cli_local_ollama_how_to_enable_function/
    17. Qwen2.5 32b will start to put the tool calls in the content instead of the tool_calls : r/ollama, accessed on March 22, 2026, https://www.reddit.com/r/ollama/comments/1j30893/qwen25_32b_will_start_to_put_the_tool_calls_in/
    18. qwen2.5-coder/template - Ollama, accessed on March 22, 2026, https://ollama.com/library/qwen2.5-coder/blobs/e94a8ecb9327
    19. Qwen 2.5 Coder + Ollama + LiteLLM + Claude Code : r/LocalLLaMA - Reddit, accessed on March 22, 2026, https://www.reddit.com/r/LocalLLaMA/comments/1pqquuf/qwen_25_coder_ollama_litellm_claude_code/
    20. How We Rebuilt Settings in Zed — Zed's Blog, accessed on March 22, 2026, https://zed.dev/blog/settings-ui
    21. zed/docs/src/configuring-zed.md at main · zed-industries/zed - GitHub, accessed on March 22, 2026, https://github.com/zed-industries/zed/blob/main/docs/src/configuring-zed.md
    22. Keybindings | Key Bindings and Shortcuts - Zed, accessed on March 22, 2026, https://zed.dev/docs/key-bindings
    23. Config | OpenCode, accessed on March 22, 2026, https://opencode.ai/docs/config/
    24. Agents - OpenCode, accessed on March 22, 2026, https://opencode.ai/docs/agents/
    25. Opencode doesn't know the location of its config file #6156 - GitHub, accessed on March 22, 2026, https://github.com/anomalyco/opencode/issues/6156
    26. mariozechner/pi-coding-agent - NPM, accessed on March 22, 2026, https://www.npmjs.com/package/@mariozechner/pi-coding-agent
    27. pi-mono/packages/coding-agent/docs/settings.md at main - GitHub, accessed on March 22, 2026, https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md
    28. LLM Providers - Use Your Own API Keys in Zed, accessed on March 22, 2026, https://zed.dev/docs/ai/llm-providers
    29. Configure AI in Zed - Providers, Models, and Settings, accessed on March 22, 2026, https://zed.dev/docs/ai/configuration
    30. Zed with local LLMs with agentic editing · zed-industries zed · Discussion #33682 - GitHub, accessed on March 22, 2026, https://github.com/zed-industries/zed/discussions/33682
    31. pi.dev, accessed on March 22, 2026, https://shittycodingagent.ai/
    32. pi-mono/packages/coding-agent/docs/terminal-setup.md at main - GitHub, accessed on March 22, 2026, https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/terminal-setup.md
    33. pi-mono/packages/coding-agent/docs/packages.md at main · badlogic/pi-mono - GitHub, accessed on March 22, 2026, https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md
