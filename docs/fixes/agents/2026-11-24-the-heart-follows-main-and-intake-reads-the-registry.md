# The heart can prove main again, intake reads the project registry, and research is shared by seat

Date: 2026-11-24 · Component: agents · Plans 365 and 366 (Huginn H2 and H3)

## What was wrong

- **The heart refused to follow `main`.** Its update loop proved `main` once, the proof failed on `opencode-launcher`, and the loop held with "main is not proven". The spawner saw a running herdr server, chose herdr, and stopped with "herdr is not on PATH", because the herdr binary is in `~/.local/bin` and a systemd unit's PATH does not carry it. A dry run also needed a backend it never uses.
- **Intake had no repositories.** It needed names written by hand, and the operator has many repositories.
- **Research was redone.** Two seats asking the same question each fetched the web, and a collaborator could not read kept answers.

## What changed

- `bin/agents/einherjar-spawn.sh` puts herdr on PATH from the places an installer leaves it, counts a herdr server as a backend only when the binary can be driven, and lets a dry run print its plan with no backend. Proved on the heart itself: the `opencode-launcher` test passes there.
- `ymir work intake` derives its repositories from the project registry in the home (`hodd/identity/projects.yaml`): solo and offline read the repositories cloned on this machine, fleet reads the whole registry. A repository is in the road by having an issue labelled `ymir:work`; no name is written in the repository. `ymir work repos --all` lists them.
- H2: when this machine's kept answers hold nothing, `ymir_research` asks the heart's kept answers itself over ssh, names the seat in the answer, and falls back to the web if the heart says nothing within five seconds. The heart never answers for this machine.
- H3: `ymir_research_find` is a read-only tool that searches kept answers and returns only the ones tagged `shareable`; private research never leaves the machine.
- The Nornir resolver reads a host's `fallback` from the fleet registry (a dark forge defaults to the heart).

Proof: `python3 tests/test_work_road.py`, `python3 tests/test_nornir_status.py`, and `bash bin/gates/tests/test_opencode_launcher.sh` on this machine and on the heart.
