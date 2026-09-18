## agents · unversioned · 2026-09-14 — The Eindri→Brokk wake bridge (they can talk back now)

### Why
- **Ask:** the seated smiths' reports lived in their panes only; the Allfather
  wanted a feature that wakes Brokk when an Eindri reports, so the fleet's
  doings reach the primary's session — "we are in control, Brokk".
- **Built:** `bin/eindri-seen.sh` (condition — a report file landed or herdr
  shows the smith left `working`), `bin/eindri-acclaim.sh` (action — files the
  report durably under state/eindri-reports/, marks done under
  state/eindri-done/, appends the wake to state/.wake-queue for Sága's drain,
  sounds the desktop note), and `bin/eindri-watch.sh` (the control door —
  `arm | retire | list | reconcile`, one when-source per smith on the Norns'
  loom via fm-procevent-when.sh, action hash-bound, fires once on a stable
  true, terminal, re-armable).
- **Armed live:** when-odrerir (already fired — his report was filed) and
  when-sessrumnir-cloth (still working). `fm-procement.sh reconcile` started=2.
- **First report delivered through the wire:** odrerir's Óðrerir saga — deck
  green at :4322, 52 Chromium checks, commit 38a326b on yggdrasil/odrerir, main
  untouched, plus the hall.ymir.zerwiz.org server story (setup-hall.sh) and
  three asks awaiting the Allfather (go live, landing mobile wart, PLAN log).

### Files
- *(carried from the frozen CHANGELOG.md)*
