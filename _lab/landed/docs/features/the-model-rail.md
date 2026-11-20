# The model rail — local models

## What it is

The **model rail** is how Ymir finds and serves local models. The engine is a **machine
property** — a CUDA `llama.cpp` binary (or a build under the home), never in the code
tree. The rail **adopts** a standing CUDA `llama-server` rather than rebuilding, and it
**proves** the build is not CPU‑only (a CPU build "works" and is ~10× slow, which makes
every later measurement a lie).

## What you need

- A GPU (CUDA) for a local model; the installer's `local-model` step provisions the
  engine + a model that fits the *probed* hardware.

## Do it

```bash
bin/model/llama-ensure.sh ensure      # adopt a CUDA llama-server, or build one
bin/model/rail-resolve.sh status      # the ranked live set of rail URLs
bin/model/rail-resolve.sh resolve     # the serving OpenAI URL + the key REFERENCE
bin/model/model-fit.sh                # the largest model that fits this GPU/RAM/disk
bin/model/models-detect.sh            # what runtimes + models are here
```

Every surface that states a rail URL calls **`rail-resolve.sh`** — so none of them
restates one. Your router (the llama‑router) owns the endpoint and autoloads a model by
id; add the id to the harness config and go.

## Notes and limits

- **One model resident at a time** on a small card. `--models-max 1` means a request for
  a *different* model **evicts** the current one — every client on the rail must ask for
  the **same id**, or they evict each other. (This is a real trap; see the AnythingLLM
  note in the hoard.)
- **CUDA, proven.** `llama-ensure` requires `--list-devices` to print `CUDA0`.
- **The rail is machine state**, resolved from the hoard (Rule 04/07), never hardcoded.
- **Fit before fetch.** `model-fit.sh` chooses by *measured* hardware, not a guess.

## If it does not work

| What you see | What to do |
|---|---|
| `rail-resolve status` is empty | No rail is up — `bin/model/llama-ensure.sh ensure`, then start the router. |
| A model fails to load (OOM) | It does not fit — `bin/model/model-fit.sh` picks one that does. |
| Two clients evict each other | They request different model ids — align them to **one** id. |
| The engine is CPU‑only | Rebuild with CUDA: `bin/model/llama-ensure.sh ensure` proves `CUDA0`. |
