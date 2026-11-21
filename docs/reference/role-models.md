# Role models — three ready-made `roles:` files

Copy the block that matches your machine into `config/agents.yaml` in your home (or into
`config/agents.<hostname>.yaml` for one machine). The how-to is
[`choose-the-models-your-judges-and-coders-run`](../features/choose-the-models-your-judges-and-coders-run.md).
Replace the model names with ones your machine lists: `bin/model/catalog.sh`.

## Only local models

No key, no network. Every choice is a local model served through `pi`.

```yaml
roles:
  judge: [pi:llamacpp-host/your-largest-local-model]
  coder:
    choose: [pi:llamacpp-host/your-coding-model, pi:llamacpp-host/your-largest-local-model]
    yolo: on
  scout: [pi:llamacpp-host/your-small-local-model]
  helm:  [pi:llamacpp-host/your-largest-local-model]
```

Only one local model is resident at a time on most machines, so a judge and a coder on different
local models take turns; the house's local-model lock enforces it.

## Only hosted models

```yaml
roles:
  judge: [claude:opus, pi:opencode-go/deepseek-v4.1-flash]
  coder:
    choose: [claude:sonnet, pi:opencode-go/deepseek-v4.1-flash]
    yolo: on
  scout: [claude:haiku, pi:opencode-go/deepseek-v4.1-flash]
  helm:  [claude:opus]
```

The second choice is the fallback when the first is not on your allow-list or its key is missing.

## Both: hosted first, local as the fallback

```yaml
roles:
  judge: [claude:opus, pi:llamacpp-host/your-largest-local-model]
  coder:
    choose: [claude:sonnet, pi:opencode-go/deepseek-v4.1-flash, pi:llamacpp-host/your-coding-model]
    yolo: on
  scout: [pi:opencode-go/deepseek-v4.1-flash, pi:llamacpp-host/your-small-local-model]
  helm:  [claude:opus, pi:llamacpp-host/your-largest-local-model]
```

A laptop with no key skips the hosted choices (named by `bin/model/role-model.sh <role> --explain`)
and lands on the local one.

## One machine differs

In `config/agents.<hostname>.yaml`:

```yaml
roles:
  coder:
    choose: [pi:llamacpp-host/your-coding-model]
    yolo: off
```

Only `coder` changes on that machine. `judge`, `scout` and `helm` keep the fleet file's lists.

## CHANGE LOG

- 2026-11-21 — added with the role resolver.
