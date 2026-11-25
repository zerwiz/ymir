Read when: starting or stopping the system, working on Hlidskjalf or another app, touching a port, a tunnel or the schedule (Nornir), or finding where an app lives now.

# The halls, the apps and the schedule

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## Starting the system

- `scripts/start.sh` raises the whole system: the Hlidskjalf SPA (`:3888`), the gate API (`:3889`), Nornir cron,
  Bifrost (`:4603`), Mimir (`:4602`) and the Smíðja visualizer (`:8437`). `scripts/stop.sh` lowers it all.
- `scripts/electron.sh start [--view hlidskjalf|smidja]` opens the desktop shell: an Electron window over Hlidskjalf by
  default, or over the Smíðja visualizer with `--view smidja`, with the app icon and a stable "Ymir" title. `stop` and
  `status` too.
- The units come from the one register, `config/units.yaml` (plan 269), rendered against the pin by
  `bin/engine/units.sh`.

## The halls are local (plan 275 item 30, 2026-11-14)

At the Allfather's word: *"this feature of opening online must go away with the logins we have. we are not hosting the
3 apps online, they are local. [a collaborator's security review] found that we were opening ports out."*

- **No login.** `src/components/LoginModal.tsx`, `HLIDSKJALF_AUTH`, the invite codes, the GitHub OAuth door, the
  accounts store (`apps/hlidskjalf/server/accounts.ts`), `bin/engine/ymir-invite.sh` and `bin/engine/ymir-setup-auth.sh`
  are gone. The desktop session is the authority: `/api/session` answers with the operator's own name and nothing to sign
  in with.
- **No chooser.** The "Take your seat — three halls share one login" screen (`src/components/Halls.tsx`) is gone, with
  the gate's public hostnames (`YMIR_PRIMARY_HOST`, `SMIDJA_HOST`, `ODRERIR_HOST`).
- **Loopback only.** The halls listen on `127.0.0.1`: 3888 Hlidskjalf SPA, 3889 the gate, 4322 Óðrerir, 8437 Smíðja,
  8787 Bilskirnir, 4602 Mímir (the well), 4603 Bifrost. The gate refuses a non-loopback bind unless
  `YMIR_ALLOW_WIDE_BIND=1`.
- **No tunnel points at a hall.** `bin/forge/gjallarhorn-tunnel.sh start` refuses a config whose ingress dials a hall
  port, before cloudflared is looked for, and `… check` audits one without raising anything. A tunnel (Gjallarhorn)
  publishes only a frontier surface, such as the video forge on `:8761` or the hound's notifications on `:2586`
(measured on the operator's seat that day: the tunnels that exist serve `:8761`, `:2586` and `:3891`, none a hall). The fix
  note is `docs/fixes/forge/2026-11-14-no-tunnel-points-at-a-hall.md`.
- **One realm does not hide three.** The workspace-mode chips are retired, but every realm stays visible: a realm is a
  folder under `svartalfaheim/` (Skrymir shows the whole home), and a page that scopes its work by realm offers every
  realm the home holds, read from the operator's registry at run time.
- **Hosted, shared surfaces are Gimlé's** (plan 284). Plans 277 and 279 keep their record; this closes 277's Local reach
  row for the halls and the residue of 279 row 2 on the halls' side.
- Every house unit's PATH names the mise shims, so a service finds the tools a shell finds (plan 275 item 26).

The how-to is `docs/features/hlidskjalf-the-control-plane.md`. Before changing `apps/hlidskjalf/**`, read
`.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`.

## The apps live in their own repos (2026-11-19)

At the Allfather's word: *"time to separate the mono repo … the apps to their own repos"*, *"i dont wanna them come into
the apps folder anymore if installed they need their own places"*, *"we can not lose anything"*.

| App | Where it lives now |
|---|---|
| Hliðskjálf (Hlidskjalf) | stays in this tree, whole |
| Smíðja (the smithy) | `zerwiz/smidja`, home `~/.local/share/ymir-apps/smidja/` |
| Hvergelmir | `zerwiz/hvergelmir` |
| Bilskirnir | `zerwiz/bilskirnir`; its data home did not move, and `ymir-app bilskirnir` finds it |
| Rödd's window | `zerwiz/rodd`; the Gná arm, the helm, the wake queue and the voice machinery (`bin/voice/`) stay here |
| Sessrúmnir | `zerwiz/sessrumnir` (still a pi-desktop fork); `bin/desktop/sessrumnir-*.sh` and the seat wire stay here |
| Óðrerir | `zerwiz/odrerir` (split, not retired); its live board is state in `~/.local/state/odrerir/`, written nightly by the hall-snapshot job |

- Every app is found through `bin/apps/app-path.sh` (`dev` → `home` → `legacy`), installed, updated and rolled back by
  `bin/apps/apps.sh`, and registered in `config/app-repos.yaml` (RULES/23, appended).
- **A move is not a deletion** when the app left with its history and the registry says `moved:` (RULES/11, appended);
  `bin/apps/split-ledger.py verify` proves nothing was lost first.
- An application lives in `apps/`; `bin/` holds function-named machine tools, never an application's name in a path
  (RULES/23).

## The schedule (Nornir) and the portal

- **Nornir** runs stateless jobs (process → inject → execute → write → exit), defined in `config/cron.yaml` and started
  at session start by `bin/time/nornir-cron-start.sh`. The realm's daily schedule includes:
  - `07:00` `bin/time/nornir-job-daily-briefing.sh`, the daily briefing;
  - `06:00` `bin/time/nornir-job-observer.sh`, Huginn, the raven of observation;
  - `00:30` `bin/time/nornir-job-memory-housekeeping.sh`, Muninn-style memory housekeeping;
  - `00:00` `bin/time/nornir-job-git-sync.sh`, which keeps the Yggdrasil world-tree in sync with its remotes.
- **Hlidskjalf is the portal**, the single control plane. Its UI guide is
  `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`.
