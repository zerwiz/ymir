## runtime · unversioned · 2026-09-17 — the model that raised itself, and the workhorse that replaced it

### Why
- **A model raised itself at login and killed the session.** `qwen3-6-35b-a3b`
  carried `[Install] WantedBy=default.target`, so systemd started it at
  12:36:33; with `--no-mmap` on a unified-memory APU the weights were
  unreclaimable, memory and swap drained, and the kernel's global OOM killer took
  `gnome-shell` — and the Ymir stack with it. `local-models.md` §4 gains
  **three traps** from this (anonymous load on unified memory; backend chosen by
  reputation rather than measurement; reasoning configured through the chat
  template), and a new **§12** states the rule: a model service unit must never
  raise itself.
- **`§11 — Reasoning is a resource you must configure`** is new. Unbounded
  reasoning fails *totally* — no answer at all — not merely worse. The same model
  on the same request produced clean, degenerate (repetition), or unterminated
  output depending only on how reasoning was configured. Prefer the engine's
  native budget flag; the chat-template keyword is a different mechanism.
- **Seated a new local workhorse** (a 176B-parameter MoE, Vulkan backend, MTP
  speculative decoding, file-backed load). Measured before seating: prefill and
  decode both at parity with the reference stack for this silicon. The per-host
  record belongs in the hoard, not here — §6.
- **Ran a 32-run A/B on guidance during reasoning** (counsel at the moment of
  failure vs counsel u

### Files
- *(carried from the frozen CHANGELOG.md)*
