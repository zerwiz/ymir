# The public tree spelled the operator's domain, in code

**Date:** 2026-11-20 · **Component:** gimle (`bin/gimle/surfaces.py`, the readers) · **Errand:** `surfaces-from-the-home`

## What was wrong

At the operator's word: *"Take the 63 private-scan findings seriously: replace the literal zerwiz.org hostnames in
the repo with configuration read from the home, starting with bin/gimle/desk.py and systems/skirnir, and re-run the
scan to show the count falling."*

Measured in the tree on `main`: thirteen occurrences of his domain in code, an example env file and test fixtures —
a service default in `systems/skirnir/services/learn-site.sh`, a homepage constant in
`systems/snotra/services/letters/letter-design.py`, a hall URL in `apps/hlidskjalf`, a classification in
`tools/calendar/reader.mjs`, a bridge example and three test fixtures. RULES/04 says the public tree never names
the operator: a **shape**, never a value.

`bin/gimle/desk.py` was already clean — it reads its tiles from the home (measured: zero occurrences), so the plan's
starting point was already done.

## What was built

One reader, over the registry the house already keeps:

**`bin/gimle/surfaces.py`** asks `<home>/hodd/identity/services.yaml` — the same file the tunnel round reads, one
`public_url` per service — and answers `--get <id>`, `--list` or `--json`. A service that declares nothing is
**exit 3 and named**; a home with no registry at all is **exit 2**; nothing is ever invented, because a default
that is a hostname is exactly the leak being removed.

The five code sites now ask it:

| file | before | now |
|---|---|---|
| `systems/skirnir/services/learn-site.sh` | a literal default URL | argument → the home's own config → `homepage` in the registry; no address, no run, with the reason |
| `systems/snotra/services/letters/letter-design.py` | a homepage constant | the letter's own field → `YMIR_HOMEPAGE_URL` → the home's settings → `homepage` in the registry → **no link at all** |
| `apps/hlidskjalf/src/data/metadata.ts` | a public hall URL | `VITE_HALL_URL`, and without it the door is not offered |
| `tools/calendar/reader.mjs` | classification by hostname | `YMIR_PING_HOST` (or the host of `YMIR_PING_URL`), and no address means no classification |
| `apps/hlidskjalf/electron/main.cjs` | a comment naming a host | a comment naming none |

The example env file now uses an invented host, and three test fixtures name `example.org` — the law's own example.

## The proof

```
$ python3 bin/gimle/tests/test_surfaces.py
  ok   a declared service answers with its url
  ok   a trailing slash is trimmed, so callers join safely
  ok   a service that declares nothing is exit 3 and is named
  ok   an unknown service is exit 3, never a guess
  ok   the list carries every declared surface and no empty one
  ok   the json map answers a program
  ok   no registry at all is exit 2, not an empty answer
surfaces: 7 passed, 0 failed
```

and the count, which is what was asked for:

```
                                     origin/main   this branch
occurrences of the domain in code          13            0
```

(the engine's own diff-mode verdict on this branch: `0 new findings, verdict CLEAN`)

## What this does not decide

- **The historical fix notes still quote the domain.** They are the record and the law is append-only (RULES/06); a
  note may be corrected by a new entry, never rewritten. If they are to stop being judged, the honest move is a
  reason in the home's allow list — the note is the witness, not a leak of a live credential.
- **`homepage` declares no `public_url` in the operator's registry.** The code now says so instead of inventing one:
  the learn site refuses to run and the made-by line carries no link until he names his own homepage in
  `hodd/identity/services.yaml`. That address is his to write, not mine.
- **The scan judges `origin/main`**, so its own count falls when this merges, not before.

## CHANGE LOG

- 2026-11-20 — written at his word, with the count before and after.
