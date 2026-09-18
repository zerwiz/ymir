## install · unversioned · 2026-09-16 — icons the operator can pin, and one pair of hands for the shells

### Why
**"Fail, no icons" — and the cause was a trap I had already been bitten by.**
`bin/design-icon.sh install` writes an app's rune into the icon theme and a
`.desktop` entry into the applications dir. It used `XDG_DATA_HOME`, and this
agent session exports that as a **sandbox** (`…/opencode-rd`), so the icons went
somewhere no desktop can see. It now targets the operator's real data dir
(`$HOME/.local/share`, with `YMIR_DESKTOP_DATA_HOME` for a throwaway test) — the
same class of bug that once hid `gh` from this session.

Installed now, for **every** app: hlidskjalf, **odrerir**, **sessrumnir**, the
Smíðja visualizer and hlidskjalf-mobile — each with its rune icon and a dockable
entry. Óðrerir and Sessrúmnir had **none**, which is exactly why they could not
be pinned. The stale `ymir-smidja.desktop` (pointing at a repo PNG) is folded
into the rune's own entry.

**One pair of hands for two lifecycles.** `scripts/start.sh` and
`scripts/stop.sh` manage the web; `scripts/electron.sh` manages the shells — and
they never met, which is why "the electrons are not running" was true while 28
processes stood, and why a restart could leave a shell watching a dead port.
`scripts/raise.sh` / `scripts/lower.sh` own both: lower takes the windows down
**first**, so none is left watching a port that just vanished.

**A bug the restart surfaced:** `scripts/electron.sh stop` used `local` outside a
fu

### Files
- *(carried from the frozen CHANGELOG.md)*
