# DeepSeek V4 Flash 284B — Best CPU Settings (from Colibri vs llama.cpp video)

> **Source**: [Running DeepSeek-V4-Flash (284B MoE) on a 64GB Strix Halo via SSD expert-streaming](https://gist.github.com/AlexsJones/9b43e7b8f3682679d17f255a3ca0d9d3) — the config used in the YouTube video "Colibrì vs llama.cpp: Running DeepSeek V4 284B on CPU"

---

## Hardware Target (Video Benchmark Machine)

| Component | Specification |
|-----------|---------------|
| **CPU** | AMD Ryzen AI Max+ 395 (16C/32T Zen 5) — Strix Halo |
| **RAM** | 62 GiB unified LPDDR5X (~256 GB/s) |
| **SSD** | NVMe ~3.8 GB/s read |
| **OS** | Fedora 43 (Linux) |
| **GPU** | **NOT used** — unified memory = no decode bandwidth win; sidesteps missing GPU kernels |

---

## Model (Video Benchmark)

| Property | Value |
|----------|-------|
| **Quant** | `DeepSeek-V4-Flash-IQ2XXS-...-imatrix.gguf` (2-bit, ~81 GB on disk) |
| **Architecture** | 284B MoE, 256 routed experts, top-6 per token, 13B active/token |
| **Key insight** | Only **6 of 256 experts fire per token** → enables SSD streaming |

---

## Required llama.cpp Fork

Stock llama.cpp **cannot** load V4 (novel arch: lightning indexer, DeepSeek Sparse Attention, MLA compressor, hyper-connections).

```bash
git clone https://github.com/antirez/llama.cpp-deepseek-v4-flash llama-v4-src
cd llama-v4-src
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON -DGGML_OPENMP=ON -DLLAMA_CURL=OFF
cmake --build build -j
```

---

## Optimal Runtime Flags (CPU-only)

```bash
./build/bin/llama-completion \
  -m ~/models/dsv4/DeepSeek-V4-Flash-IQ2XXS-...-imatrix.gguf \
  -t 6 \                 # 4–6 threads is OPTIMAL. More cores = SLOWER (memory-bandwidth bound)
  -c 4096 \              # explicit context; too-small context => compressor-cache assert
  --mmap \               # REQUIRED and INVERTED from usual: mlock OFF. Streams experts from SSD.
  -fa on \               # REQUIRED with quantized KV, else llama_new_context() aborts
  -ctk q8_0 -ctv q8_0 \  # shrink KV to leave RAM for expert pages (MLA KV is tiny anyway)
  -n 200 -no-cnv \
  -p "Explain how mixture-of-experts models work:"
```

---

## Why These Settings Work

| Setting | Reason |
|---------|--------|
| **`-t 4` or `-t 6`** | Measured decode tok/s: 2→1.29, **4→1.98**, 6→1.87, 8→1.81, 16→1.05, 32→0.22. Extra threads fight over the single LPDDR5X bus and thrash page-fault path. **`-t 4` beats `-t 32` by 9×.** |
| **`--mmap` ON, `mlock` OFF** | Opposite of normal local models. You *can't* lock 81 GB into 62 GB. mmap lets OS cache hot core (~13 GB dense/attention) and evict cold expert pages. mmap'd pages are file-backed = always reclaimable = never trigger system OOM. |
| **`-fa on`** | Mandatory with `-ctk/-ctv q8_0` (MLA attention) or context creation asserts. |
| **`-ctk q8_0 -ctv q8_0`** | Quantized KV cache shrinks KV footprint, leaves RAM for expert pages. |
| **`-c 4096`** | DeepSeek Sparse Attention cache sized from `n_ctx`. Too-small context triggers `GGML_ASSERT(n_comp_visible <= n_comp_cache)` in `deepseek4.cpp`. |
| **No `MemoryMax`** | Charges the model and forces evict+re-read thrashing (measured 211+ reads/sec). |

---

## Thread Scaling Table (Measured)

| Threads | Decode tok/s | Notes |
|---------|--------------|-------|
| 2       | 1.29         |       |
| **4**   | **1.98**     | **MAX decode throughput** |
| 6       | 1.87         | Best prefill + near-best decode |
| 8       | 1.81         |       |
| 16      | 1.05         |       |
| 24      | 0.70         |       |
| 32      | 0.22         |       |

> **Use `-t 4` for max decode, `-t 6` for best prefill + near-best decode.**

---

## Long Context / Prefill Tips

- **Long prefill batch**: chunk with `-ub 128 -b 128`
- **Long generation**: just pass real `-c` (e.g., 4096)
- **Under `llama-bench`** it looks like ~128-token cap — that's a bench artifact (tight context), not a real limit

---

## What NOT to Do

| ❌ Avoid | Why |
|----------|-----|
| Increase threads beyond 6 | Thrashes memory bus, kills throughput |
| Use `mlock` | Causes OOM/thrashing (can't lock 81 GB into 62 GB) |
| Add `MemoryMax` | Forces evict+re-read thrashing (211+ reads/sec measured) |
| Expect GPU to help decode | Unified memory = no bandwidth win |
| Use MTP speculative decode | IO-bound: verifying K draft tokens still streams K×(6×43) experts |

---

## Expected Performance (Video Machine)

| Metric | Value |
|--------|-------|
| **Decode** | ~1.9 tok/s (coherent, usable for offline reasoning) |
| **Prefill** | ~6 tok/s |
| **Model load** | Streams from SSD on demand (mmap) |
| **RAM usage** | ~62 GiB (fits in 62 GiB unified memory) |

---

## Summary Cheatsheet (DeepSeek V4)

```bash
# Build
git clone https://github.com/antirez/llama.cpp-deepseek-v4-flash llama-v4-src
cd llama-v4-src
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON -DGGML_OPENMP=ON -DLLAMA_CURL=OFF
cmake --build build -j

# Run (optimal CPU-only)
./build/bin/llama-completion \
  -m <path-to-IQ2XXS.gguf> \
  -t 6 \
  -c 4096 \
  --mmap \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  -n 200 -no-cnv \
  -p "Your prompt here"
```

---

## Key Insight (DeepSeek V4)

> **For MoE models larger than RAM, tune threads DOWN, not up.**
> The sparsity (6/256 experts) + mmap + fast SSD makes "bigger than RAM" solvable.

---

# Additional Technical Analysis: Large MoE Models in llama.cpp

## Key Bottlenecks & Required Configuration Flags

When running a model significantly larger than system memory (e.g., 162 GB model on 61 GB RAM), llama.cpp defaults to attempting to construct a rewritten, vector-optimized model layout in fresh memory. This leads to out-of-memory errors before execution begins. Disabling repacking and managing expert execution on the CPU resolves this issue.

### Essential CLI Flags

| Flag / Parameter | Function | Why It Is Required |
|------------------|----------|-------------------|
| `--no-repack` (or `-nr`) | Disables weight repacking/reorganization | Prevents llama.cpp from allocating fresh RAM to transform quantized weights for CPU vector instructions, avoiding the allocate-RAM startup crash |
| `--override-kv` / CPU Expert Flags | Forces MoE expert weights to remain on system CPU/RAM | Ensures expert layers are handled on CPU memory via mmap paging rather than overwhelming GPU VRAM |
| `--mmap` | Enables memory-mapped file I/O (OS page paging) | Allows the OS kernel to stream model weight pages on demand from fast NVMe storage instead of loading everything into physical RAM at once |

---

## Performance Benchmarks: llama.cpp vs Colibrì (Prompt Processing)

| Prompt Length (Tokens) | llama.cpp Processing Speed | Colibrì Processing Speed |
|------------------------|---------------------------|-------------------------|
| 21 tokens | 0.9 tokens/sec | 0.9 tokens/sec |
| 194 tokens | 3.3 tokens/sec | 0.95 tokens/sec |
| 769 tokens | 6.2 tokens/sec | 0.93 tokens/sec |
| 3,000 tokens | 8.1 tokens/sec | 0.8 tokens/sec |

> While Colibrì offers faster initial time-to-first-token (25s vs. 100s) on tiny prompts by avoiding mmap population, llama.cpp outperforms drastically as prompt length increases due to batch processing capabilities.

---

## Recommended Setup Workflow (General)

1. **Quantization**: Use unsloth Q8 / full precision GGUF or standard quantized GGUF variants
2. **Storage**: Store models strictly on a fast NVMe SSD (capable of ≥3 GB/s sequential reads) to prevent disk I/O bottlenecks during layer streaming
3. **GPU Offloading**: Offload only dense attention layers to GPU VRAM (e.g., ~6.5 GB VRAM utilization for non-expert layers), keeping the 11,000+ expert networks paged on system RAM/NVMe

---

# Your Machine: Dell Precision 7560 — Qwen 3.6 35B-A3B Benchmarks

## System Specifications

| Component | Specification |
|-----------|---------------|
| **Hardware Model** | Dell Inc. Precision 7560 |
| **Memory** | 128.0 GiB |
| **Processor** | 11th Gen Intel® Core™ i9-11950H × 16 |
| **Graphics** | Intel® UHD Graphics (TGL GT1) |
| **GPU** | NVIDIA RTX A5000 Laptop GPU (16 GB VRAM) |
| **Disk** | 1.0 TB |
| **OS** | Ubuntu 26.04.1 LTS (Kernel 7.0.0-30-generic) |
| **Firmware** | 1.48.0 |

---

## Your Downloaded Qwen 3.6 35B-A3B Quants (Unsloth Dynamic)

| Model Quant | Download Size | VRAM / RAM Allocation Strategy | Performance & Quality |
|-------------|---------------|--------------------------------|----------------------|
| **Q4_K_S** | 22.7 GB | Offload ~14 GB to RTX A5000 VRAM, ~9 GB to System RAM | **Best Sweet Spot** — Highest quality of the three with minimal quantization degradation. Expected: ~10–14 tok/s |
| **IQ3_S** | 15.5 GB | Fits **ENTIRELY** into 16 GB VRAM | **100% GPU Execution** — Maximum generation speed: ~18–25+ tok/s |
| **Q2_K_XL** | 14.1 GB | Fits **ENTIRELY** into 16 GB VRAM | Ultra-fast, lower precision. Noticeable accuracy loss on complex logic/coding vs Q4_K_S |

---

## Expected Speeds by Configuration

### Setup 1: Heavy GPU Offloading (Best Daily Performance) — Q4_K_S
- **Quant**: Q4_K_M (~21 GB total footprint)
- **GPU VRAM**: ~14 GB offloaded to RTX A5000
- **System RAM**: ~7–8 GB paged
- **Generation (Output)**: **10–15 tokens/sec**
- **Prompt Processing (Ingestion)**: **150–300+ tokens/sec**

### Setup 2: Peak Speed — IQ3_S (Fully in VRAM)
- **Quant**: IQ3_S (15.5 GB)
- **GPU VRAM**: 100% offloaded (`-ngl 99`)
- **System RAM**: Near-zero usage
- **Generation (Output)**: **18–25+ tokens/sec**
- **Prompt Processing (Ingestion)**: Very fast

### Setup 3: Maximum Quality / Large Context — Q8_0 or FP16 in System RAM
- **Quant**: Q8_0 (~37.5 GB) or FP16 (~70 GB)
- **Flags**: `--mmap --no-repack` (or `-nr`)
- **Generation (Output)**: **2–5 tokens/sec** (bottlenecked by DDR4 ~40–50 GB/s)
- **Prompt Processing (Ingestion)**: **15–35 tokens/sec**

---

## Recommendations

| Use Case | Recommended Quant | Why |
|----------|-------------------|-----|
| **Daily coding, complex tasks, architectural work** | **Q4_K_S** (22.7 GB) | Best quality/speed balance. Offload ~13–14 GB to VRAM, ~9 GB to system RAM. ~10–14 tok/s. |
| **Agentic setups, quick chats, max response speed** | **IQ3_S** (15.5 GB) | Fits 100% in VRAM. `-ngl 99` → ~18–25+ tok/s. No system RAM bottleneck. |
| **Maximum precision, huge context windows** | **Q8_0** or **FP16** | Use `--mmap --no-repack`. ~2–5 tok/s but unlimited context headroom (128 GB RAM). |

---

## Critical: Why Video Settings Would SLOW DOWN Your Machine

> **The flags in the video (`--no-repack`, CPU-only expert routing) are a salvage strategy for under-spec hardware running models 2.5× larger than RAM.**

| Setting | Video Machine (61 GB RAM, 162 GB model) | Your Machine (128 GB RAM, 14–22 GB model) |
|---------|------------------------------------------|-------------------------------------------|
| `--no-repack` | **Required** — no RAM for weight conversion | **Harmful** — disables AVX/AVX-512 optimizations, drops CPU speed significantly |
| CPU-only experts | **Required** — GPU holds only 4% of model | **Harmful** — wastes 16 GB RTX A5000; IQ3_S fits 100% in VRAM |
| `--mmap` | **Required** — streams from SSD | **Useful** — but not for crash avoidance |

### Speed Comparison on Your Hardware

| Execution Mode | Generation Speed | Why |
|----------------|------------------|-----|
| **GPU Offloaded (Your Best Setup)** | **10–20+ tok/s** | Weights run on RTX A5000 VRAM at ~512 GB/s bandwidth |
| **Video Settings (`--no-repack` + CPU Experts)** | **2–5 tok/s** | CPU AVX disabled; bottlenecked by DDR4 system RAM (~40–50 GB/s) |

**Your GPU offload is 3× to 5× faster than the video's settings.**

---

## RAM vs VRAM: What Determines What

| Determines | Hardware Component | Your Specs | Result |
|------------|-------------------|------------|--------|
| **SIZE (Capacity)** | System RAM + GPU VRAM | 128 GB + 16 GB = 144 GB total | Can fit massive models (70B+ dense, 200B+ MoE) |
| **SPEED (Tokens/sec)** | Memory Bandwidth | GPU VRAM: ~512 GB/s<br>System RAM: ~40–50 GB/s | Layers in VRAM = fast (15–30+ tok/s)<br>Layers in RAM = slow (2–8 tok/s) |

---

## Bottom Line for Your Workstation

**Qwen 3.6 35B (3B active params) sits in your sweet spot:**
- Small enough active footprint for snappy speeds on RTX A5000
- 128 GB RAM gives unlimited headroom for heavy context windows
- **Use IQ3_S for speed, Q4_K_S for quality** — don't apply DeepSeek V4 salvage flags