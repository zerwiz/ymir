# hoard · unversioned · 2026-10-01 — the row names its realm: `workspace:` → `realm:`, and the old key still answers

Plan 62, item 6 — the last piece of the one-word rename. The paths are done (`workspace/` →
`registry/`, `hodd/workspaces/` → `hodd/life/`, `svartalfaheim/<realm>/workspace/` → `…/projects/`,
migration `0007`); this is the **value**.

## Why

A project row's `workspace:` key was never a workspace. It named the **realm** — the same word the
rest of the vocabulary has always used, and the same value `workspaces.yaml` enumerates. Plan 62
sealed the rename `workspace: work` → `realm: work`.

**The risk was never the rename; it was the silence.** A registry written before today must keep
working, and the failure mode of "just renamed the key" is a reader that resolves nothing and says
nothing. So the alias is not politeness — it is the ward, and it is named out loud when used.

## What

- `registry/projects.yaml.example` — the row shape now shows `realm:`; the deprecated key is
  documented in the file. `registry/workspaces.yaml.example` states that every `id:` there is a realm.
- **`bin/registry-lib.sh` (new)** — the ONLY place allowed to resolve the key:
  - `registry_projects_file` — where the master registry is (`PROJECTS_YAML` → the hoard → the repo's
    shape), resolved through `bin/vault/hoard-lib.sh`, never a restated path (Rule 07).
  - `registry_realm` — reads `realm`; falls back to `workspace` and warns, **by name**, once per
    resolution. A row carrying both keys resolves to `realm` and does not warn (it is already correct).
  - `registry_deprecated_rows` — every row still on the old key, as `id<TAB>value`.
  - `registry_deprecated_key_warn` — the one wording of the warning, so the reader and the ward can
    never disagree.
- `bin/project-git.sh` — sources the lib; prints `realm` in its row header and resolves
  `--field realm`. `--field workspace` still resolves and says it is `realm`. **It prints its block**;
  a reader that prints nothing is not a reader.
- `bin/ymir-validate.sh` — a new `registry` check: **PASS** when every project row names its realm,
  **WARN** naming each row still on `workspace:`, and never FAIL (a registry written before the
  rename is not a broken install).
- `bin/ymir-install.sh` — the seeded registry's example row teaches `realm:`.

## The ward, measured

```
$ bin/project-git.sh ymir-platform
deprecated-registry-key: row "ymir-platform" carries `workspace:` in …/hodd/identity/projects.yaml; renamed to `realm:` (plan 62) — the value still resolves, but the row should be renamed.
project[1]{id,host,owner,repo,remote,default_branch,auth,machine,company,realm}:
  "ymir-platform","github.com","zerwiz","ymir","origin","main","gh","omarchy","whynotproductions","work"
```

The operator's live home registry is **untouched** — its rows change by hand, with his word. That is
why the alias exists: until he renames them, every reader works and every reader says so.

## Files

- `bin/registry-lib.sh` (new), `bin/project-git.sh`, `bin/ymir-validate.sh`, `bin/ymir-install.sh`
- `registry/projects.yaml.example`, `registry/workspaces.yaml.example`, `bin/README.md`
- `.agents/tests/registry-realm-key.test.sh` (new) — the ward, runnable by hand
- `.agents/skills/lifecycle/smoke_test.sh` — `rename-realm` (registry-lib.sh is the only reader of the
  key) and `rename-alias` (the old key resolves and names itself)
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` §5b (registries an adapter
  resolves), `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` (registry section — the
  rename is now shipped, not promised), `.agents/skills/galdr-ymirsystem/assets/installation.md`
  (the seeded registry teaches `realm:`) — the gate demands the owning asset of every touched script
- `bin/ymir-install.sh` taught `realm:` in the registry it seeds.

## A mend that is NOT taken here (recorded, not swallowed)

While working, this branch tripped `defaults-guard`'s "uses the home, never resolves it" ward on
`migration 0007` — it read `$YMIR_HOME` alone, with no resolver. The path half of plan 62 has since
landed on `gate/one-word-three-meanings` with that mend already in it (`ymir_home_root`, env last),
so this branch does not carry a second copy: it rebased onto that commit and took its version. The
ward was real and was mended; it was mended upstream, not here.

## Known, and NOT mine

`smoke_test.sh` reports two FAILs on this branch — `cron` (Nornir not running on this seat) and
`hoard` (the layout map still names `hodd/workspaces`, because migration 0007 has not been applied to
the operator's home). Both are reproduced on the untouched plan-62 path base (`bd2aa8b`) and are the
home half of the rename, which changes by hand, with the Allfather's word.

galdr-reread: none beyond the three assets above.