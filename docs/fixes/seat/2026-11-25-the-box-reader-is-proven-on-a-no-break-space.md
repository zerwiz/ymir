# The box reader is proven on a no-break space

**Component:** seat (plan 369 item 18)

## What was reported

After #942 merged, `bin/seat/herdr-editor.py` still answered `text` for a grey suggestion on a real
pane. The box line there has a NO-BREAK SPACE (U+00A0) after the prompt glyph. The tests used a plain
space.

## What was found

The merged reader was already right. Python's `\s` matches U+00A0, so the marker and the dim check
both cover it. The `text` answer came from a copy of the reader in a checkout that did not yet hold
#942. The pinned runtime and `main` answered `suggestion` for the same pane.

## What changed

Only the test. `bin/seat/tests/test_herdr_editor.sh` gains the box line byte for byte as measured,
plus a no-break space before normal text (`text`) and before nothing (`empty`).

## If it happens again

Check which copy ran. `bin/agents/eindri-send.sh` uses the reader beside itself, so an old checkout
uses an old reader. Run it from the pinned runtime, or bring that checkout up to `main`.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #951
