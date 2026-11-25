# gates · 2026-11-25 — one gate pack for every app repository

## What was wrong

The app repositories that left Ymir's tree were guarded by a light `privacy-guard.yml`: gitleaks through a
marketplace action, and a grep of the tree for the operator's private words. The two newest repositories carried
Ymir's full wards instead, copied by hand. So the answer to "are the gates the same everywhere?" was no.

The light guard also read its word list from an Actions secret. That puts the deny list on the hosting service, and
the house law keeps it in the home.

## What changed

- **`bin/gates/pack/` is the pack's one source.** `files.txt` names Ymir's 17 ward files; `tree/` holds the pack's
  own files laid out as they sit in an app: the one door `bin/gates/run-gates.sh`, the hooks, the CI workflow,
  `vendor-sync.sh`, the planted-fault test and the root mark.
- **`bin/gates/pack.sh`** seats the pack from a committed Ymir revision (`seat`), judges one clone (`check`) and
  reads every app repository on GitHub (`status`). It refuses to take a file a repository wrote for itself, and it
  never overwrites a repository's own `.gitleaks.toml`.
- **CI is never given the deny list.** The pack's door judges shapes when no home is readable and says so in one
  line. The hooks on a seat read the list from the home, where a machine named as a host is binding.
- **The private-path ward judges what a change adds.** It is a surface ward, and an app that left with its history
  names Ymir's public layout in older lines. Commits and pull requests are judged on added lines (binding), and the
  whole-tree run lists inherited lines (advisory). A planted-fault case proves an inherited line does not block an
  unrelated change.
- **`vendor-sync.sh --behind main`** fails an app's CI when Ymir's `main` has moved past its copies.
- **Eir's `gatepack` row** (risk `never`, roles heart and dev) shows each repository as current, behind or absent.

## Proof

```bash
bash bin/gates/tests/test_gate_pack.sh       # 7 passed: seat, the seated test, sync, current, behind, refusal, gitleaks.toml kept
bin/gates/pack.sh seat <app clone> && bash <app clone>/tests/gates.test.sh   # 16 passed in each of six app clones
bin/agents/eir-doctor.sh check               # the gatepack row names each repository's state
```

The leak audit of each app repository's history, run before the pack was turned on, is written in the operator's
plan 372.
