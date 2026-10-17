## runtime · unversioned · 2026-10-17 — the CLI resolves the home per machine, not the stale Documents/Ymir

### Why
ymir.js defaulted YMIR_HOME to $HOME/Documents/Ymir, so every run on a machine whose real home is ymirhome (or Termux) created a phantom dir and failed the eir hoard check. It now resolves env -> ~/.config/ymir/home -> the canonical ymirhome.

### Files
- `bin/engine/ymir.js`