#!/usr/bin/env python3
"""bench_win_router.py — bench llama.cpp router models on zerwiz-1 (Windows).

Per skill method: warmup load (discard), then timed request on a FRESH prompt so
cache_n == 0 (true cold prefill). Timings come from the server's own `timings`
(prompt_per_second = prefill t/s, predicted_per_second = decode t/s).

Usage (Linux OS driving the Windows-side router):
    python3 bench_win_router.py                 # default endpoint below
    BENCH_BASE=http://<win-host-ip>:8080 python3 bench_win_router.py

NOTE 2026-09-09: GPU now CONFIRMED working after installing the cudart/cublas
companion DLLs (cudart-llama-bin-win-cuda-12.4-x64.zip) next to llama-server.exe
-- `--list-devices` shows CUDA0 16 GB and buffers are CUDA0. nvidia-smi needs NO
admin on this box. For VRAM/GPU util during a run, sample in a second shell:
    powershell.exe -NoProfile -Command "nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv"
"""
import json, os, time, urllib.request

BASE = os.environ.get("BENCH_BASE", "http://172.17.16.1:8080")
MODELS = ["qwen35-4b", "qwen35-4b-64k", "qwen3-4b", "gptoss", "gemma-r", "devstral"]

PROMPT = """We are a small dev team hiring flowers. Given the plant data below, write a concise
spec for a cold-hardy dry-garden starter mix (max 5 bullet points). Keep it practical.

Plant data: lavender (Z5-9, dry), salvia nemorosa (Z4-8, dry), echinacea (Z3-8),
yarrow (Z3-9, dry), agastache (Z5-10, dry), allium (Z4-8), stachys byzantina (Z4-8),
sedum telephium (Z3-9), ornamental grasses (miscanthus, panicum), achillea, anthemis,
coreopsis (Z4-9), gaillardia (Z3-10), penstemon (Z4-9), veronica (Z4-8),
nepeta (Z3-8), salvia officinalis (Z5-8), thyme (Z5-9), rosemary (Z6-10), santolina.
Multipliers for a power function:

Seed marker 7f3a9cd2 — ignore this line but include the marker in your reply."""

def chat(model, max_tokens, prompt):
    body = json.dumps({"model": model, "messages": [{"role": "user", "content": prompt}],
                       "max_tokens": max_tokens, "temperature": 0,
                       "cache_prompt": False}).encode()
    req = urllib.request.Request(BASE + "/v1/chat/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.load(r)
    wall = time.time() - t0
    return d, wall

print(f"{'model':<14} {'state':<8} {'prompt_tok':>10} {'cache':>5} {'wall_s':>7} "
      f"{'prefill_t/s':>11} {'decode_t/s':>10} {'TTFT_ms':>8} {'reply':>28}")
for m in MODELS:
    # 1) warmup: short DIFFERENT prompt forces load, discarded (KV stays on old text)
    try:
        chat(m, 5, "hi")
    except Exception as e:
        print(f"{m:<14} {'FAIL-WARM':<8} {repr(e)[:60]}")
        continue
    # 2) timed cold run (fresh long prompt => cache_n stays 0)
    try:
        d, wall = chat(m, 64, PROMPT + " " + m)
        ch = d["choices"][0]["message"]
        t = d["timings"]
        usage = d["usage"]
        content = (ch.get("content") or "").strip()
        reasoning = (ch.get("reasoning_content") or "").strip()
        prefill = t["prompt_per_second"]
        decode = t["predicted_per_second"]
        ttft = t["prompt_ms"]
        print(f"{m:<14} {'ok':<8} {usage['prompt_tokens']:>10} {usage.get('prompt_tokens_details',{}).get('cached_tokens',0):>5} "
              f"{wall:>7.1f} {prefill:>11.1f} {decode:>10.1f} {ttft:>8.0f} {(content or reasoning or '(empty)')[:26]:>28}")
    except Exception as e:
        print(f"{m:<14} {'FAIL':<8} {repr(e)[:80]}")
    time.sleep(1)