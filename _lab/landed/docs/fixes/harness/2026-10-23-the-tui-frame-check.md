## harness · 2026-10-23 — the TUI frame is checked, and the cause it sits under is named

**His words:** *"why are the ui in pi breaking like this"* — then, after two screenshots and a list of
workarounds, *"this needs to be production ready and never happends. 1 wthgf are that for soulution"*. He
was right to refuse the workarounds: a resize and a `ctrl+o` are not a fix.

**The cause was already found, in this tree, tonight** — `docs/fixes/harness/2026-10-23-the-tool-that-
painted-on-the-terminal.md` (PR #412, merged 20:59 local): a tool that hands a child its **stdio**
(`stdio: "inherit"` in `eindri.ts`) lets that child draw wherever its own cursor is — over the prompt,
over the status line, over the spinner — and pi never sees those bytes, so nothing in its renderer can
repair the damage. That is the "random texts over the UI" and the fused lines exactly. #412 also carried
pi 1.3.0 → 1.4.0, whose notes fix terminal modes left on when pi exits without teardown.

**And the reason it kept happening while it was fixed:** a running `pi` keeps the code it loaded. At
21:05 the seats held `pi` processes started at **16:30** and **19:51** — every one of them older than the
20:59 merge, so every one of them still painted. The mend reaches a screen at that session's **next
start**, never before.

```
measured[3]{fact,evidence}:
  "fullscreen sends `ESC[?7l` (autowrap OFF) at startup and never restores it","`PI_TUI_WRITE_LOG` in a 66x18 pty — one autowrap event, `False`, row 1"
  "under autowrap-off a one-column overrun is CLIPPED, not wrapped","the same capture: rows reaching exactly column 66, no wrap; the clipped `MCP: 12 servers enab` in his screenshot is a clip"
  "and a stray writer then shifts what is already on the row","his artefact: a `Working` rule inside a transcript line, a `(` and a caret on the right edge, one transcript row eaten — which is what inherited stdio does, not what pi's own frame does"
```

**What this change adds — the instrument, so it is never again discovered by the operator.**
`bin/pi/tui-frame-check.sh` starts a real `pi` in a throw-away pty of a chosen size (`--cols`, `--rows`,
`--mode`), captures the raw ANSI stream through `PI_TUI_WRITE_LOG`, replays it (CUP/ED/EL-aware,
OSC-aware, grapheme-aware) and **fails if any write reaches past the right edge**, naming the row, the
column and the bytes; it also reports the autowrap state, because `?7l` left on is what turns one bad
column into a torn screen.

```
run[2]{command,result}:
  "bin/pi/tui-frame-check.sh --cols 60 --rows 18","regular: 5 rows, none past 60, autowrap untouched · fullscreen: 5 rows, none past 60, AUTOWRAP DISABLED · pass, exit 0"
  "bin/pi/tui-frame-check.sh --cols 40 --rows 14","the smallest window in use — the check is meant to be run at that width, not at 120"
```

**What I did NOT change, and why:** I first set `"tuiMode": "regular"` on this seat, then un-set it when
the cause turned out to be #412's and not the mode's. His UI is his; the mode is not a fix and should not
be spent as one. The backup remains at `~/.pi/agent/settings.json.bak-20261023-tuimode`, and
`pi --tui-mode regular` is there if a session ever needs it.

**Still owed, and it is named:** (1) the check is a door, not a cron row — wiring it into `housewatch`
behind a `--frames` flag means a pty probe every quarter hour, which is the next small piece; (2) the fix
reaches a screen only at that session's next start, so the standing rule is *merge a harness fix → tell
the operator which sessions must be restarted*, and that rule belongs in the harness asset.

**The rule this earns:** *a mend to the interface is not delivered until the session that shows it has
started again — and what the interface writes must be measured at a narrow width, with a real pty, before
it is believed.*

## Appended 2026-10-23 21:15 — the dead branch where a painting path hides

Reading #412's own fix in `eindri.ts` showed the mend was half a mend:

```ts
const out = execFileSync(cmd, args, { encoding: "utf8",
  stdio: quiet ? ["ignore", "pipe", "ignore"] : "inherit" });   // quiet = true by default
```

No caller ever passes `quiet`, so the `"inherit"` branch was **unreachable — and still a painting path**:
one future call `run(cmd, args, false)` and the terminal is the child's again. Dead code is exactly where
such a path hides, so the branch is gone rather than defaulted: `run(cmd, args)` always captures
(`stdio: ["ignore", "pipe", "ignore"]`), and the comment says why in one sentence. This is Rule 17's case
made concrete — the guard is the absence of the branch, not a default in front of it.

Verified: `bun build .pi/extensions/eindri.ts` bundles clean; the only inherited stdio left in the harness
is `open-editor.ts`, which stops the TUI before handing over the terminal.
