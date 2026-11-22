# 2026-11-22 — the home seed no longer trips the NSR path gate

The nightly `nsr-compliance` job failed every night (`check_paths`: *ABSOLUTE PATH: ./bin/engine/home-seed.sh -> /hodd/life*). The two lines were the anchored `.gitignore` entries for the plan 331.7 compatibility links, written inside a heredoc, where a line starting with `/` reads as an absolute path to the gate. They are now appended by `printf` after the heredoc: the seeded `.gitignore` still carries `/hodd/life` and `/hodd/state` (measured on a fresh seed), and the gate passes.

## CHANGE LOG

- 2026-11-21 — review-mend: added missing heading for #890
