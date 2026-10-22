## gimle · unversioned · 2026-10-22 — the projector, the places map and the tiles (D2–D4)

### What

- **`bin/gimle/project.py`** — the projector. It reads every meeting under
  `hodd/life/meetings/<workspace>/<id>/` (`meeting.json` for the title and classification, `by-house.md` for
  decisions, questions and actions with their evidence) and writes `meetings.json` for the desk.
  **It refuses class 3**: a meeting whose classification says `restricted`/`confidential` is skipped entirely,
  not redacted. With `--plane` it also files a card per action, **idempotently by title**.
- **`places.json`** — created **empty** and never overwritten by the projector: an empty map means *nobody
  but the operator sees anything*, which is the fail-closed default of plan 105's H3. A membership map is a
  decision, not a projection.
- **`bin/gimle/project-and-publish.sh`** — projects on the seat that holds the record and hands the result to
  the desk on the server (`scp` over the fleet's own ssh), so the desk never reads the hoard directly.
- **a user timer on the seat** — `gimle-project.timer`, every 15 minutes, `OnBootSec=5min`.

### Verified

- projection: **2 meetings**, 0 skipped, `places.json` created empty — *"projected 2 meeting(s) skipped 0
  (class 3) places.json created empty (fail-closed)"*.
- publication: `published server:/home/zerwizserver/gimle/desk/data`.
- the desk with the real session/operator header renders **Due this week · Last decisions · Questions
  waiting on me · The places** and the four tiles **Board · Documents · Whiteboard · Meetings**.
- a stranger (`Remote-User: someone`) sees **0** lines of the meeting content — fail-closed holds.
- the timer is `active` and the first unit run finished successfully.

### Not verified / not done

- **`places.json` is empty**, so the desk is operator-only until real memberships are written. That is
  deliberate; it is not the finished flow.
- the `--plane` card path was **not exercised tonight** (it needs `PLANE_TOKEN` and a project id in the
  environment); the six cards already on the board were filed by the one-off seeder.
- the timer runs on this seat only; the fleet's other seats need the same unit (plan 106 phase 3).
