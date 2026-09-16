# Rule 09 — Electron is a Local Seat

A desktop window is the machine talking to itself. Every rule below follows from
that one sentence.

## 09.1 Local connections only

**An Electron shell loads loopback and nothing else.** A URL that is not
`127.0.0.1`, `localhost` or `::1` is refused, with a warning, and replaced by the
local default. If a shell is handed a public hostname — a tunnel, a `*.zerwiz.org`
name — it must **not** honour it.

Why the law, not a preference: a desktop app that dials out is a desktop app whose
failures belong to somebody else's edge. A bridge that dressed a cloud endpoint as
`127.0.0.1` cost a night of "the agents never start"; a shell that reaches for a
public hall when its own machine is quiet is the same mistake wearing different
clothes.

**Cloudflare has nothing to do with Electron.** Tunnels exist for the *web* door,
so a person elsewhere can reach the apps. The desktop is already where the apps
live.

## 09.2 No login in the desktop seat

The web door has exactly one login; the desktop seat does not have one at all. The
shell is a local, trusted seat — its preload marks its requests, and the gate
honours that marker **only from loopback**. A login prompt inside an Electron
window means the surface has been mistaken for the web.

## 09.3 A service that is down says so

When a local service is not answering, the shell reports it — it does not fall
back to a remote copy, a cached one, or a public hostname. A wrong answer from
the wrong server is worse than no answer.

## 09.4 The shell carries the house mark

Every app ships its own **rune** icon (see `midgard/design-system/runes.md`), and
installation writes both the icon into the user's icon theme and the `.desktop`
entry into their applications directory — with this machine's root rendered in, so
the entry works and the operator can pin it. An app nobody can pin is an app half
installed.

## 09.5 One lifecycle for the web and the windows

`scripts/raise.sh` and `scripts/lower.sh` own both. Lowering takes the **windows
down first**, so no shell is left watching a port that has just vanished.

## 09.6 References

- `apps/hlidskjalf/electron/`, `apps/odrerir/electron/`, `apps/sessrumnir/src/main/`
- `scripts/electron.sh` — the shell lifecycle; `scripts/raise.sh` / `scripts/lower.sh`
- `bin/design-icon.sh` — the rune and the entry, installed
- Rule 05 (platforms), Rule 07 (config resolves from env, never a literal)

---

*Append-only. A correction is a new entry citing the old one.*
