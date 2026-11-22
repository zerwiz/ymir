# 2026-11-22 — the arm never dies of one bad cycle

The operator: *"this must always work — the arm is the key to Ymir's whole system."*

Measured on the dev desk: `ymir-syn-watch.service` restarted every two seconds for hours; each life wrote a lease and died, so the lease always named a dead pid, the helm read as vacant, wakes were refused (*"no arm is held"*) and dispatch refused (*"no helm, no errand"*). The cause: one child of the cycle (the handoff sweep) printed a cut multi-byte character, `subprocess.run(text=True)` raised `UnicodeDecodeError`, and nothing caught it.

Two fixes, either alone enough:
- `src/ymir_runtime/proc.py`: every captured child is decoded as UTF-8 with `errors="replace"`, so a broken byte is a replacement mark, never a crash.
- `src/ymir_runtime/watch.py`: the arm's loop survives any exception in one cycle, says so on stderr (`arm cycle failed and was survived: …`) and keeps watching.

Proved: the fixed arm, run against the same home that crashed it, stayed up for its whole 30 s window and raised the waiting wakes.

## CHANGE LOG

- 2026-11-22 — review-mend: added missing heading for #902
