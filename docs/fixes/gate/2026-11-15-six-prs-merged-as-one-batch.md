# Six open pull requests merged locally as one batch

### Why

Six PRs sat open (#750, #754, #758, #760, #768, #769) and the server's reviewer never merged them. At the operator's
word they were merged locally into one branch, so the conflicts between them are mended once and the gate runs once.

### What was done

- Merged in order: #750, #754, #758, #760, #768, #769, then current `main`.
- **#754:** the runtime asset keeps both new sections; the private-scan job keeps main's worktree check and the
  batch's warden door.
- **#758:** its new `voice-vad` gate line moved into `bin/gates/checks.d/0262-voice-vad.sh` (the gate is a directory
  now); its 76 retirements were committed with the delete override and its own reason.
- **#760:** the smithy header takes the batch's layout but keeps main's `showsWindowControls`; the Electron launcher
  keeps the DevTools origin flag, the per-run profile and main's `YMIR_WINDOW_BUTTONS`; the home resolver keeps main's
  three functions; the batch's own fix note got its own file
  (`2026-11-14-the-batch-760-is-brought-up-to-current-main.md`).
- **#769:** `pr-watch.sh` keeps main's captured output and gains the `re` import its per-day key needs; the private
  scan keeps main's single deny-list engine, which already replaced the batch's hardcoded patterns.
- **defaults-guard on push:** `systems/skirnir/services/ear.sh`, `systems/snotra/services/ear/snotra-voice.py` and
  `systems/snotra/services/letters/letter-design.py` guessed `~/Documents/ymirhome` as a second home. Each now asks the
  one resolver (`bin/vault/hoard-lib.sh`) and treats an unresolved home as absent.

### Verified

`letter-design.py --self-test` passes; `defaults-guard.sh check` on the three files is clean; the whole gate
(`bin/gates/ci-verify.sh`) runs on the batch before the PR is opened.
