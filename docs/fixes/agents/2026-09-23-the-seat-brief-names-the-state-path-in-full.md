## agents · unversioned · 2026-09-23 — the seat brief names the state path in full (a worker wrote into the code tree)

### Why
- **The seat brief named a relative path, so the worker wrote where the bridge
  does not look — and into the code tree.** The brief said *"write the QUESTION
  to `state/eindri-questions/<name>.md`"*. A seated worker's cwd is the code tree,
  so that resolved to `<repo>/state/eindri-questions/<name>.md`. But the
  Eindri→Brokk bridge resolves its state through the hoard
  (`bin/hoard-lib.sh` → `$YMIR_STATE_DIR`), i.e.
  `$YMIR_HOME/state/eindri-questions/`. The two paths never met, so the route
  stayed silent.
- **Proven live (2026-09-23).** The `snotra` Eindri was seated, told to ask about
  a genuine fork (the release version), and did exactly as told:

  > *"Question written. Snotra stands down — awaiting Brokk's answer via
  > bin/eindri-send.sh."*

  The file landed at `/home/heimdall/ymir/state/eindri-questions/snotra.md` — in
  the **repo tree**. `eindri-seen.sh` read *false*, the wake queue stayed empty,
  and Brokk was never woken. Copying the same file to
  `$YMIR_HOME/state/eindri-questions/snotra.md` made the whole route fire
  (`SEEN`, then `"snotra","QUESTION", …` in the wake queue), which isolated the
  defect to the path and nothing else.
- **It was also a Rule 04 violation.** State written under the code tree is lost
  when a packaged install replaces that tree. The hoard path is the only correct
  home for a worker's records.

### Fix
- **`bin/herdr-run.sh`** — the seat brief now names the state path **in full**,
  expanded from the already-resolved `STATE_DIR` (which `hoard_state_dir`
  produces at the top of the script):
  - question → `$STATE_DIR/eindri-questions/$NAME.md`
  - report → `$STATE_DIR/eindri-reports/$NAME.md`

  The brief says so explicitly — *"that exact path — NOT a relative `state/`
  inside the code tree"* — so a worker cannot reasonably land it in the tree.

### Verification
- `bash -n bin/herdr-run.sh` clean.
- The expansion was checked against the bridge's own resolution:
  `STATE_DIR = /home/heimdall/Documents/ymirhome/state`, and
  `bin/eindri-seen.sh` resolves `STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"`
  — the same directory.
- The route was proven end to end with the file in that directory (see above).

### Files
- `bin/herdr-run.sh`
