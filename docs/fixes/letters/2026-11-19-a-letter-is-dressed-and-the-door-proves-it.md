# A letter is dressed, and the door proves it

**Date:** 2026-11-19 · **Component:** the letters door (`systems/snotra/services/letters/`) · **Rules:** 06, 08, 27
**Plan:** 322

## The fault

The door dressed a letter by default — measured on the night's own draft: `multipart/alternative`, a 10,665-byte
`text/html` part, table-based, the Markdown converted, no stray `**`. **Nothing proved it.** `--plain` was an unguarded
escape; `--html FILE` accepted a hand-dressed letter from any copy; and no part of the send path could tell a letter
dressed by the pinned shelf from one that had never been dressed at all. A dressing nobody can prove is a dressing the
next hand at 23:00 will skip.

## What changed

- **`letter-html.py` stamps what it renders.** The first line of every dressed letter is
  `<!-- letter: <template> · sha256:<first 16 of the template file's sum> -->`, so the template is named and the exact
  file that dressed it is fingerprinted.
- **The door writes the evidence into the letter itself** as a header:
  `X-Ymir-Letter: dressed · <template>`, or `X-Ymir-Letter: undressed · <why>`.
- **`--plain` now needs a reason:** `--plain --undressed "<why>"`. Without one the draft is refused, by name.
- **`--html FILE` without a stamp is refused** unless `--undressed "<why>"` says why — a hand-dressed letter from an
  unverified copy no longer passes as a dressed one.
- **`send` checks the bytes that leave.** A draft carrying no `X-Ymir-Letter` line is refused with the plan named, rather
  than sent bare. The check runs **after** the approval gate, so a missing word is still reported as a missing word.

## Proof

```
printf 'Hi Craig,\n\nA test.\n' > /tmp/t.md
bash systems/snotra/services/letters/mail-send.sh draft --to <their address> --subject T --body /tmp/t.md --dry-run
  → eml  /tmp/tmp.YP62glCg0z.eml   (grep it: X-Ymir-Letter: dressed · leemunroe-simple
                                    and <!-- letter: leemunroe-simple · sha256:3e63c44ee9df90b9 -->)

bash systems/snotra/services/letters/mail-send.sh draft ... --plain --dry-run
  → error: a plain letter needs a reason: --plain --undressed "<why>" (plan 322)

python3 systems/snotra/services/letters/letter-html.py --self-test
  → PASS  letter-html: eleven proofs — markers, escaping, footer, refusals
```

The two suites that draft letters were updated to state their reason, and both pass:
`python3 -m unittest bin.mail.tests.test_headers` (12 tests) and
`python3 -m unittest bin.time.snotra.tests.test_outbound_gate`.

## What is not done

`config/letters.yaml` (a letter *kind* choosing its template) is the next phase of plan 322 and is not in this change.
The stamp covers the one renderer the shelf has, `leemunroe-simple`; a template added later gets its own row or no stamp.
