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
- **The verdict store guessed the home too.** `bin/forge/merge-verdict.sh` and `bin/gates/gate-verdict.sh` (from
  #747, already on `main`) read `${YMIR_HOME:-$HOME/Documents/ymirhome}`, which defaults-guard refuses. Both now ask
  the resolver and refuse when no home resolves.
- **queue-warden kept a dead twin.** The merge left main's old `run_one` (merge main in, `git add -A`,
  `--no-verify`, a skipped fixes guard, a hardcoded remote) beside the batch's `recut_one`/`merge_one`, which already
  carry #747's verdict gate. Nothing called it; `test_queue_warden.sh` refused it five times. It is removed:
  47 pass, 0 fail.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #771
