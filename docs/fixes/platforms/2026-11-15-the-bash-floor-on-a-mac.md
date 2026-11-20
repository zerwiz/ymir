# The bash floor on a Mac: a script that needs bash 4 finds one, or says how to get one

**Date:** 2026-11-15 · **Component:** platforms / install · **Found while:** installing Ymir on a stock Mac
(MacBook Pro, Apple silicon, macOS 14.6, `/bin/bash` 3.2.57) from the home pack

## What went wrong

macOS ships bash 3.2.57, the last GPLv2 release, and never a newer one. Several scripts use bash 4 features
(`declare -A`, `local -n`, `mapfile`), so on a stock Mac they stopped partway through with errors that do not name
the cause:

| Script | What it printed on bash 3.2 |
|---|---|
| `bin/agents/eir-doctor.sh check` | `line 161: declare: -A: invalid option`, then `line 98: floors: unbound variable` |
| `bin/engine/ymir-migrate.sh status` | `line 54: mapfile: command not found`, then `error: unknown action status` |
| `bin/agents/groa-update.sh` | `SEATING FAILED — the tree moved but the seat did not` (its doctor step died the same way) |

The installer itself runs on 3.2, so an install looked healthy until the first doctor run or update.

## What changed

| Path | Change |
|---|---|
| `bin/fleet/ymir-platform.sh` | two new verbs. `ymir_bash4_path` prints a bash >= 4 on this host (`$YMIR_BASH`, Homebrew on Apple silicon and Intel, MacPorts, `~/.local/bin`, then `PATH`). `ymir_bash_floor "$@"` returns at once on bash >= 4; on an older bash it re-runs the calling script under that bash, and when there is none it prints the reason and `brew install bash`, then exits 2. `YMIR_BASH_FLOOR_REEXEC` stops a loop |
| the 23 scripts that use bash 4 features | one guard line after `set -…`: on bash < 4, source the shim and call `ymir_bash_floor "$@"`. On bash >= 4 the line is a single test and costs nothing |
| `bin/engine/ymir-install.sh` | the prerequisites step adds a `bash` row: `OK bash >= 4 at <path>`, or `WARN` with `brew install bash` on macOS |
| `bin/bridge/ymir-plan.sh` | the plan adds `runtimes bash`: `SKIP` with the path, or `BLOCKED` with the remedy |
| `docs/features/install-ymir.md`, the installation asset | the Mac note and the shim table row |

The guarded scripts are: `bin/agents/{domain,eir-doctor}.sh`, `bin/engine/ymir-migrate.sh`,
`bin/fleet/tailscale-sync.sh`, `bin/forge/{gather,queue-warden,ship-watch}.sh`,
`bin/gates/checks/{home-contract-check,portability-ratchet}.sh`, `bin/gates/{doc-sweep,guards}.sh`,
`bin/gates/guards/{app-functional,dead-code,rules-number,skills-share}-guard.sh`,
`bin/host/{heimdall-ssh-keys,omarchy-plugins}.sh`, `bin/records/{mimir-ingest,plan}.sh`,
`bin/seat/{armpin,seat-reap}.sh`, `bin/skills/manifest.sh` and `systems/snotra/services/ear/snotra-live.sh`.

## How it was proved

All runs below were on the Mac above, with bash 5.2.37 built into `~/.local/bin`.

| Run | Result |
|---|---|
| `/bin/bash bin/engine/ymir-migrate.sh status` with a bash >= 4 present | re-runs under it and prints the 25 migrations |
| the same with `HOME=/nonexistent PATH=/usr/bin:/bin` (no bash >= 4) | `error: ymir-migrate.sh needs bash 4 or newer; this is bash 3.2.57(1)-release`, then the fix line; exit 2 |
| `bash5 bin/engine/ymir-migrate.sh status` | unchanged output; the guard does nothing |
| `/bin/bash bin/bridge/ymir-plan.sh` | `runtimes bash SKIP bash >= 4 at …/.local/bin/bash`; with no bash >= 4, `BLOCKED … brew install bash` |
| `bash -n` on every changed script, under 3.2 and 5.2 | clean |

## What this does not fix

This is the first step of making Ymir native on a Mac (Dana's plan 293, "One core, three systems"). It does not
replace bash, and it does not touch the GNU-only tools still called directly. Measured on this tree with a pattern
scan, as an upper bound because many call sites already fall back:

| Construct | Files |
|---|---|
| `stat -c` | 93 |
| `sha256sum` / `md5sum` | 104 |
| `systemctl` / `journalctl` / `loginctl` | 59 |
| `timeout` | 59 |
| `/proc/` | 48 |
| `readlink -f` | 32 |
| `date -d` | 26 |
| `ss` / `ip` | 22 |
| `sed -i` with no suffix | 16 |
| `flock` | 15 |
| `cryptsetup` / `bwrap` | 10 |

The local-model step still builds llama.cpp for CUDA, and the Utgard sandbox still needs Docker or Podman. Both are
plan 293's.

## A second Mac fault: a message spoken aloud

While the install ran, the Mac spoke a sentence about "rules" and "the runtime". The cause was in
`bin/fleet/fleet-ensure.sh`: line 89 called `say "fleet:   units pinned to the runtime checkout … (RULES/02 §7)"`,
but the script defines its own `say() { printf …; }` only at line 147. On Linux an undefined `say` fails quietly
(the call carried `2>/dev/null || true`). On macOS `say` is `/usr/bin/say`, so the line was read aloud through the
speakers.

The proof is macOS's own log. `/usr/bin/say` ran at 15:45:22, during the installer's `fleet` step, and at 15:49:51,
when `fleet-ensure.sh ensure` was run by hand. No other process called it.

| Path | Change |
|---|---|
| `bin/fleet/fleet-ensure.sh` | `say()` is now defined right after `set -u`, and the early call is a plain `printf` |

A scan of every tracked `*.sh` for a `say` call with no definition before it found no other live case. Two scripts
matched only in help text or with an inline definition. A ward for this belongs to plan 293: any helper named like a
macOS command (`say`, `open`, `pbcopy`) is a hazard when it is called before it is defined.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #778

- **2026-11-20** — redacted: a machine, a user or a person named above now reads as a role or an invented example (RULES/04 · plan 287 §3). No fact of the fix changed; the original text stands in the repository's history.
