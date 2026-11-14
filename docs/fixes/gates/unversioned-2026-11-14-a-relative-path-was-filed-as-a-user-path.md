# gates · unversioned · 2026-11-14 — a relative path was filed as a user path

The Rule-07 row of `compliance-check.sh` (`config`: no hardcoded models, providers or user paths) was
red on `main` with three findings. Two were the gate's own false positives; the third was a real leak of
exactly the class the gate exists to catch.

## The three findings

| File | Finding | The truth |
|---|---|---|
| `bin/gates/tests/test_opencode_launcher.sh` | `(model)` on `ALLOWED="opencode-go/deepseek-v4.1-flash"` | a **test** naming the model it hands the door. There is nothing else to hand it, and it claims nothing about the author's machine |
| `bin/engine/tests/test_runtime_deploy_stable.sh` | `(path)` on `"$T/home/state"` | **not an absolute path at all** — the pattern never asked where the match started, so it read `T/home/state` as `/home/<user>/` |
| `bin/time/nornir-job-private-scan.sh` | `(path)` on `ADDRESS\t/home/<machine>/` | **a real leak**: the sweep's own rule baked a machine's home into the public tree — the very thing it sweeps for |

## What changed

- **The path class requires the path to begin a token.** A real absolute path follows a space, a quote,
  `=`, `(` or a line start; a path inside a variable does not. `"$T/home/state"` is no longer a finding.
- **The model class judges shipped surfaces only.** Files under a `tests/` directory are skipped. The
  path class still judges tests — a machine's own home path in a test is the same leak as anywhere.
- **The sweep reads the fleet's homes from the home.** `hodd/identity/machine-homes.txt` (private, shipped
  to `ymirhome` with this mend) holds one path per line, exactly as `nda-names.txt` holds the client
  names. Absent, the rule is skipped **and said**, because a silently missing rule is a false clean.

- **The sweep resolves its home instead of restating it.** The same file carried
  `HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"` — a second place that knew where the hoard lives, which
  `defaults-guard` refused the moment the file entered a push. It now resolves through
  `bin/vault/hoard-lib.sh` and, with no home recorded, refuses with rc 2 and names the door, rather than
  guessing a path that might belong to another operator.

## Proof

```text
$ bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh | grep config
  "config","no hardcoded models, providers, or user paths (Rule 07)","PASS","1010 files clean; …"
```

The sweep still bites — measured in a scratch home and a scratch repo:

```text
$ ls hodd/identity/machine-homes.txt && echo "the tree lives at /home/<machine>/ymir" > repo/leak.md
ADDRESS	leak.md:1:the tree lives at /home/<machine>/ymir and nowhere else
$ rm hodd/identity/machine-homes.txt
private-scan: note — no …/machine-homes.txt, so no machine home paths are checked this run
```

## Files

- `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`
- `bin/time/nornir-job-private-scan.sh`
- `hodd/identity/machine-homes.txt` (in `$YMIR_HOME`, not this repo)

## CHANGE LOG

- 2026-11-14 — written with the mend. The third finding is the same class the 04:04 private-scan errand
  fixed in a unit template and a hound config; the sweep itself had been missed.
