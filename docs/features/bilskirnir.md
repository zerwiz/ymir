# Bilskirnir — the business hall

## What it is

Bilskirnir is the hall of many rooms. Every agent has its own room, its own screen, and its work in plain sight. You
give an agent an errand and watch it forge.

It is the house's **business** hall: running the house's business, and still able to code, research and take every
other errand. Sessrúmnir stays the developer's seat. The first agent who answers is **Nanna**, Ymir's own assistant;
a user who wants another name sets `fleet.assistant` in their own roster.

It opens in its own Electron window, like the other Ymir apps, and fits every screen from a phone to a wide desktop.

## What you need

- Ymir installed. The install step `bilskirnir` runs `apps/bilskirnir/setup.sh` for you, and Gróa runs it again after
  every update.
- `hermes` on your PATH, so Nanna can answer. Without it the hall still opens, and Nanna stays silent.
- An `electron` binary for the window: a system package (`/usr/lib/electron*`) or `npm` electron. Without it, open
  the hall in a browser.
- The model rail reachable (the rail key is read from `~/.pi/agent/auth.json`).

## Do it

```bash
apps/bilskirnir/start.sh             # raise the hall and open the window
apps/bilskirnir/start.sh --check     # what is up, change nothing
apps/bilskirnir/start.sh --stop      # lower what start.sh raised
apps/bilskirnir/start.sh --headless  # no window: open http://127.0.0.1:8787 in a browser
apps/bilskirnir/start.sh --dev       # the face from Vite, with hot reload
apps/bilskirnir/setup.sh --check     # is the install current?
```

`start.sh` raises the pieces in the one order that works: setup, Nanna's gateway, the face, the server, and then the
window. A piece that already answers is kept, never restarted. `--stop` lowers only what `start.sh` itself raised.

The launcher entry **Ymir · Bilskirnir** is seated by the setup door wherever a desktop exists.

## On every screen

| Width | What you see |
|---|---|
| wider than 1180 px | three columns: the rooms, the chat, the details |
| 861 to 1180 px | the details slide over the chat; tap the veil or press Escape to close them |
| 601 to 860 px | the rooms become a drawer, opened by the button at the top left of the chat |
| 600 px and under | one column, the chat first; the composer stays above a phone's home bar |

`node apps/bilskirnir/tests/screens.mjs <url> <out-dir> <label>` photographs the four proof sizes in a real Chromium.
It fails when the page scrolls sideways or the composer leaves the screen.

## Settings

| Setting | Where | Default |
|---|---|---|
| `PORT` | `apps/bilskirnir/.env` | `8787` |
| `BILSKIRNIR_HERMES_PORT` | the environment, read by `setup.sh` | `8642` |
| `BILSKIRNIR_MODEL` | the environment, read by `setup.sh` | `qwen3.6-35b-a3b@q4_k_xl-mtp` |
| `BILSKIRNIR_WEB_PORT` | the environment, read by `start.sh --dev` | `5173` |
| `BILSKIRNIR_ELECTRON` | the environment, read by `start.sh` | probed |
| `BILSKIRNIR_DESKTOP` | the environment, read by `setup.sh` | `1` (seat the launcher entry) |

## Limits

- Hosting it on another machine needs a login. The local mode has no sign-in and binds loopback only (plan 259).
- The agents' computers still come from Orgo until the house's own desk replaces it. Without `ORGO_COMPUTER_ID` the
  details say that no computer is set up yet.
- Voice still runs through Bot HQ's cloud voice; the road is Rödd's voice.

## If it does not work

- **"The hall is silent" in the window.** The server did not answer. Run `apps/bilskirnir/start.sh --check`, then read
  `apps/bilskirnir/data/run/server.log`.
- **Nanna says nothing.** Her gateway is down. `start.sh --check` names it; read `data/run/gateway.log`.
- **The install row says stale.** Run `apps/bilskirnir/setup.sh` and read its lines. Eir's `bilskirnir` surface
  reports the same.

## CHANGE LOG

- **2026-11-12** — first written: every screen, its own window, install and Gróa, the house's words.
