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
- `bin/desktop/design-icon.sh` — the rune and the entry, installed
- Rule 05 (platforms), Rule 07 (config resolves from env, never a literal)

---

*Append-only. A correction is a new entry citing the old one.*

## Appended 2026-11-06 — one login, and the surface chooses its home

**At the Allfather's word:** *"no login on runned on the computer locally or in electron. only if the user are
hosting them up"* — said while four seats were being stood up on a shared machine, and said because 09.2 had left a
gap: it fixed *how many* logins a seat has, never *whose*.

The gap was live in the tree. Hlidskjalf held its own password book (`HLIDSKJALF_AUTH`), its own accounts and invite
codes, **and** acted as the doorman for the other seats by hostname (`SMIDJA_HOST`, `ODRERIR_HOST`, `PRIMARY_HOST`),
so a seat's identity was decided by whichever app a browser reached first. Two locks and three ways in.

```
login_law[4]{surface,login,where the identity comes from}
  "run locally, or in a window","NONE","the machine's own two feet — loopback is the operator's own hand. No prompt, no cookie, no ceremony for a local run."
  "hosted, behind a gate","the gate's, and only the gate's","the forward-auth header (`Remote-User`), honoured ONLY from the door's own address, refused and logged otherwise"
  "hosted, with no gate of its own","the seat's own login — the one case it was written for","its own credential store, which is OFF whenever a gate stands in front"
  "never","two logins on one seat","a house with two locks starts trusting the weaker one"
```

**What this forbids:** a seat that asks for a password on its own machine; a seat that is the doorman for another
seat; an app that honours `Remote-User` from a peer that is not the door; a login that is neither the gate's nor the
seat's own.

**Enforced by:** `bin/ward/services-register.sh` (a hosted row declares its road and its gate) · each app's own door
mode (P2 of plan 208) · and 09.1's rule, which already refuses a shell that is handed a public hostname.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
