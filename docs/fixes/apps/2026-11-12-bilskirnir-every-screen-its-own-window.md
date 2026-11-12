# Bilskirnir fits every screen, opens in its own window, installs with Ymir, and speaks in the house's words

**2026-11-12 · component: apps · `apps/bilskirnir/` · `bin/engine/ymir-install.sh` · `bin/agents/groa-update.sh` · `bin/agents/eir-doctor.sh`**

The Allfather's words, from plan 259:

- *"The UI are not responsive on screen size changes at all."* · *"Must work on the mobile also."*
- *"it should open in an electron as the others"*
- *"This application must be able to be installed and have common updates of Ymir when Gróa updates."*
- *"we need to change all the text in the app too"*
- On the new-agent screen: thirteen identical marks in a shape grid, and Bot HQ's bright colours.

## What was wrong

| Fault | What the user saw |
|---|---|
| Bot HQ is a fixed three-column window (rooms 350 px, chat at least 424 px, details 360 px) | on a phone the hall was cut off at the right edge; on a tablet the chat was squeezed |
| no window of its own | the hall opened only in a browser tab, unlike every other app in the house |
| install and Gróa did not know the app | its soul, its `.env` and its dependencies went stale after an update |
| Bot HQ's words | "Bot", "Create New Bot", "group chat", "Tasks", "Log out", and "the keeper of this machine's hall" |
| the face picker | every face is the Ymir mark, so the shape grid showed the same mark thirteen times; the swatches were red, orange, yellow and green |

## What was done

**Every screen.** A new `web/src/styles/screens.css` narrows the hall in stages. Under 1180 px the details slide over
the chat with a veil. Under 860 px the rooms become a drawer, opened from the chat's own header. Under 600 px it is one
column with the chat first, the composer on the safe area, and 16 px input so a phone does not zoom. The store opens the
details closed on a narrow screen and does not remember that choice. Escape folds away the drawer, then the details.

**The window.** `apps/bilskirnir/start.sh` raises the hall in the one order that works: setup, Nanna's gateway, the
face built into `web/dist`, the server, the window. It keeps any piece that already answers. `--stop` lowers only the
sessions it wrote a pid for, never by pattern. `apps/bilskirnir/electron/` is the shell: it probes the electron binary,
wears the bronze Ymir mark, is titled "Bilskirnir" with app id `ymir-bilskirnir`, and says in a sentence when the hall
is silent.

**Install and update.** `ymir-install.sh` gains the step `bilskirnir` (roles heart and dev). Gróa re-runs
`setup.sh` after every fast-forward and reports it in `--check`. Eir has a `bilskirnir` surface reading `setup.sh
--check`. The setup door now also seats the launcher entry and its icon where a desktop exists, and corrects the old
seed description. The installation asset carries the same.

**The words.** Every visible string now uses the house's words: agents, rooms, errands, the shelf, the hall. The
server's visible errors say the same. Identifiers, API paths and storage keys did not change.

**The face.** The shape grid is gone from both pickers. Six house hues are offered: stone, bone, bronze, rust, moss and
steel. An agent's hue is drawn as a ring and a glow around its mark, so agents stay distinct in the rail and the chat.
Stored colour keys still work and wear the nearest house hue.

## Proof

| Check | Result |
|---|---|
| `node apps/bilskirnir/tests/screens.mjs` at 390×844, 768×1024, 1280×800, 1920×1080 | no sideways scroll; the composer on screen at every size |
| `apps/bilskirnir/start.sh` then `--check` | gateway, server and window up; Hyprland shows class `ymir-bilskirnir`, title `Bilskirnir` |
| `bin/engine/ymir-install.sh --check` | `"bilskirnir","OK","current (apps/bilskirnir/setup.sh --check)"` |
| `bin/agents/groa-update.sh --check` | `bilskirnir: current (agent home, soul, .env, dependencies)` |
| `bin/agents/eir-doctor.sh check` | `"bilskirnir","ok","bilskirnir: ready"` |
| grep for Grokbot, Doug, Chief of Staff and "Bot" in visible strings | none |

## CHANGE LOG

- **2026-11-12** — every screen, the window, install and Gróa, the words, the hue rings (Hœnir, as Eindri).
- **2026-11-12** — the push was refused by `rules-compliance-guard.sh` (RULES/39 N1/N7) for the line that names the XDG
  data path `$HOME/.local/share`: the ward read `.local` as an mDNS host. Narrowed to `\.local\b([^/]|$)`, so a
  `host.local` name is still caught and a `.local/` path segment is not (component: gates).
