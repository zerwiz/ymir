# 2026-11-20 — three new templates reach every home

**Component:** install · **Files:** `.agents/home-contract.yaml`, `bin/voice/tests/test_mic_check.sh` (exec bit)

The batch gathered on 2026-11-20 shipped three new examples — `worktree-roots.yaml.example` (plan 339.4),
`voice.env.example` (plan 326.0) and `cards.yaml.example` (gimle plan 328) — with no row in the home contract, so a
fresh install would never receive them (`home-contract-guard`, RULES/42). Each now has a `seeded`, optional row naming
its home path and what happens when it is absent. A new test door also lacked its exec bit (RULES/12).

## Appended the same evening

`defaults-guard` refused two new tools that guessed the home (`~/Documents/ymirhome`) instead of resolving it:
`bin/forge/worktree-reap.py` and `bin/records/todo_board.py`. Both now take `$YMIR_HOME` or the one resolver
(`hoard-lib.sh` `ymir_home_root`), and refuse by name when neither answers. Two more doors gained their exec bits
(`bin/voice/kokoro_url.py`, `bin/boards/card_audit.py`).
