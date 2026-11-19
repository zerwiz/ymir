## rodd · 2026-11-19 — the voice window leaves for its own repo; the arm and the voice stay in Ymir

### Why
The Allfather: *"time to separate the mono repo"*, *"i dont wanna them come into the apps folder anymore if installed
they need their own places"*, *"we can not lose anything"*, and *"take rödd after bilskirnir"* (plan 07).

"Rödd" names two things. **Only the window moved**: `apps/rodd` (the Electron face over the speech-to-speech engine's
browser page). **The arm, the helm, the wake queue, the `tell` road and the voice machinery** (`bin/voice/`, `rodd-arm.sh`,
`rodd-helm.sh`, `rodd-head.py`, `voice-door.sh`, `voice-toolbox.py`, the supervisor) are the house's, carry the name for
history only, and **stay in Ymir**, unchanged.

### What moved
`apps/rodd/` (31 files) → `zerwiz/rodd`, cut with `git filter-repo --subdirectory-filter`: every one of the 27 commits
that touched it here, authors and dates kept. Its upstream face (huggingface/speech-to-speech v1.1.0, Apache-2.0) is still
fetched at install, never committed.

### It finds Ymir instead of climbing to it
The window reached Ymir's voice by climbing two folders up (`$APP/../..`); installed in its own home, that finds nothing.
- `scripts/ymir-root.sh` finds Ymir (`YMIR_RUNTIME_DIR`, the pin, the old tree). Ymir is a **hard** need here (her voice
  door, head, toolbox and desk check are Ymir's), so without it the window refuses in words: *"her voice comes from Ymir
  … and Ymir is not installed on this machine"*.
- `start.sh` hands over to the pin's copy only when the window sits in a Ymir tree; in its own home (a release exported
  from its repo, never a working tree) it runs where it stands, on its own release's Electron.
- **`src/pin.js` would have refused every installed start**: it served the face from the pin's `apps/rodd/ui`, which
  leaves with the window. In its own home it serves its own `ui/`.
- The unit template names the window's folder as `__APP_DIR__`: `desktop-place.sh` fills it with the pin's copy while
  the window is in a tree, its own home's `current` link after; the window's `activate.sh` renders the same file.

### Ymir's side
`ymir-app` and the stopwatch find the window through the resolver, as do the icon tool and `voice-ensure.sh` (which
builds the face). **The arm-pin checks** (`bin/pi/arm-pin.sh`, `bin/seat/armpin.sh`) recognise the window's processes in
its own home and accept that home as lawful, as they accept the pin — otherwise they would have reported the installed
window as "runs outside the pin". The face gate runs its own test only while it is in the tree. Lines kept on purpose
are in `config/split/rodd.kept.tsv`. The registry: `contract: 1`, `moved: zerwiz/rodd@<sha>`, `install_default: dev`.

### Found on the way
`bin/voice/tests/test_rodd_pin.sh` had two checks gone stale (8 of 10 on main) since the pin code moved from `main.js`
into `src/pin.js`; they read `pin.js` now, both roads (12 of 12), and the test skips once the window has left.
`bin/voice/tests/test_rodd_helm.sh` fails 7 of 31 **on main too** (the refusal-spoken and dedupe checks) — untouched
here, owed as its own fix.

### Proof
- `split-ledger.py verify rodd`: 31/31 files, 27/27 commits, 12/12 fix notes, 0 ties owed — **nothing lost**.
- From the cut repo into a fenced apps home: install fetched the face at v1.1.0 and the window's Electron, `--check`
  green, flipped; `activate.sh` rendered the unit (`WorkingDirectory=<apps home>/rodd/current`,
  `YMIR_RUNTIME_DIR=` the pin) and the launcher (`ymir-app rodd`).
- The installed window resolves its own face (`index.html` and the SDK bundle present) and refuses in one line without
  Ymir; `start.sh` says the same.
- The arm untouched: `test_rodd_arm` 61/61, `test_arm_pin` 14/14.

### Owed
- A real voice turn through the installed window — only with the Allfather at the desk and no call held (the desk
  law): it raises the voice engine on the GPU and opens the microphone.
- Push `zerwiz/rodd` (held for the one PR), and the move record in the home.
