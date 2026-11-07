## model · 2026-11-06 — the decision model, remeasured by a second hand

Component: `~/.agents/skills/modeltesting/{backends-benchmark.md,llamacpp/TESTING.md,ledger.jsonl}`,
`~/CHANGELOG.md`. Machine: this box's A5000, throwaway server on `:9187`. Read with
[`2026-11-06-the-first-decision-model-on-the-rail.md`](2026-11-06-the-first-decision-model-on-the-rail.md),
which owns the fix itself — this note is the **independent verification**, and it corrects two of
that note's numbers.

### Why this note exists at all

The errand "seat the Jev decision models and measure them" was dispatched **twice** — `jev-preset-bench`
(this seat) and `jev-bench-two` (delivered first, branch `eindri/jev-bench-two` @ `57a8ba0b`). The second
hand took the same brief and found the work already done, so it did what a second hand is for: it measured
again, from scratch, and reported where the first measurement did not reproduce.

A duplicate errand is not wasted if the second one checks the first. It is wasted if it writes the same
records twice — so nothing here duplicates the sibling's note, and no append-only record was rewritten.

### What reproduced exactly (the door is real)

Julia-1 was served by a throwaway `llama-server` (Jev CUDA build, `0.7.0-dev` commit `5aeac37`,
`-ngl 999 -c 4096`, `/props`-verified `n_ctx 4096`, card 56 MiB baseline → 345 MiB resident) and asked the
same `choice` question, "which team should handle this customer message?", with criteria descriptions:

```
choice "billing"   p 0.9994931625235761   confidence 0.9992397437853642   input_tokens 76
```

Every digit is **identical to the sibling's run** — same model, same seed 42, same temp 0. The same request
with **bare labels** (`criteria: {"billing": null, …}`) returns `shipping 0.8943524567389909`,
`confidence 0.8415286851084863`, `input_tokens 38` — also digit-identical. Determinism across two
independent hands and two independent servers is proved, and so is the description effect: **same model,
same state, same question; only the criteria changed, and the routing fell into the wrong bucket.**

### What did not reproduce — 84.0/s was the harness, not the model

The sibling recorded **84.0 decisions/s at 3 options** and **67.4 at 12**. Measured again here with a
persistent HTTP connection (one socket, keep-alive, no per-call setup), 5 warmups discarded, then 5 runs ×
100 timed decisions per option count:

| options | median decisions/s | range | mean | p95 | input tokens |
|---|---|---|---|---|---|
| 3 | **112.42** | 102.60 – 112.69 | 8.9 ms | — | 76 |
| 12 | **75.59** | 73.68 – 76.24 | 13.2 ms | — | 155 |

So the loop number is **~34% higher at 3 options and ~12% higher at 12** than the first record. The
difference is not the card and not the model: the first harness paid a connection setup per decision, and
this one does not. Both figures are true and they answer different questions:

- **84/s is the end-to-end floor for a client that reconnects** — plan capacity with it.
- **112/s is what the model itself will do** on a held connection — plan a tight loop with it.

Tripling the options costs **33% of throughput** on a held connection (vs 20% on the reconnecting one),
which is the more honest shape: options cost tokens, and tokens now dominate.

### Correction — the router does **not** advertise the decision modality

The sibling's note and its §"Proof" claim `GET /v1/models` reports `"output_modalities":["decisions"]` for
the alias. Measured today, with and without `?reload=1`:

```
julia-1@q8_0  →  architecture: {"input_modalities": ["text"], "output_modalities": ["text"]}
                context_length: absent       source: "preset"
```

llama-swap does not read the GGUF's decision metadata, so it advertises **text**. This matters, and it cuts
against trusting the catalogue: a client that routes on `output_modalities` will send a chat turn to a
decision model and receive **501**, not a decision. **Probe the endpoint, never the catalogue** — the same
law the sibling's own §19.11 already states, applied to the field it trusted.

The 404 on `:8080/v1/systemone` is unchanged and still the trunk binary (`0.4.1-dev`, `73c941b`, loaded from
`/usr/local/lib/libllama-server-impl.so`, which carries no `systemone` route). That root step remains owed;
nothing in this note changes it.

### The rail print, for the record

`[julia-1@q8_0]` is seated and the router lists it (43 models served today, not the 39 the first note saw —
the rail has grown since). Its preset args, as the router itself prints them, inherit the `[*]` global
exactly: `--jinja --temperature 0 --seed 42 --reasoning off --parallel 1 --flash-attn 1 --ctx-size 4096
--n-gpu-layers 999`, weights at `llama-swap-models/julia-1-q8_0/model.gguf`.

`.pi/agent/models.json` is **still rightly without the alias** — a decision GGUF cannot drive a chat turn,
and this measurement confirms the transport reports text, which would make such an alias a promise the
model cannot keep. The sibling's reasoning stands; only its evidence for it was wrong.

**OpenJev** (CC BY-NC) was not seated, not benchmarked, and appears in no preset in this note. It must never
reach anything commercial-facing.

### Files

- `~/.agents/skills/modeltesting/backends-benchmark.md` — §10.5.21 appended
- `~/.agents/skills/modeltesting/llamacpp/TESTING.md` — §19.13 appended
- `~/.agents/skills/modeltesting/ledger.jsonl` — one new line, `heimdall/julia-1@q8_0`, `2026-11-06`
- `~/CHANGELOG.md` — the dated entry for this machine

Nothing under `~/.config/llama-rail/` was changed by this hand: the preset was already seated and correct.

### What remains

- **The root restart** — `:8080/v1/systemone` answers 404 until `llama-swap.service` runs a binary that
  carries the route. Unchanged, and still the Allfather's one command.
- **The gate drift found on the way** — `bin/gates/fixes.sh` knows ten components (`install runtime skills
  agents seat hlidskjalf odrerir sessrumnir smidja hoard gate`) while `docs/fixes/` holds at least
  `model`, `collab`, `desktop`, `assistant`, `clients-register` and more. `fixes.sh validate` therefore
  reports them as *unknown component directory* and never checks their headers, and its header regex wants
  a semver or `unversioned` where these directories use a date. A gate that skips a shelf is the same
  false green this house has paid for before; it wants its own errand.
