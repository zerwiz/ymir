## guard · 2026-11-10 — hoard-guard's `sk-` shape is anchored to a non-letter

### What
`bin/gates/guards/hoard-guard.sh` `SECRET_SHAPES`: `sk-[A-Za-z0-9]{20,}` → `(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{20,}`.

### Why
It blocked a merge of the home on a well episode that quotes a Swedish heading: an adjective ending in
`-isk` joined by a hyphen to a long compound noun, so the letters `sk-` plus twenty more matched. The episode itself recorded the same false
positive in another scanner. The merge was committed with the guard's sanctioned `--no-verify` + `--log-bypass`.

### Verified
That heading no longer matches; `key=sk-<26 chars>` and a bare `sk-<26 chars>` at line start still do.
`secret-guard.sh` and `public-guard.sh` carry the same unanchored shape and are left as they were (not in this change).
