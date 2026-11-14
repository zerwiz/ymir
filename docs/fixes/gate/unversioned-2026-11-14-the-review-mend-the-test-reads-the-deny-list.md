## gate · unversioned · 2026-11-14 — the review mend: the test reads the deny list, the note stops quoting, and the loader that was left behind

### Why

The helm's review of `eindri/agnostic-code` (head `52f16423`) found the sweep still carrying, in four
added lines, the very names it removes. It also found — and this is the serious one — that the previous
commit had staged only `.agents/` and the note, so the branch shipped the new home allow-list **without**
the loader that reads it.

### What

- **The test no longer spells what it refuses.** `bin/vault/tests/test_home_resolvers.sh` proved that
  `hoard-lib.sh` names neither the operator's realm nor the heart's host by writing both words in the
  test. It now reads them from his deny list (`$YMIR_HOME/hodd/identity/public-deny.txt`, or
  `$YMIR_DENY_LIST`) — the same door `bin/gates/agnostic-audit.sh` reads — and greps the library for
  every entry. A machine with no list says so aloud and skips, because a test that silently checks
  nothing is a green that means nothing.
- **Proved to bite, not to pass.** A deny file naming one word the library *does* contain makes the
  test fail by name: `FAIL hoard-lib.sh names 1 word(s) from the home's deny list` (10 passed, 1
  failed). With the real list: `names not one word`.
- **The note stopped reprinting what it removed.** `<the heart's host>`, `<the house's domain>`,
  `/home/<user>`, `<the realm>` — a fix note that quotes the old values puts them back in the tree.
- **The loader ships.** `bin/gates/guards/ndalib.py` (`load_allow` merges the repository's generic
  words with `$YMIR_HOME/config/nda-allow.yaml`) and `bin/gates/tests/test_nda_guard.sh` (three new
  proofs) were left unstaged by the previous commit. Both are here.
- **The file-name question, answered.** `bin/host/heimdall-ssh-keys.sh` is an EXISTING file — the lore
  ward's own, from `8d2a24e8` — not a new door and not a rename. Only its portability comment changed,
  to name the two proven platforms by role instead of by host.

### Files

- `bin/vault/tests/test_home_resolvers.sh`, `bin/gates/guards/ndalib.py`,
  `bin/gates/tests/test_nda_guard.sh`
- `docs/fixes/gate/unversioned-2026-11-14-the-operator-s-values-leave-the-public-tree.md` (the table's
  two quoted defaults and two prose paths, plus the note that the ssh-keys door is an existing file)

### Proof

- `bash bin/vault/tests/test_home_resolvers.sh` — 11/11, its last row now *"names not one word from the
  home's deny list"*; and the planted-word run above proves the row can fail.
- `bash bin/gates/tests/test_nda_guard.sh` — 37/37.
- `bash bin/gates/guards/nda-guard.sh` — exit 0 on this tree (146 inherited lines owed a scrub; a new
  line naming a person is still refused).
- `bash bin/gates/guards.sh` — 0 FAIL on the push; the two INHERITED findings (weave index drift,
  cron's missing scripts) name files this branch does not touch.
- `grep -nEi '<the token set>' docs/fixes/gate/unversioned-2026-11-14-…md bin/vault/tests/…` — nothing.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
