# Main was red: a stale catalogue and two guessed homes

**Date:** 2026-11-09 · **Component:** gate · **Doors:** `FEATURES.md` (woven) · `bin/records/meetings.sh` · `bin/collab/kit/scripts/notify-arm.sh`

## What was wrong

After the night's merges, `origin/main` was red on two wards, and every pull request was being
held by them — the gate judges a branch against main and refuses to blame the branch for main's
fault, but `ci-verify` still exits non-zero, so nothing could land.

```
features-guard[3]{finding,page,catalogue}:
  "the woven catalogue is stale","FEATURES.md","run bin/records/weave-features.sh …"
defaults-guard[3]{finding,file,line,text}:
  "a home guessed","bin/records/meetings.sh","26","HOARD=\"${_home:-${YMIR_HOME:-$HOME/Documents/ymirhome}}/hodd\""
defaults-guard[2]{finding,file,why}:
  "uses the home, never resolves it","bin/collab/kit/scripts/notify-arm.sh","…"
```

- The catalogue was one row behind: the Snotra meetings row landed without a re-weave, so
  `FEATURES.md` no longer matched its fragments.
- `meetings.sh` carried a literal fallback naming one machine's home; on any seat where the hoard
  is not in that exact place it read an empty shelf and reported "no meetings" — a wrong answer,
  not an error.
- `notify-arm.sh` read `$YMIR_HOME` without ever asking the resolver.

## What was forged

- `bin/records/weave-features.sh` run (Rule 14 · Þættir: the catalogue is woven, never hand-edited).
- `meetings.sh` resolves through `bin/vault/hoard-lib.sh` and **refuses** (`exit 2`, with the
  remedy) when the resolver cannot answer.
- `notify-arm.sh` asks the same door when it is reachable from the kit's own tree; inside a guest
  repository, where no Ymir exists, it carries no home rather than inventing one.

## Verified

```
$ bin/gates/guards/defaults-guard.sh check   # "none" — every path resolves through the one resolver
$ bin/gates/guards/features-guard.sh         # "none" — every page catalogued, the catalogue current
$ bash -n bin/records/meetings.sh bin/collab/kit/scripts/notify-arm.sh
```
