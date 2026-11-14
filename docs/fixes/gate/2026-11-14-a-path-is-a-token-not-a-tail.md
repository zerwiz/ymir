## gate · 2026-11-14 — a ward's finding names a path, not a tail of one

### Why

Two pull requests were refused a push for a fault neither had. Measured on #747 (`fix/queue-warden-never-merges-red`)
and #754 (a gathered batch): `runtime-pinned-guard` answers

```
"a unit runs a working tree","queue-warden.service → /home/<seat>/ymir/.yggdrasil/queue-warden-review/bin/forge/queue-warden.sh (working tree)"
```

That unit points into an **errand worktree**, not into this checkout. But `inherited()` decided "is this finding
ours?" by asking whether the ward's output *contained* a changed path — and `bin/forge/queue-warden.sh` is a
substring of `.yggdrasil/queue-warden-review/bin/forge/queue-warden.sh`. So every branch that touches that script was
refused, and the true owner of the finding (the machine's units) was never named.

### The fix

`inherited()` now decides on whole tokens:

- **ours, absolute** — the finding names `$ROOT/<path>`, this checkout's own copy;
- **ours, relative** — the path stands as a token of its own, once the punctuation a ward wraps it in is stripped
  (a TOON row is `"a home guessed","bin/x.sh","42","…"`, and its cells are comma-separated with no spaces, so the
  tokeniser splits on whitespace *and* commas);
- **never ours** — a path buried inside a longer path.

### Proof

`bin/gates/tests/test_guards_inherited.sh`, wired as the gate `guards-inherited` in `bin/gates/ci-verify.sh` — five
cases, both directions:

| case | verdict |
|---|---|
| a neighbour checkout's copy (`…/.yggdrasil/queue-warden-review/bin/forge/queue-warden.sh`) | INHERITED |
| this checkout's own absolute copy (`$ROOT/bin/forge/queue-warden.sh`) | OURS |
| a relative path standing alone (`"bin/forge/queue-warden.sh"`) | OURS |
| a relative path buried inside a longer path | INHERITED |
| an unrelated finding | INHERITED |

`5 ok, 0 failed` on this machine. The ward is unchanged in what it *finds*; only the ownership decision moved.

### Appended the same day — the body that proved it was refused for naming a path

The first push's CI failed on `pr-identity-guard`, not on this change: the pull-request body quoted the finding with a
real absolute home path, and the ward reads `/home/<x>/…` as a leaked address. Reworded to
`<this checkout>/.yggdrasil/queue-warden-review/…`, and the ward answers `pr-identity-guard: OK`.

Worth keeping: an example is still text, and a body that quotes a machine path is judged exactly like a commit that
carries one — the rule is about facts, not about intent.
