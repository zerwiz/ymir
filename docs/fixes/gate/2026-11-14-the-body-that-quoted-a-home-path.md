## gate · 2026-11-14 — the body that proved the guard was refused for quoting a path

The first CI run on this branch failed on `pr-identity-guard`, not on the change: the pull-request body quoted the
ward's finding with a real absolute home path, and the ward reads such a path as a leaked address. The body now
writes `<this checkout>/.yggdrasil/queue-warden-review/…`, and the ward answers `pr-identity-guard: OK`.

**Why this is worth a note.** An example is still text. A document that quotes a machine path is judged exactly like
a commit that carries one, and the finding is about the fact, not the intent behind it. The same trap catches a fix
note that reproduces a ward's output verbatim — so a note quotes the shape, never the address.

Measured on PR #766: `whole-tree` FAILURE at the `PR identity ward` step, one line, `refused: homepath`.
