## runtime · unversioned · 2026-11-14 — the plan-watch unit in the tree was a rendered unit

The private sweep found `systemd/nornir-job-plan-watch.service:5` carrying a literal checkout path:

```
ExecStart=/bin/bash -lc 'cd /home/zerwizserver/ymir/.yggdrasil/plan-watch && …'
```

That file was a **rendered** unit — one machine, one operator, one worktree — committed into a public
tree by the commit that added the plan watch (`d4490b23`). The repository's own convention is the
opposite: a unit that lives here is a **template**, with a token the renderer fills
(`tools/mill/systemd/*.service` use `__YMIR_ROOT__`), because a rendered unit names a machine and that
is private data (RULES/04, RULES/07).

### What changed

| file | change |
|---|---|
| `systemd/nornir-job-plan-watch.service` | the rendered unit becomes a template: `__YMIR_ROOT__`, with a header saying a rendered unit never comes back into this tree |
| `bin/time/nornir-job-plan-watch.sh` | `--install` renders the unit **from that template** (was: an inline heredoc followed by a `sed` whose output went to `/dev/null`, so the substitution never happened); a fallback keeps the old text if the template is absent |
| `bin/engine/units.py` | `render_template()` also fills `__YMIR_OPERATOR_HOME__`, so no template can leave one machine's home in a rendered unit |

### Why the render path had to move too

A template nothing renders is a dead door. `--install --dry-run` is what a person (and
`bin/gates/tests/test_plan_watch.sh`) reads to see the unit, so it now prints the **rendered template**:
the same three lines it printed before, with this checkout substituted at that moment instead of a
stranger's checkout baked in at commit time.

```
$ bin/time/nornir-job-plan-watch.sh --install --dry-run
[Unit]
Description=Plan watch (Nornir job)
[Service]
Type=oneshot
ExecStart=/bin/bash -lc 'cd <the checkout that ran this> && bin/time/nornir-job-plan-watch.sh'
[Timer]
OnCalendar=*-*-* 07:30:00
…
```

The rendered unit for a seat is written to that seat's own unit directory
(`~/.config/systemd/user/`) by `bin/seat/clocks.sh install`, as `ymir-plan-watch.service`; this door
only prints the rendered template. Either way a rendered unit is never committed.

### Files

- `systemd/nornir-job-plan-watch.service`
- `bin/time/nornir-job-plan-watch.sh`
- `bin/engine/units.py`

Found by `bin/time/nornir-job-private-scan.sh` (sweep 2026-11-14T03:51:38Z). The home's record of what
moved is `hodd/docs/machines/zerwizserver/2026-11-14-the-machine-paths-left-the-public-repo.md`.
