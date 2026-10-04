## harness-integration · unversioned · 2026-10-04 — the extension paths stop contradicting themselves

### Why

The Allfather opened with *"why are these extensions in lib?"* — a question the
documentation should have answered in one look and could not, because it answered
it two ways.

`harness-integration/README.md` carried **two incompatible models of the same
tree**. One (the 2026-09-12 table) said:

> `.pi/extensions/` — pi, as project-local extensions — **the governance set:
> `syn-turnend-guard.ts`, `gna-pi-watch.ts`, `ro.ts`, `skuld-branch-supervision.ts`**

The other (a later section) said:

> **One home.** It lives in `.pi/shared/extensions/` (deployed), **never in
> `.pi/extensions/`** — a copy in both makes pi refuse the duplicate tool.

**Both cannot be true, and neither described reality.** All twenty extensions live
in `.pi/shared/extensions/` and are deployed to `~/.pi/agent/extensions/`.
`.pi/extensions/` holds **nine no-op factories that register nothing** plus the
`lib/` helper tree. A grep for "where does an extension live" returned two answers
and neither was right.

`.pi/extensions/README.md` made it worse: it tabulated `lib/ro-*.ts` and
`lib/skuld-branch-*.ts` beside `ro.ts` and `skuld-branch-supervision.ts`, as peers —
which is exactly the impression that sent the question.

### Fix

- **The table now states what is actually there**, with the loader rule quoted from
  the installed source — *"No recursion beyond one level"*, a subdirectory loads
  only with an `index.ts` — because that is the whole reason `lib/` exists and is
  never scanned.
- **Every stale path reference corrected** from `.pi/extensions/<ext>.ts` to
  `.pi/shared/extensions/<ext>.ts`, in the port table, the wiring notes and the
  `BROKK_SESSION_PID` line numbers.
- **Both contradictions corrected in place and dated**, not silently overwritten,
  with the previous wording kept so a reader who remembers it can see what changed.
- **`.pi/extensions/README.md` now opens by saying this tree is not the extension
  home**, what the nine stubs are for, and why `lib/` is a leftover from plan 29.
- **The `.ymir-root` bullet now records the validation that already exists** — every
  recorded root is checked against `bin/syn-watch-arm.sh` and one that is gone is
  skipped. Dead worktrees in that file are hygiene, not a silent resolution failure.

### Verified

```
$ python3 — every documented path checked, 0 dead      (15 paths)
$ bash bin/valknut-load.sh --check
  valknut-load --check                           PASS
```

### Not done here

The layout itself is unchanged: `lib/` is still sourced from the old flat tree.
That is a separate change on `.pi/shared/extensions/` — one directory per
multi-file extension with an `index.ts`, per pi's documented shape. Full analysis,
including why plan 58's "thin loaders" can never be built:
`~/Documents/ymirhome/hodd/docs/developer-setup/2026-10-01-pi-extension-system-layout.md`.
