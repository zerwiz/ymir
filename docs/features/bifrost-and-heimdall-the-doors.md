# Bifrost and Heimdall — the bridge and the ward

## What it is

Two doors between realms:

- **Bifrost** — the bridge. Two senses, one idea: (a) the **model bridge** that keeps an
  OpenAI‑compatible endpoint alive for the harness so a session never 401s, and (b) the
  **ingress gateway** that routes external traffic in.
- **Heimdall** — the watchman. He admits an entrant only by the **rune of introduction**
  they carry: the SSH keys published to the operator's GitHub, validated, merged into
  `authorized_keys`, and refreshed.

## What you need

- Ymir installed. The bridge auto‑selects a provider (with no key, a local model server),
  and Heimdall needs the operator's GitHub user recorded.

## Do it

**Bifrost — the model bridge:**

```bash
bin/bridge/bifrost-bridge.sh            # raise the model bridge (keeps the endpoint alive)
```

Provider is the operator's choice (`YMIR_MODEL_PROVIDER`): `opencode-go` (needs a key),
`lmstudio` (keyless, local), or `openai-compatible`. With no key it auto‑selects the
local route, so a fresh install with a local model server just works.

**Heimdall — the ssh‑key ward:**

```bash
bin/host/heimdall-ensure.sh status     # is the ward armed?
bin/host/heimdall-ensure.sh ensure     # arm it (fetch, validate, merge keys; 15-min timer)
```

One key published to your GitHub opens every warded computer; the ward refreshes it.

## Notes and limits

- **No provider is forced to need a key.** A local model server works out of the box.
- **Heimdall is key‑only.** It admits by the rune you publish, not a shared secret; the
  refresh means a revoked key drops off within the timer window.
- **The ingress is opt‑in.** External routing (the gateway) is raised deliberately; the
  tunnel ([Hlidskjalf](hlidskjalf-the-control-plane.md)) is the usual path in.

## If it does not work

| What you see | What to do |
|---|---|
| A session 401s / the model never answers | `bin/bridge/bifrost-bridge.sh` — the bridge is down. |
| SSH stopped working on a seat | `bin/host/heimdall-ensure.sh status`; the key may be unpinned or GitHub unreachable. |
| The gateway does not answer | It is not raised — raise the set (`scripts/start.sh`). |
