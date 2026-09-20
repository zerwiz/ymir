## install · unversioned · 2026-09-19 — the system finds the user's models, and says what it found

### Why
- The Allfather: *"the system must find the users models from root pi."* It did not — the
  install reported that models would be "ensured" while never naming the file that declares
  them, so a roster naming a model the machine had never seen stayed invisible until an
  agent failed.
- `bin/models-report.sh` reads `$HOME/.pi/agent/models.json` — the ROOT pi home — and
  `step_models` logs it in both modes: *"the user's models — 7 providers / 54 models ·
  google,ollama,lmstudio,ollama-remote +3 more"*, or a loud WARN when the file is absent or
  unparseable. The line sits **before** the `--check` early return, so a dry run reports it
  too.

### Files
- `bin/models-report.sh`
