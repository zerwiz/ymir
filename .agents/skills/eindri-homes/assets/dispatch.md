# Dispatching an Eindri — the full chain

How a request becomes a seated, running worker. Every link is a real script; the
chain must never guess a model or skip the lock.

```
dispatch[8]{step,who,what}:
  "1 request","Allfather / Brokk","a task, optionally naming a model or locality"
  "2 role","bin/eindri-role.sh choose","pick the smith by craft (whole-word match)"
  "3 model","bin/model-resolve.sh resolve","friendly/exact -> {locality,harness,provider,model}; unresolved -> ASK"
  "4 harness","config/agents.yaml harness rule","local -> pi, online -> opencode (agent may pin harness:)"
  "5 seat","bin/herdr-run.sh eindri (or bin/eindri-start.sh)","herdr pane/tab/space; --model resolution happens here"
  "6 lock","bin/local-model-lock.sh","serialize local inference per host (local_concurrency)"
  "7 register","a2a MCP (a2abridge bridge)","agent announces its card; reachable over A2A"
  "8 report","herdr agent list / Hlidskjalf Fleet","state: working/blocked/done; tasks from Runes"
```

## The commands

```bash
# resolve a request (no side effects)
bin/model-resolve.sh resolve "qwen 3.6 iq2"
#  -> locality=local harness=pi provider=llama-cpp model=qwen3.6-35b-a3b@q2_k_xl

# seat the right smith on the right model, in a visible pane
bin/herdr-run.sh eindri bragi --model "qwen 3.6 iq2" -- "do marketing research"
# convenience front door:
bin/eindri-start.sh "do marketing research"        # role + seat; add --model to pin
```

## Rules (non-negotiable)

- **One local model at a time per machine** — route local runs through
  `bin/local-model-lock.sh` (`local_concurrency` in `config/agents.yaml`).
- **Local → `pi`, online → `opencode`** — unless an agent pins `harness:`.
- **Never guess a model** — a low/medium confidence resolve for an explicit
  request must **ask** (`ask_user_question`).
- **A model token must be servable** — match `pi --list-models` and the running
  llama server `/v1/models`; `iq2` has no id today (nearest `q2_k_xl`).
- **Seat visibly** — a pane beside the work; never a hidden process.

## Known gaps to close (to 100%)

1. `local-model-lock.sh` not yet on the inference path (a pane can't be wrapped;
   lock the run, not the TUI).
2. Resolver tie-breaks (prefer family+size+newer gen+the agent's configured model).
3. Servability check against the live server.
4. `ask_user_question` wiring on unresolved/ambiguous.
5. `eindri-start.sh --model` passthrough.
6. No dedicated A2A/MCP skill (`ratatoskr`) or Hlidskjalf-UI skill yet.
