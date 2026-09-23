## runtime · unversioned · 2026-09-23 — agents-config.sh runs again (an unbound state dir killed every verb)

### Why
- **`bin/agents-config.sh` died on line 35 for every verb.** It resolved
  `RESOLVED="${YMIR_STATE_DIR}/agents-resolved.json"` but only ever called
  `hoard_settings_dir` and `hoard_local_env` — never `hoard_state_dir`. Under
  `set -u` the unbound `YMIR_STATE_DIR` aborted the script before any action ran:

  ```
  $ bin/agents-config.sh get kvasir model
  bin/agents-config.sh: line 35: YMIR_STATE_DIR: unbound variable
  ```

  So `show`, `get`, `resolve`, `apply` and `init` were all dead. **The agent/model
  map could not be read or applied at all** — a configured model never reached
  the canonical `.agents/agents/*.md`, and `bin/agent-run.sh` had no cache to
  read.
- The state path belongs to the operator's home (Rule 04), which is exactly what
  `hoard_state_dir` resolves; the call was simply missing.

### Fix
- **`bin/agents-config.sh`** — call `hoard_state_dir YMIR_STATE_DIR` beside the
  other two hoard resolvers, before `RESOLVED` is built.

### Verification
- `bash -n` clean.
- `bin/agents-config.sh get kvasir model` now answers
  `llama-cpp/qwen3.6-35b-a3b@q2_k_xl` instead of aborting.

### Files
- `bin/agents-config.sh`
