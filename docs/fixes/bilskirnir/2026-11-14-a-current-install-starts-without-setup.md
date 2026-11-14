## bilskirnir · 2026-11-14 — a current install starts without running setup

### Why

Bilskirnir ran her whole `setup.sh` on **every** start, because `setup.sh --check` failed one line and `start.sh`
believes `--check`:

```
bilskirnir: agent's browser is not pinned to her desk — re-run setup.sh
bilskirnir: not ready
```

The check grepped the agent's `config.yaml` for the **quoted** spelling
`cdp_url: "http://<desk>:9299"`. The config is rendered by `house/house.py · parts`, which writes it through
`yaml.safe_dump` — and a plain URL is not quoted there, so the file held `cdp_url: http://127.0.0.1:9299` and the
grep never matched. A perfectly current install read as broken at every launch and re-rendered what was already
right.

Measured cost: the setup step was 3.9 s of a 20.4 s cold boot, every time.

### What changed

| Place | Before | Now |
|---|---|---|
| `apps/bilskirnir/setup.sh` | `grep -q "cdp_url: \"http://$DESK_HOST:9299\""` | `cdp_pinned <config> <host:port>` — reads the **value**, accepting the URL quoted, unquoted, with a trailing slash and with a trailing comment |

Quotes are YAML's business; the pin is the value. The check is a single `grep -E` (no new dependency, no measurable
cost added to a check that runs at every start).

### Proof

On the live install (heimdall, the pin `~/ymir-runtime`, the engine home
`~/Documents/ymirhome/bilskirnir/data/engines/nanna`), with the patched `setup.sh` run **from the pin's own
directory** so every other path is the real one:

```
bilskirnir: desk up (image=present container=running screens=1)
bilskirnir: agent home current (no model chosen yet: )
bilskirnir: agent's browser drives her desk
bilskirnir: ready
exit=0
```

Against the genuine config files, in four spellings plus two negatives:

| config | `cdp_pinned … 127.0.0.1:9299` |
|---|---|
| `cdp_url: http://127.0.0.1:9299` (how `yaml.safe_dump` writes it) | pinned |
| `cdp_url: "http://127.0.0.1:9299"` | pinned |
| `cdp_url: 'http://127.0.0.1:9299/'` | pinned |
| `cdp_url: http://127.0.0.1:9300` (another screen) | not pinned |
| no `browser:` block | not pinned |

And against the three real engine homes: `nanna` pinned (her screen is the hall's), `bot_2eayQCr5VCab` (9300) and
`bot_aCiyAD2OpVrM` (9301) correctly not pinned to 9299 — each bot drives its own screen.

`apps/bilskirnir/start.sh` now prints `setup current` and skips the render: **3.9 s cut from every cold boot**,
and the boot stopwatch's Bilskirnir row measures the rest (gateway, server, window).

## CHANGE LOG

- 2026-11-14 — written with the change; measured on heimdall's live install the same night.
