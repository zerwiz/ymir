# 2026-11-22 — branch-current fetches main before it judges

The operator: *"in the gates there should always be a check that we are pushing onto the latest main; sometimes main has moved and we push onto an old main and get conflicts."*

The ward existed and was wired first in pre-push, but it **never fetched**: it measured the branch against the `origin/main` already on disk, so a main that had moved since the last fetch read as *current*, and the PR arrived with conflicts. Now it fetches the base first (`git fetch <remote> <branch>`, 15 s limit, `BRANCH_CURRENT_FETCH_TIMEOUT`); offline, it judges the copy on disk and says so on stderr. `BRANCH_CURRENT_NO_FETCH=1` keeps the old behaviour for a sandbox. Its row now names `base_ref` (fetched or on-disk).

Proved on throwaway repos: with main one commit ahead upstream, the old behaviour passed the push; the new one refuses it (*1 commit(s) behind origin/main*).
