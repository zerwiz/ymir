# The doctrine still described the retired two-home extension design

**Dated:** 2026-10-07 · **Component:** agents (Pi extension surface) · **Branch:** `docs/pi-extensions-one-home`

## The symptom

Commit `ac5fd8ad` (2026-10-04) moved every Pi extension into `.pi/extensions/`
and deleted `.pi/shared/extensions/` — one home, nothing deployed. The **code**
peeled its roots and doors forward (PR #299), but the **doctrine** kept answering
the question *"where does an extension live?"* with the retired two-home model:

- `RULES/13-pi-extensions.md` §1: "The source is `.pi/shared/extensions/`; the
  deployed copy is `~/.pi/agent/extensions/`"; §2: "`.pi/extensions/` holds no-op
  factories".
- `.pi/extensions/README.md`: "This tree is NOT the extension home".
- `bin/seat/valknut-load.sh`: `PI_EXT_SRC="$ROOT/.pi/shared/extensions"` — a
  directory that no longer exists, so its deploy did nothing, its `--check`
  vacuously passed the mirror comparison and **failed the project tree as
  duplicates**, and it never wrote the `.ymir-root` record a fresh install needs.
- `.agents/tests/pi-extensions.test.sh`: asserted the two-home shape and
  `skip_all`ed because there was no source tree.
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`: a
  three-row table and several paragraphs pointing extensions at the retired path.

Nothing throws when doctrine and tree disagree — the tree loads, or it does not,
and the document quietly misleads the next reader.

## The mend

- **`RULES/13-pi-extensions.md`** — an appended correction section (Rule 06: the
  rule is appended, never rewritten). It names the superseded text so a reader is
  not misled, and states the four things that stand now (one home; the global home
  holds no extension; the gate is `valknut-load --check`; roots are walked).
- **`.pi/extensions/README.md`** — rewritten: this tree *is* the home; the global
  tree holds only `.ymir-root`; the extension and lib tables describe the one tree.
- **`bin/seat/valknut-load.sh`** — `PI_EXT_SRC` is now `.pi/extensions/` (the one
  home). It **deploys nothing**: it removes any `~/.pi/agent/extensions/<name>` that
  also stands in the project tree (the collision Rule 13 exists to prevent), writes
  the `.ymir-root` record, and `--check` fails when an extension is in two load
  paths or the record is missing.
- **`.agents/tests/pi-extensions.test.sh`** — rewritten to assert the one-home
  reality; no longer skips.
- **`harness-integration/README.md`** — the two-home table and the deploy
  paragraphs replaced with the one-path model; the 23 `.pi/shared/extensions/`
  references resolved.

## Proof

```bash
bin/seat/valknut-load.sh --check   # PASS: project home 16 exts · no two-path dup · .ymir-root resolves
.agents/tests/pi-extensions.test.sh   # all checks pass (exit 0)
bin/seat/valknut-load.sh --pi      # "one tree — the project home (nothing deployed)"
ls ~/.pi/agent/extensions/         # only .ymir-root
```

## The one line

**One home per extension — and since 2026-10-04 that home is the repo's
`.pi/extensions/`.** The global `~/.pi/agent/extensions/` holds a root record and
nothing else.
