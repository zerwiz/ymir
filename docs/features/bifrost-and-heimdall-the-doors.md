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
`local-rail` (the local llama.cpp rail on `:8080`), `lmstudio` (only when it is **named**),
or `openai-compatible`. With nothing named the bridge decides by what is actually here:
`opencode-go` when a key is readable — through the env file, the vault
(`bin/vault/hodd.sh emit secrets/platform.env`) or pi's `auth.json` — and otherwise the local
rail. `lmstudio` is never chosen for you: it was the old fallback, and a door the operator
retired answered every chat with a bare 500. Ask what it would serve, and why:

```bash
bin/bridge/bifrost-bridge.sh --resolve      # which provider, why, and where the key is
bin/bridge/bifrost-bridge.sh --status       # up/down, and the provider actually serving
```

The model list comes from `bin/model/catalog.sh`, so the models the house really uses
(`deepseek-v4.1-flash`, …) appear in `/v1/models` even when the gateway cannot be reached.

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
- **The ingress is opt‑in, and it never points at a hall.** The halls (Hlidskjalf `:3888` and its
  gate `:3889`, Óðrerir `:4322`, Smíðja `:8437`, Bilskirnir `:8787`, Mímir `:4602`, Bifrost `:4603`)
  are local only: `bin/forge/gjallarhorn-tunnel.sh start` **refuses** a config that dials one, and
  `… check` audits a config without raising anything. A tunnel publishes a frontier surface instead —
  the video forge, the hound's notifications — and a hosted, shared surface is Gimlé's (plan 284).

## If it does not work

| What you see | What to do |
|---|---|
| A session 401s / the model never answers | `bin/bridge/bifrost-bridge.sh` — the bridge is down. |
| SSH stopped working on a seat | `bin/host/heimdall-ensure.sh status`; the key may be unpinned or GitHub unreachable. |
| The gateway does not answer | It is not raised — raise the set (`scripts/start.sh`). |

## CHANGE LOG

- **2026-11-14** — the provider fallback and the tunnel rule corrected (plan 275 items 22 and 30): `lmstudio` is
  served only when it is named, the key is read through the vault, and a tunnel may not point at a hall.
- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
