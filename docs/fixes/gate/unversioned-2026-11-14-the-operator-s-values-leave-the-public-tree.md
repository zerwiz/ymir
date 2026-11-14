## gate · unversioned · 2026-11-14 — the operator's people, domains and machines leave the public tree

### Why

The repository ships to strangers and is installed on their machines, so it may carry the house's
craft and never the operator's life. It carried both: real people in prompts, companies and a mail
domain in the mail tools, thirty-odd host names in comments and defaults, a realm name in a Hlidskjalf
stylesheet and in a dozen code paths, and a desk whose tiles were six of his URLs. `public-guard` had
been judging shapes since 2026-11-03, but it allowed his real mail domain in its own allow-list — the
ward re-created the leak it exists to refuse.

Plan 288 §1 draws the line: a value **about this operator** lives in his home; the code that needs it
**reads** it, through one resolver, with a template in the repository (`RULES/42`). Plan 287 §3 is the
rule: examples are invented (`Ada`, `example.org`, `host-a`), and where a name was only scenery it
becomes the role (*the heart*, *the dev machine*, *a second machine*).

### What moved to the home, and the resolvers that read it

Three resolvers now live in `bin/vault/hoard-lib.sh`, the one door every script already uses:

| Resolver | Answers | Replaced |
|---|---|---|
| `ymir_plan_dir` | the canonical plan ledger: the single `svartalfaheim/<realm>/projects/<project>/plans` in the home (the older `workspace/` shape only when `projects/` has none) | the realm spelled in `behind.sh`, `plan-state.sh`, `plan-board.sh`, `plan-audit.sh`, `queue.sh`, `review-seat.sh`, `ymir-mcp.py` and five comments |
| `ymir_fleet_heart` | the fleet registry's `heart` | `HEART="${YMIR_HEART:-zerwizserver}"` in `bin/records/well-door.sh` |
| `ymir_house_domains` | the domains the home calls its own | `*@zerwiz.org` in `identity-guard.sh` and `bin/records/developers.sh` |

Against those, two home files ship a template and a seed row (`.agents/home-contract.yaml`):

- `$YMIR_HOME/hodd/identity/house-domains.txt` (`.agents/config/house-domains.txt.example`) — the
  house's own mail domains: a commit may be authored as `<agent>@<one of these>`, and such an author
  is shown unmasked. Absent, both wards allow only the generic `@ymir` forms and say so.
- `$YMIR_HOME/config/nda-allow.yaml` (`.agents/config/nda-allow.operator.yaml.example`) — the words
  the NDA gate must allow because they are his: his realm, his mail domain, his handle, each with a
  reason. `ndalib.load_allow` merges the repository's generic list with this one; an entry with no
  reason is ignored in both.
- `$YMIR_HOME/config/gimle/{desk-tiles,plane-workspaces}.txt` — the desk's places and the board's
  workspaces, so `bin/gimle/desk.py`, `bin/gimle/plane_reader.py` and `bin/time/daily-line.sh` stop
  shipping a list of his.

Values that were defaults became configuration, and an empty answer is now a clean refusal that names
the setting instead of pointing a stranger's install at a machine of ours: `PING_ROOM_HOST`,
`NPM_PRETEST_HOSTS`, `RAIL_KEY_PROVIDERS`, `YMIR_DESK_TILES`, `GIMLE_PLANE_WORKSPACES`,
`GIMLE_PLANE_WORKSPACE`, `PLANE_API_BASE`, `RAIL_KEY_PROVIDERS`, and the collab register's `host`.

Three smaller corrections of the same class: `bin/seat/seats.sh` shortened **his** home with a literal
(`/home/heimdall`) and now shortens this user's; `bin/seat/machine-profile.sh`'s seat table of four
hosts became `hostname -s`; and three scripts that fell back to `"${_h:-$HOME/Documents/ymirhome}"`
(`smith-seat.sh`, `verdict-watch.sh`) now refuse when the resolver names no home.

### The wards

- **`public-guard.sh` defers to `public-guard.py`.** It was a second implementation of the same rule
  and its allow-list carried the operator's real mail domain. The file stays (a rule, a skill and
  `.secret-guardignore` name it) and keeps its two flags; the judgement is no longer restated.
- **`public-guard.py`** no longer allows the real domain in `MAILBOX_ALLOWED_DOMAIN`, and its comment
  no longer quotes the real tailnet id.
- **`ssh-roads-guard.sh`** honours `YMIR_FLEET_REGISTRY` — the override `role.sh` and the public ward
  already honour — so a test can judge a fleet of its own. `bin/gates/tests/test_fleet_roads.sh` was
  rewritten to do exactly that, with `host-a` and a temp registry.
- **`bin/time/nornir-job-private-scan.sh`** derives its home-path and house-domain rules from the
  home's `fleet.json` ssh users and `house-domains.txt` instead of naming them.

### Prompts and shipped documents

