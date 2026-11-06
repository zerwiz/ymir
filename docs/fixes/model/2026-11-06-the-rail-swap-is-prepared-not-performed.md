# The rail's binary swap: prepared and proven, not performed (it needs root)

**2026-11-06 · component: model · `/usr/local/bin/llama-server` · `llama-swap.service`**

His word: *"Replace the rail's binary so :8080 serves the endpoint its catalogue already advertises."*

## Why it cannot be done from this session

`sudo -n true` → **`sudo: a password is required`**. Both the binary (`/usr/local/bin/llama-server`) and the unit
(`/etc/systemd/system/llama-swap.service`) are root-owned. So the swap is prepared, tested and reversible — and **one command
is left for the Allfather**.

## What was proved on a spare port, before touching anything

A user-level copy of the candidate engine, started with **the rail's own preset file**, on `:8085`:

```
engine   ~/.local/opt/jev-cuda/engine/llama-server   (b12138, CUDA 12.8 + cudart on LD_LIBRARY_PATH)
args     --models-preset ~/.config/llama-rail/models.ini --models-max 1 --sleep-idle-seconds 900
```

```
proved[3]{door,result,evidence}:
  "the catalogue","39 models, the same ids the rail advertises",'`GET /v1/models` -> 39, including `julia-1@q8_0` and both qwen3.6 presets'
  "a chat model","loads and answers on the NEW engine",'`{"content":"OK"}` from `qwen3.6-35b-a3b@q2_k_xl`, `system_fingerprint: b12138-f7b41cca4`'
  "the decision endpoint","`POST /v1/systemone` answers through the SAME router",'"the well bridge is down" -> `signal 0.9997`, 34 input tokens'
```

**The first attempt failed, and the reason is the more useful finding:**

```
cudaMalloc failed: out of memory — 11.4 GiB requested on a 16 GiB card
```

Not an incompatibility: my **four Jev doors were holding 11.6 GiB**. With them stopped, the same chat model loaded at once.
So the rule this box must live by is the one already written for the rail: **one resident at a time** — and four decision
doors are not "small" when each takes a window.

## The one command, for the operator

```bash
# 1 · keep the old engine (rollback is a mv)
sudo cp /usr/local/bin/llama-server /usr/local/bin/llama-server.bak-20261106

# 2 · put the candidate in its place, with its runtime beside it
sudo install -Dm755 ~/.local/opt/jev-cuda/engine/llama-server /usr/local/bin/llama-server
sudo install -Dm644 ~/.local/opt/jev-cuda/cudart/libcudart.so.12 /usr/local/lib/libcudart.so.12
sudo ldconfig

# 3 · raise the rail and prove the two doors
sudo systemctl restart llama-swap
curl -s http://127.0.0.1:8080/v1/models -H "Authorization: Bearer $KEY" | head -c 120
curl -s -X POST http://127.0.0.1:8080/v1/systemone -H "Authorization: Bearer $KEY" \
  -H 'content-type: application/json' \
  -d '{"model":"julia-1@q8_0","state":"x","questions":{"q":{"type":"noul","instructions":"ok?"}}}'
```

**Rollback:** `sudo mv /usr/local/bin/llama-server.bak-20261106 /usr/local/bin/llama-server && sudo systemctl restart llama-swap`.

## What this changes for the four decision doors

They must stop competing with the rail for the card. The honest arrangement after the swap is **the rail serves everything**,
and the separate `jev-*` units are retired to on-demand — one resident model, whichever the caller needs.

## CHANGE LOG

- **2026-11-06** — the candidate engine proven on the rail's own presets, the VRAM contention found and named, and the single
  root command handed over with its rollback (Hœnir).
