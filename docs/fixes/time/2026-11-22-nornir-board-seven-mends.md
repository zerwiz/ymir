# Nornir board: seven mends

The fleet's scheduled-jobs board showed seven failing items. Six were real faults or false alarms; one was a reach problem.

| # | Fault | Mend |
|---|---|---|
| 1 | The clock retired when the session lock was missing for one read (around runtime flips). | `bin/time/nornir-cron-start.sh` waits `BROKK_CRON_LOCK_GRACE` seconds (default 600), re-checking every 15, before retiring. A retire writes `state/.cron-retired` and sends a notice. |
| 2 | A door the machine does not run exited 3 and showed as FAIL. | `warden_require_door` callers exit `WARDEN_RC_NOT_HERE` (78). The clock logs `cron SKIP not-here`; the board shows "skip (not this machine's door)". Real failures keep their codes. |
| 3 | Weekly rows listed twice. | The home `cron.yaml` declares them twice. The board now dedupes by gate, days, time and command. The clock already stamps by command, so nothing fired twice. |
| 4 | The daily briefing failed on aged mail drafts. | It exits 0 and adds a to-do card for the Allfather. |
| 5 | `nsr-compliance` failed `check_paths`. | Fixed by #890 (home seed). The heart's `check_paths` passes now; a pin older than that commit needs a flip. |
| 6 | `trello-due.sh` imported a file that does not exist. | It now reads `systems/snotra/services/cron/snotra-trello.py`. |
| 7 | Unreachable machines mixed into failures. | `bin/time/nornir-fleet.py` shows "offline (last seen …)" or "no road". |

> [!IMPORTANT]
> The operator must fill in: the two machines that have no user or address (named in the home ledger `state/eir/ledger.jsonl`); and say whether `whynot` and `aegir` are off. A host row may carry `"offline": true`. The second copy of the weekly rows in the home `cron.yaml` can be deleted.

Test: `bin/time/tests/test_nornir_mend.sh`.

## CHANGE LOG

- 2026-11-22 — review-mend: added missing heading for #907
