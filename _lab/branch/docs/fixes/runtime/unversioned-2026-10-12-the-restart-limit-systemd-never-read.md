## runtime · unversioned · 2026-10-12 — the restart limit systemd never read

### Why

`mcp-gateway.service` on this seat had looped **2246 times** on an `ExecStart` path that no
longer existed. The unit carried a restart limit — `StartLimitIntervalSec=120`,
`StartLimitBurst=10` — so it should have stopped after ten. It never did, because those two
keys sat in `[Service]`.

systemd moved `StartLimitIntervalSec` / `StartLimitBurst` to `[Unit]` in **v230**. Anywhere
else it ignores them, and says so exactly once per start, in a line nobody reads:

```
mcp-gateway.service:11: Unknown key 'StartLimitIntervalSec' in section [Service], ignoring.
```

**A limit that is silently ignored is worse than no limit: it reads as protection.** The
guard was written, reviewed, and shipped — and never applied once.

The misplacement was not one file. Measured against the pre-fix tree:

```
pre_fix[3]{shelf,templates,with_startlimit_in_service}:
  "tools/mill/systemd","13","10"
  "tools/web/systemd","6","5"
  "tools/mill/systemd/ymir-syn-watch.service","—","the ONLY one already in [Unit]"
```

`ymir-syn-watch.service` had it right, which is the proof the correct placement was known
and the rest simply drifted.

### The second question: why was the deployed unit never re-rendered?

Because nothing that ran on this seat re-renders an existing unit.

`bin/fleet/fleet-ensure.sh` renders units through `materialize_web_unit`, substituting
`__YMIR_BIN_DIR__` → `$FLEET_TEMPLATE_ROOT/bin` at render time. That render happens **only**
under `fleet-ensure.sh ensure`, which is invoked by `ymir-install.sh`, `ymir-autoboot.sh`,
and `eir-doctor.sh fix` — never by `status`, and never by `eir-doctor.sh check`. A unit
rendered by an older template is corrected only when an `ensure` pass runs.

This seat was renewed by a hand `git merge --ff-only` after the `bin/` reorganisation, so no
`ensure` pass had run since the move. The unit kept its pre-move rendering, pointed at a path
that was gone, and looped — with the brake it believed it had.

So the stale path and the ignored limit are one failure, not two: the seat had no pass that
re-renders, and the loop had no limit to stop it. This note mends the second half. **The
first half — a deployed unit that no longer matches its template is invisible to
`fleet-ensure status` — is filed as its own ticket**; it is a behaviour addition and does not
belong in a fix note that must be verifiable in one pass.

### Mend

- **15 templates**: `StartLimitIntervalSec` / `StartLimitBurst` moved from `[Service]` to the
  end of `[Unit]` — 10 under `tools/mill/systemd/`, 5 under `tools/web/systemd/`
  (`bifrost`, `hlidskjalf-gate`, `hlidskjalf-spa`, `mimir`, `smidja`). Values unchanged.
- **New gate** `bin/gates/checks/unit-template-check.sh`, wired into `bin/gates/ci-verify.sh`
  as `gate units`. It is deliberately general: it does not know about `StartLimit`. It renders
  every template and fails on **any** key, lvalue, or section `systemd-analyze verify` reports
  it will ignore — the whole class, not the one instance. On a host without `systemd-analyze`
  it SKIPs cleanly (Rule 05: a platform layer is gated on its host, never a false failure).
- **`bin/gates/guards/fixes-guard.sh`**: `tools/{mill,web}/systemd/*` and
  `bin/fleet/fleet-ensure.sh` mapped to `runtime`; `bin/gates/ci-verify.sh` and
  `bin/gates/checks/*` mapped to `gate`. Before this, `tools/*/systemd/*` mapped to **no
  component at all** — a correct `runtime/` note covered nothing and the guard passed on a
  technicality while saying it could not tell. Same defect as the `bin/skuld/*` row above it.
- **Derived registers re-run in the same pass**: `bin/README.md` (417 files) and
  `.agents/assets/agents/capabilities.md` (452 door rows) — the new check needs a row or it
  does not ship.

### Verified

```
verified[4]{check,result}:
  "systemd-analyze verify, rendered as the gate renders — PRE-fix","15 of 19 templates FAIL: Unknown key 'StartLimitIntervalSec' in section [Service], ignoring"
  "the same check — POST-fix","0 of 20 templates: unit_templates 20 'ok — systemd reads every key'"
  "bin/gates/checks/unit-template-check.sh","rc=0 on the worktree"
  "bin/gates/inventory.sh --check · capabilities.sh --check","both current (rc=0); the new check registers as tested · keep"
```

`bash -n` clean on both `ci-verify.sh` and the new check.

### Not done here

- **The units already deployed on this seat** were mended **by hand** (the `ExecStart` path
  and the section move) when the MCP gateway was raised. This repo change does not re-render
  an existing deployed unit; that happens on the next `fleet-ensure ensure`. The template and
  the deployed file are therefore correct independently, not by this commit's action.
- **The drift check** — `fleet-ensure status` reporting a deployed unit whose content differs
  from its freshly-rendered template — is filed separately, not smuggled in here.
- **Ticket**: this closes #55 (*"the mcp-gateway unit template puts StartLimit\* in [Service]
  — the limit never applies (2246-restart loop)"*).
