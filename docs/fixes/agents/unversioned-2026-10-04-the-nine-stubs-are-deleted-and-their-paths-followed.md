## agents · unversioned · 2026-10-04 — the nine stubs are deleted, and their paths followed them

### Why

PR #281 left `.pi/extensions/` holding **nine no-op factories** whose only job was to
stop someone putting a real extension there and colliding with the deployed copy.

**That tripwire is now mechanical.** `bin/valknut-load.sh --check` fails when any
project-local file exceeds a kilobyte or is byte-identical to a source extension —
the same failure the stubs prevented by hand, and now with a number attached.

**So the stubs were measured, not assumed.** Deleted in an isolated worktree with
every gate run either side:

| | with stubs | without |
|---|---|---|
| `capabilities --check` | PASS | **PASS** |
| `inventory --check` | PASS | **PASS** |
| `extension-smoke` | broken=0 | **broken=0** |
| `pi-extensions.test.sh` | PASS | **PASS** |
| `valknut-load.sh --check` | PASS | **PASS** |
| pi discovery, project-local | 9 files | **0, ERRORS: none** |

**Nothing referenced them in code.** They registered nothing, and no code imported
or executed them. Pi loads them purely because they sat in a discovered directory.

### The cost, paid before they went

**Nineteen live references across eleven documents** pointed at the stub path for
extensions we actually ship — `galdr.md`, `runtime.md`, Galdr's `SKILL.md`, `pi.md`
(six, several with line numbers), `norse-naming.md`, `pi-boot-guide.md`,
`porting-upstream-to-norse.md`, `reference-adoption.md`, `brokk-distro-runtime.md`,
`build-method.md`, `omarchy.md` and the root `README.md`. All repointed to
`.pi/shared/extensions/…`.

**Six references were already wrong before this change** — `fm-primary-pi-watch.ts`,
`brokk-primary-turnend-guard.ts` and kin. Those are upstream provenance names in
`porting-upstream-to-norse.md` and `assets/reference/`, and they were **left alone on
purpose**: a provenance column quoting the upstream name is correct even when the
file never existed here. Only the Ymir column was repointed.

**Three fix notes were touched by the sweep and reverted.** A fix note records a path
as it *was*, and Rule 06 says never rewrite one.

### Two drifts #281 left behind, caught here

**1. Galdr's dual surface.** The agent card `.agents/agents/galdr.md` is a byte-mirror
of the canonical skill. #281 added the Rule 13 paragraph to `SKILL.md` and not to the
card, so the compliance gate read *"agent and skill differ"*. **That drift has been on
`main` since #281 merged** — this fix is not only about the stubs. Re-mirrored.

**2. Two TOON table headers.** `governed[10]` held 11 rows and `rules[6]` held 7,
both because #281 added a row without touching the count in the header. The `toon`
gate reads the declared number and fails on the mismatch. Corrected to `governed[11]`
and `rules[7]`.

**Neither would have been found by reading the diff.** Both are count-vs-declaration
mismatches, and both are exactly what a gate that counts is for.

### `.pi/extensions/` now

Empty but for a README that says **why it must stay empty** — the two-path collision,
the exact pi error, and the fact that herdr can only report it as a pane that will
not sit at a prompt. Rule 13 is named there, and the real tree is mapped.

### Verified

```
ci-verify                all gates PASS
compliance               PASS   (15 governance gates)
capabilities --check     PASS   ("Pi extension tools",39)
inventory --check        PASS
extension-smoke          broken=0
pi-extensions.test.sh    PASS
valknut-load --check     PASS
```
