# The bridge never falls back to a retired door, and a reply now ends

**Date:** 2026-11-14 · **Component:** bridge (`bin/bridge/bifrost-bridge.sh`, `.agents/backend/model-bridge.py`) · **Plan:** 275 item 22

## What was wrong

Two faults in the same door, one of which only showed when the first was fixed.

**1. The provider fallback was a retired one.** `bifrost-bridge.sh` chose its provider in this order: a named
`YMIR_MODEL_PROVIDER`, then `opencode-go` if `OPENCODE_GO_API_KEY` sat in `$YMIR_HOME/.env.local`, and otherwise
`lmstudio`. The key does not live in that file — it lives in the vault (`bin/vault/hodd.sh emit
secrets/platform.env`) and in pi's `auth.json` — so the answer was always `lmstudio`, a door the Allfather retired
on 2026-10-24 (*"no lm studio we not using that"*). At 03:16:41 and 03:16:47 the bridge logged
`provider=lmstudio … proxy error: curl: (7) Failed to connect to 127.0.0.1:1234`, and OmniChat answered every
message with `The well is local; no model backend answered (http://127.0.0.1:4603/v1 → 500)`.

**2. A non-stream reply had no end.** `_CurlResponse.read()` returned the whole body on every call, so the proxy's
`while chunk := resp.read(4096)` loop never terminated: it re-wrote the same 640-byte JSON until the client gave up.
Measured on :4604 — one completion produced a **13 GB** download of repeated JSON. A chat client that waits for the
end of the reply never got one, which is a second way to see "no answer".

## The fix

- **The fallback order is: named → keyed → local rail → a refusal.** `model-bridge.py` gains
  `--resolve-provider`, which prints the provider and *why*, and `choose_provider()` is the one owner of that
  question. A key is read through four doors in order — the env file, the process environment, the vault, pi's
  `auth.json` — and the door it came from is reported. `lmstudio` is served **only when it is named**. With no key
  and no rail the door refuses and names both roads.
- **The key never leaves the process.** It is not printed, not written into any env file, not passed in argv (argv is
  readable through `/proc`). Only its NAME is reported.
- **`local-rail` is a real provider** (`YMIR_RAIL_BASE_URL`, default `http://127.0.0.1:8080/v1`), so a seat with no
  hosted key still has a road. Its key comes from `LLAMA_SWAP_API_KEY` or pi's `llama-swap` credential.
- **`/v1/models` reads the catalogue.** The hand-written table (which listed `deepseek-v4-flash` and not v4.1) is now
  only a last resort; the list comes from `bin/model/catalog.sh` filtered to the provider, so the models the house
  actually uses appear.
- **Every reply is delimited.** A non-stream body is buffered (it already was) and sent once with its true
  `Content-Length`; a stream keeps chunked framing and a terminating zero-chunk. `read(n)` consumes, as a stream's
  `read` must.

## Verified

- `bin/bridge/tests/test_bifrost_provider.sh` — 10 checks: a named provider wins (even lmstudio); no key and no rail
  is a refusal naming both roads; the vault door and pi's `auth.json` both serve `opencode-go`; a live rail serves
  `local-rail`; the catalogue's v4.1 appears; a non-stream reply is byte-identical to the upstream body, once, with
  its own `Content-Length`; and the key appears in no output the door prints.
- Live on heimdall from a worktree copy on :4604, using the REAL vault key: `--resolve` answered
  `opencode-go … a key is readable (OPENCODE_GO_API_KEY in the vault)`; `/v1/models` returned 30 models with
  `deepseek-v4.1-flash` first; one completion returned `http=200 bytes=698 time=2.17s`, valid JSON, content
  `the bridge answers`.
- Wired into `bin/gates/ci-verify.sh` as `bifrost-provider`.

## Not done here

`bifrost.service` on this seat still runs the PIN's copy of the bridge; it serves `lmstudio` until the pin flips.
No service was restarted for this half — a restart now would only re-raise the retired door.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #757
