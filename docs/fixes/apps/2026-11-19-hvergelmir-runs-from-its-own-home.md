## apps · 2026-11-19 — Hvergelmir runs from its own home: start, data, face and stop

### Why
After the split, Hvergelmir was installed for the first time on a dev machine through `bin/apps/apps.sh install hvergelmir`
and started from `~/.local/share/ymir-apps/hvergelmir/current`. The install was green. The start was not right, and the app's
browser face had no road from the installed release.

### What was wrong (the causes)
All four sit in the app's own repo (`zerwiz/hvergelmir`), not in Ymir:

| Fault | Cause | Effect |
|---|---|---|
| A faux start died wanting keys | `start.sh` sourced the config `.env` with `set -a` **after** the caller's environment | the file's `DNA_SEARCH_MODE=web` overwrote the caller's `fixture`, so the API asked for live credentials and exited |
| The database landed in the release | nothing set `DNA_DATA_DIR`, so the API used `<release>/data` | the next update or rollback flips `current` and strands the database behind it |
| The browser face could not be raised | `install.sh` never built `apps/dna-client-browser/fe/dist`, and no door started the hub | only the API came up; the face needed a developer's `just` recipe |
| `stop.sh` could miss the port | it read only the caller's `DNA_PORT`, never the config's | a port set in the config was not lowered |

### What changed
One commit in the app's repo, `495cea7` on branch `eindri/e2e-hvergelmir` (not pushed; the helm carries it). The branch
is kept in the installed clone at `~/.local/share/ymir-apps/hvergelmir/repo`.

- `start.sh` hands the config to the API as `DNA_ENV_FILE`. Node's `process.loadEnvFile` fills only what the caller left
  unset, so the caller wins. It defaults `DNA_DATA_DIR` to the app's state dir (`~/.local/state/hvergelmir/data`).
- `install.sh` builds the browser face, and `install.sh --check` fails when the face is not built.
- `hub.sh` is new: it raises the hub (the face) on `:4851` the same way, from the built face.
- `stop.sh` lowers both ports, each from the caller's env, then the config, then the default.

No Ymir file needed a change for the app to stand alone.

### Proof
On the dev machine, the desk free (`bin/desk/in-call.sh holder` printed nothing):

- `bin/apps/apps.sh install hvergelmir` printed `"hvergelmir","updated","current 2f7ce719f511"`, exit 0.
- In a fenced apps home, `install` from `main` and then `update` to the fix flipped `current -> releases/495cea7eb42a` and
  `previous -> releases/2f7ce719f511`. `check` was green, two `rollback`s flipped back and forth, and `remove --yes` removed
  the home and kept state and config.
- From the fixed `current`, `start.sh` printed
  `dna-server-api on http://127.0.0.1:4850 (local, faux, search fixture, model faux-haiku, pi-durable 1.1.0)`, and `hub.sh`
  printed `Durable News Agent: http://127.0.0.1:4851`.
- An app window on the hub mapped: `hyprctl clients` showed title `Durable News Agent`, `mapped True`, and its pid lived.
  DevTools read the page text, which held the three cards.
- The core path ran: `POST /v1/workflows/news-sweep` returned 202. Sweep 1 completed with 12 gathered, 8 kept by the jev
  gate, 0 duplicates and 3 presented. `GET /v1/feed` returned the three cards.
- After a restart on the other release, the three cards were still there. Sweep 2 returned `no_news`, because the durable
  store remembered what sweep 1 had gathered.

> [!NOTE]
> The installed `current` here is still the shipped `2f7ce719f511` until the fix lands on the app's `main`.
> `apps.sh update hvergelmir` then carries it. The first, unfixed start left a stray `data/` inside
> `releases/2f7ce719f511/`. It holds no needed data, and it goes with that release when the prune drops it from the
> last three.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
