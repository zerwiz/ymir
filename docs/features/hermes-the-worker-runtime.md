# Hermes — the worker runtime

## What it is

**Hermes** is Nous Research's open‑source **agent runtime** (MIT) — its own brain,
config, memory, skills, scheduling, and isolated subagents. Ymir **adopts** it as a
worker runtime (an external engine, like Pi or OpenCode). The name is the product's,
never a Norse rename.

## What you need

- Ymir installed. The installer's `hermes` step provisions it when absent; config and
  identity stay **yours**.

## Do it

```bash
bin/engine/hermes-ensure.sh status            # is the runtime present?
bin/engine/hermes-ensure.sh ensure --install  # provision it if absent
```

Then drive it as a harness: it is one of the harnesses an agent can run on
(`config/agents.yaml` picks the harness per agent — `pi | opencode | claude | codex |
gemini | hermes | …`), and `bin/agents/agent-run.sh <agent> "<task>"` runs an errand
through whatever you chose.

## Notes and limits

- **Ymir guarantees the runtime exists, not your data.** Hermes's config, keys, memory
  and skills are the operator's own; Ymir never overwrites them.
- **It is a worker, not the primary.** Brokk stays the primary; Hermes is one engine a
  worker can run on.
- **MIT.** Compatible with Ymir's Apache‑2.0.

## If it does not work

| What you see | What to do |
|---|---|
| `status` says absent | `bin/engine/hermes-ensure.sh ensure --install`. |
| An agent cannot use it | Set its harness to `hermes` in `config/agents.yaml`, then `bin/fleet/agents-config.sh apply`. |
| A model never answers | The model rail/bridge is down — `bin/agents/eir-doctor.sh fix`. |
