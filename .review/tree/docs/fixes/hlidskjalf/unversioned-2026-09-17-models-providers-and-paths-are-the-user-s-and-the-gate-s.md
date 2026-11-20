## hlidskjalf · unversioned · 2026-09-17 — models, providers, and paths are the user's — and the gate says so

### Why
- **The law, amended (Rule 07).** Two clauses appended, the rule itself untouched:
  - **A. Models and providers live in the hoard, per user, read from YAML.**
    Every operator's differ, so there is **no global model or provider** — a
    shipped default naming a model is a claim about someone else's machine. The
    user's own live in `$YMIR_HOME/hodd/`, read from a YAML file there; the repo
    ships a template.
  - **B. No hardcoded absolute file paths.** No `$HOME<user>/…`, no
    `/Users/<user>/…`, no `C:\Users\…`. A path is relative to a resolved root or
    comes from env/config with one documented default.
- **The gate, `config`.** `compliance-check.sh` gains a check that fails on a
  model id or provider name used as a **value** in shipped code or a tracked
  config, and on an absolute path naming a user. Comments, `*.example` templates,
  `CHANGELOG*`, and `assets/reference/` are exempt by intent — they document,
  they do not configure. **192 files clean.**
- **Three real violations found and fixed:**
  - `.agents/config/eindri-dispatch.json` — three dispatch rules named
    `opencode-go/deepseek-v4.1-flash`. Now a template with `<your-model-id>`.
  - `.agents/skills/galdr-ymirsystem/assets/pi-boot/pi-profile.yml` — the PI boot
    profile named `lmstudio/qwen3.6-35b-a3b`. Now a placeholder.
  - `bin/bootstrap-macos.sh` — `$HOME/Documents/Ymir`. Now resolve

### Files
- *(carried from the frozen CHANGELOG.md)*
