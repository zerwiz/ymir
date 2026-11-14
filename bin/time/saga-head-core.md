FIXED CORE — every worker knows this (plan 275 §04:15/04:20/04:25). This file is the ONLY copy: the head prints it and the seat law (bin/seat/herdr-run.sh) appends it, so it is kept current by the same change that moves a command.
~/ymir is a PUBLIC repo: never a secret, key, name, plan, schedule or client in it (Rule 04); it delivers by PR — branch, pull request, the Allfather seals the merge, never an agent.
$YMIR_HOME (~/Documents/ymirhome) is his PRIVATE repo: plans (svartalfaheim/<realm>/projects/<project>/plans/), memory, identity, secrets (never staged). Edit it only with bin/vault/home-sync.sh begin, then ship "<msg>" <paths> — named paths, never git add -A.
Apps run from the pin ~/ymir-runtime -> releases/<sha>: bin/engine/release.sh build --ref main · flip <sha>. A working tree is not where apps run.
Herdr: herdr agent list · herdr agent read <pane>. Speak to an agent ONLY with bin/agents/eindri-send.sh [--from "<who>"] <pane> "<text>" — every line carries a [from …] stamp, and only [from the Allfather …] is his own word ([from agent …] is the helm or a worker, [from script …] is a program).
The Gná arm: ONE session on each machine holds it — the lock, the wakes, the dispatch. Ask bin/voice/rodd-arm.sh who (this machine) or bin/fleet/arm-send.sh --who (the fleet); reach the holder with bin/voice/rodd-arm.sh tell --from <you> "<text>". A tell is HANDED, not done, until the holder answers.
  A session that does not hold the arm is read-only for spawn, steer, merge and drain, and says so instead of acting. It never takes the helm (rodd-arm.sh hold only takes a vacant one, never steals). The arm is not a microphone: bin/desk/in-call.sh holder names the DESK, not the arm.
Tools: bin/agents/skill-find.sh "<words>" (skills) · bin/records/where.sh <path> (the owner of a path) · bin/model/catalog.sh (models) · bin/gates/fixes.sh list (fix notes).
The desk: while bin/desk/in-call.sh holder prints anything, no app restarts and no sound tests.
Laws: stage named files only (never git add -A) · no AI attribution anywhere · never remove a feature, only the parts named · test in the REAL window through DevTools (YMIR_DEVTOOLS_PORT) on heimdall and, from a release, on nidavellir (ssh nidavellir-t) before calling it done · one fix note per change in docs/fixes/<component>/ · commit on your own branch eindri/<errand> and DO NOT push — the helm gathers one PR.

## CHANGE LOG

- **2026-11-14** — written with plan 275 item 28: one file, printed by the head and appended by the seat law, so no brief repeats it by hand. The head prints every line ABOVE this heading and nothing below it; the history stays here, out of the context it would otherwise spend.
