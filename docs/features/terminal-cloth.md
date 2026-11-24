# The terminal cloth — one look for every command Ymir runs

Every script you run wears the same cloth as the halls and the homepage: stone, bone, bronze and blood, with
runes. While something downloads, clones, installs or builds, you see a rune turning in bronze and the time it
has taken. When it ends you see **one line**: a steel ✓ with the time, or a blood ✕ with the last lines of what
went wrong and where the full log lives.

## What you need

Nothing. It is part of Ymir. It uses only `bash`, `printf` and `sleep`, and `curl` for a download bar.

## What you see

| Moment | On a terminal | In a pipe, in CI, or with `NO_COLOR` |
|---|---|---|
| A step is running | a bronze rune turns, with elapsed time | nothing until it ends |
| A step passes | `✓ installing the release's dependencies  4m12s` | the same line, no colour |
| A step fails | `✕ …  (exit 1)`, the last 15 log lines, `log: <path>` | the same, no colour |
| A counted job | `[3/7] odrerir` before the name | the same |
| A download of known size | a bar with bytes and percent | one line at the end |

The noisy output of a step is kept in `~/.local/state/ymir/log/` (`YMIR_LOG_DIR` to move it). A step that
passes deletes its log; a step that fails keeps it. `YMIR_STEP_KEEP=1` keeps every log.

## Which commands wear it

`install.sh` (the curl one-liner, with a small inline copy), `ymir install`, `ymir groa`, `ymir smidja build`,
`ymir migrate`, `ymir sense`, `ymir config`, `ymir mimir`, `ymir lower`, the desktop windows' first run, the
`apps.sh install | update | rollback` door, the release build (`release.sh build`, `release-build.sh`) and the
npm postinstall (`fleet-deploy.sh`).

## For a script author

```bash
. bin/desktop/ymir-style.sh; style_init
style_steps 3                                   # the next three steps read [1/3] … [3/3]
style_step "cloning the app" -- git clone -q "$url" "$dir"
style_step --data "listing" -- python3 tool.py  # its stdout is replayed on stdout, unchanged
style_download "fetching the archive" "$url" "$dest"
```

A step returns the command's own exit code, always. The command runs in a subshell: a shell function works, but
variables it sets do not survive. Decoration goes to stderr; data stays on stdout.

## Limits

- `style_download` shows a byte bar only when the server states a `Content-Length`; otherwise it shows the rune.
- A multi-stage build (clone, install, compile) is one step; its stages are in the log, not on the line.
- `CI`, `NO_COLOR`, `YMIR_NO_COLOR=1`, a dumb `TERM` or a non-terminal stderr all switch the cloth to plain lines.

## If it does not work

If you see raw escape codes in a log, set `NO_COLOR=1`. If a step ends ✕, open the `log:` path it printed — the
whole command output is there. The tests are `.agents/tests/style-progress.test.sh`.

## CHANGE LOG

- **2026-11-24** — written with the change it describes (the terminal cloth gets progress).