`.agents/` was swept the same way, except `nsr-compliance` (his call, plan 288 §3): the agent
contract's ledger path, both copies of the server-stack registry, the elder's ledger page, the
ratatoskr and tyr pages, the Snotra, Óðrerir, Smíðja, Hlidskjalf, Nornir, memory-well and Þing assets,
the harness page that named a partner, and the OpenCode plugin. The plugin is the one real behaviour
change there: `ymir_plan` and `ymir_place` resolved the realm as a **default parameter**
(`whynotproductions`), so both now call a new `planLedger(home, realm?, project)` that discovers the
ledger by the same precedence as the shell resolver and refuses, naming what it found, when a home
holds several.

The collab kit's shipped documents use `Ada` and `Example-ControlTower`, and
`bin/forge/conflict-errand.md` no longer sets the operator's GitHub identity on a smith's machine — it
derives the smith's own from `gh api user`.

### Files

- `bin/vault/hoard-lib.sh` (+3 resolvers), `bin/vault/tests/test_home_resolvers.sh` (new, 11 proofs)
- `bin/records/{behind,plan-state,plan-board,well-door,developers,snotra-ladder,comms}.sh|py`,
  `bin/gates/{plan-audit,queue,doc-sweep}.sh`, `bin/gates/guards/{public-guard.sh,public-guard.py,
  identity-guard.sh,ssh-roads-guard.sh,ndalib.py,defaults-guard-row fixes}`, `bin/gates/tests/
  {test_fleet_roads,test_pr_identity,test_nda_guard}.sh`, `bin/forge/{review-seat,smith-seat,
  verdict-watch,conflict-errand.md}`, `bin/collab/*`, `bin/gimle/*`, `bin/mail/*`, `bin/people/*`,
  `bin/notify/*`, `bin/voice/*`, `bin/thing/ping-room.sh`, `bin/time/*`, `bin/seat/*`, `bin/pi/*`,
  `bin/model/*`, `bin/mcp/ymir-mcp.py`, `bin/engine/*`, `bin/fleet/*`, `bin/bridge/*`, `bin/host/*`,
  `scripts/*`, `src/ymir_runtime/{fleet/rail.py,tests/test_allow.py}`
- `apps/{bilskirnir,odrerir,rodd,sessrumnir}` — `apps/hlidskjalf`, `apps/smidja-factory` and
  `bin/agents` were NOT touched (their errands had not landed)
- `.agents/` — the 18 prompt files, except `nsr-compliance`
- `.agents/config/{house-domains.txt.example,nda-allow.yaml,nda-allow.operator.yaml.example}`,
  `.agents/home-contract.yaml` (three new rows)

### The home side (shipped, not in this repository)

`hodd/identity/house-domains.txt`, `config/nda-allow.yaml`, `config/gimle/desk-tiles.txt`,
`config/gimle/plane-workspaces.txt` — one `home-sync.sh ship` to `origin/main`.

### Proof

- `bin/gates/guards.sh` — 0 FAIL on this push (two INHERITED findings name files this branch does not
  touch: the weave index drift and cron's missing scripts).
- `public-guard.py --tree` — 5 findings, all `docs/features/…` and `docs/fixes/mail/…`, which is
  `agnostic-docs`' shelf; nothing in this change's scope.
- `bin/vault/tests/test_home_resolvers.sh` 11/11 · `bin/mail/tests/test_gna.py` 41/41 ·
  `bin/gates/tests/test_nda_guard.sh` 37/37 (three new proofs: a word allowed in the **home's** file is
  let through, the repository's refusals still bite, and a home entry with no reason is ignored) ·
  `test_fleet_roads`, `test_pr_identity`, `test_pr_ship_guard`, `test_plan_state`,
  `test_desktop_main_guard`, `test_plan_watch`*, `test_review_seat_verdict`,
  `test_people_guard_people`, `test_gimle_mcp_board`, `bin/notify/tests/test_open_target.sh`,
  `bin/desk/tests/test_in_call.sh`, `bin/voice/tests/test_rodd_arm.sh` (61/61) — all pass.
- `PYTHONPATH=src python3 -m unittest ymir_runtime.tests.test_allow ymir_runtime.tests.test_rail` —
  33/34; the one failure (`test_a_dated_grant_allows…`) fails identically on `origin/main`'s tree.

### Known, and NOT this change's

`test_rodd_helm.sh` (3), `test_rodd_pin.sh` (2), `test_worker_speaks_to_helm.sh` (4),
`test_sol_stamps.sh` (3), `test_jev_doors.sh`'s live assertion (1) and the one `test_allow` failure
above fail identically on the untouched main checkout (`7ae52975`); measured, not assumed.

*`test_plan_watch.sh` runs `bin/time/nornir-job-plan-watch.sh` for real, and that job nudges the helm:
running it twice sent duplicate `plan-watch` lines to the helm's pane. Reported to the helm; the test
is not run again in this errand.

galdr-reread: `harness-integration/README.md` was not touched; the touched `.agents/` assets are named
above and were read before editing.
