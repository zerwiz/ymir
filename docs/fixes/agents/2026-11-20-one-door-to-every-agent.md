# 2026-11-20 — one door to every agent: tell.sh, and Hermes reached through its gateway

**Component:** agents · **Plan:** 340, phases 340.1–340.4 · **Files:** `bin/agents/tell.sh` (new),
`bin/agents/hermes-tell.sh` (new), `bin/agents/window-tell.sh`, `bin/agents/tests/test_tell_doors.sh` (new),
`docs/features/tell-any-agent.md` (new), one catalogue entry.

## Why

The house had five places an agent can live and a different road, or none, to each. Hermes's gateway answered when
asked by hand, but nothing in Ymir knew how to ask it. Neither the Hermes CLI in a terminal nor the desktop's own
conversation could be reached at all. The operator's word: *"we need to have terminal etc communication to other
agents. also into hermes."*

## What changed

- **`window-tell.sh` finds agents that run under an interpreter.** The Hermes CLI was the case in point. Process names
  come from `WINDOW_TELL_AGENTS`, which now includes `hermes`. An interpreter (`WINDOW_TELL_INTERPRETERS`) counts as an
  agent when its command line matches `WINDOW_TELL_CMDLINE`. The door now refuses to type while
  `bin/desk/in-call.sh holder` names a call.
- **`hermes-tell.sh` speaks to the Hermes gateway's OpenAI-compatible API.** It reads the listener from Hermes's own
  `gateway_state.json`, or from `API_SERVER_HOST`/`API_SERVER_PORT` in Hermes's `.env`. It reads the key
  (`API_SERVER_KEY`) from that same `.env` at call time. The key is never copied, logged or printed.
  - `--new` starts a fresh, named session and prints its id.
  - `--session <id|prefix|title>` continues a session through `X-Hermes-Session-Id`.
  - `--desktop` lands in the conversation the desktop drives. A live turn lease held by `platform=desktop` names it.
    Without one, it is the desktop-made session that spoke last.
  - The door refuses a session that is mid-turn or has subagents running, unless `--force`. The API has no per-session
    lock, so a second turn would race the first.
  - It refuses to send the key to a listener that is not on loopback.
- **`tell.sh` resolves a name to a road.** The names are `arm`, `hermes`, `hermes:desktop`, `hermes:<session>`,
  `herdr:<pane|name>`, a pane id, an errand id (the pane's name), `window:<pid|word>`, or a bare word. `--list` prints
  every reachable agent with its road. `<machine>:<who>` is refused by name until 340.5.

## Found on the way

- **Closing the desktop window marks its conversation ended, but the conversation keeps running.** The reason recorded
  is `ws_orphan_reap`. The gateway went on running turns and subagents in that session. A first query that skipped
  ended sessions lost the desktop's conversation, so the session lookup no longer filters on `ended_at`.
- **The Hermes CLI's process is named `hermes`, not `python3`.** Hermes sets its own process title, so the name list
  catches it. The command-line match covers runtimes that do not set a title.

## Proof (the dev machine)

- `test_tell_doors.sh` passes 22 of 22. It runs against a fake Hermes home and a fake gateway: stamp, session header,
  the key absent from all output, busy and loopback refusals, and road resolution.
- **Hermes over the gateway:** a fresh tell was answered with its own name and *"noted, the word is ember"* Two more tells to
  that session, one through `--session` and one through `tell.sh hermes:tell-20261120`, each answered *"ember"*.
- **Hermes CLI in a terminal:** `hermes chat` was started in a test foot window. `--list` found it as agent `hermes`,
  and a real tell was typed. The screen showed the stamped line and Hermes's answer *"granite"*. The window was then
  closed.
- **The herdr road:** `tell.sh agent-tell "…"` came back into the sender's own pane, stamped with the sender.
- `--desktop` resolved the operator's open desktop conversation and **refused** it, because two subagents were running
  under it.

## Owed

- **340.3's on-screen proof is not done.** The Hermes desktop window was closed throughout, and its conversation had
  live subagents. Opening or closing the desktop mid-work pauses those subagents, so it was not done. When the desktop
  is open and idle, run this and watch the line appear in the window:
  `bin/agents/tell.sh hermes:desktop "test line"`.
- **The desktop window's class is unverified.** `--where` assumes the class matches `^hermes`; it was not measured
  while the window was open. `HERMES_DESKTOP_CLASS` overrides it.
- **Not yet tested on a second machine from a release.**
- **The keystroke path will move.** When the hypr door (plan 341.1) lands, `window-tell.sh`'s typing moves to
  `hypr.sh type`, so the house has one guarded keystroke path.
