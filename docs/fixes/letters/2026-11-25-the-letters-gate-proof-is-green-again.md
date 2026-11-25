# The letters-gate proof is green again

**Date:** 2026-11-25 · **Component:** the letters gate's proofs (`bin/time/snotra/tests/test_outbound_gate.py`) · **Rules:** 06
**Plan:** 375 (found while measuring Part B), 322, 231

## The fault

The proof that the letters gate is the only way mail leaves had been red on `main` for eight days, and nothing noticed.
It failed **12 of 16**.

The cause was the commit that retired the Snotra shims, `ca6faff37` (2026-11-17). It deleted
`bin/time/snotra/mail-send.sh`, `calendar-invite.sh` and `snotra-approve.sh`, but the test still ran them. Each mail
and calendar proof ran `bash <missing file>`, got exit `127`, and failed without judging the gate at all.

A thirteenth fault was hidden behind the first twelve. Once the test was pointed at the real doors, it passed **15 of
16**. The proof that an approved draft sends exactly once was refused by the gate itself:

```
error: send refused for draft r-2 — it carries no X-Ymir-Letter line, so nobody can say it was dressed (plan 322)
```

The gate was right. Since plan 322, `send` refuses a draft with no dressing stamp, but the test puts its stand-in drafts
into the fake Gmail API by hand, without the stamp the door writes when it drafts.

## What changed

- `MAIL`, `CAL` and `APPROVE` now name the real doors under `systems/snotra/services/` (letters, calendar, approve).
  `MAIL_REAL` and `CAL_REAL` are kept as the same paths, so the proofs that read the door's own text are unchanged.
- The hand-made drafts in `test_2` and `test_3` carry
  `X-Ymir-Letter: undressed · a test note needs no typeface (plan 322)`. That is the exact line the door stamps on a
  deliberate plain letter.
  `test_1` keeps its unstamped draft: an unapproved draft is refused as `NOT APPROVED` before the stamp is read.

No door was changed. The gate, the approval records, the hash binding and the spending are the shipping ones.

## Proof

```
python3 bin/time/snotra/tests/test_outbound_gate.py
Ran 16 tests in 93.784s
OK
```

Before this change, on `origin/main` at `c8c4a6e3f`, the same command printed `FAILED (failures=12)`.

## What is still owed

No gate runs this test, which is why it could stay red for eight days. The same is true of `bin/mail/connect.sh
--self-test` and `bin/mail/tests/test_gna.py`: none of them is listed in `bin/gates/checks.d/`.

Wiring the mail and letters proofs into the gate suite is new gate behaviour. So it is left as a separate decision, not
slipped into this repair.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #945
