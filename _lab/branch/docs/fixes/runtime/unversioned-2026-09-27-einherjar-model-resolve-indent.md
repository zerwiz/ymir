## runtime · unversioned · 2026-09-27 — einherjar's model resolver died of indentation

### Why

Every `bin/agents/einherjar-spawn.sh` run that reached the model-resolution road
failed: `agent_yaml_local_providers()` embeds a python heredoc whose statements
mixed column-zero and two-space indentation, so python raised `IndentationError`
at `home = os.environ.get("YMIR_HOME")` and the spawn answered *"model request
could not be resolved — ask the Allfather which model"*. The machine's own
dispatch gate was broken by a transcription slip, not by any model choice: the
concrete token `opencode-go/deepseek-v4.1-flash` resolved cleanly the moment the
block was normalized.

- The heredoc's function body now sits at column zero like its sibling helpers,
  nested blocks at four spaces. `bash -n` clean; a fresh spawn's preflight
  resolves the model and prints the launch shape.
- Found 2026-09-27 while dispatching the P6-gateway / Phase-1-engine / heart
  migration errands on the Allfather's word (deepseek v4.1 in pi). This is the
  shape of the smoothness he named: a one-space slip in a bash-bound heredoc
  blocked the whole dispatch road until the engine (plan 58 Phase 1) gives the
  spawn a real interface.

### Files

- `bin/agents/einherjar-spawn.sh`