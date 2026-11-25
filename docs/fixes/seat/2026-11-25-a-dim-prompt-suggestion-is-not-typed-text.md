# A dim prompt suggestion is not typed text

**Component:** seat (plan 369 item 18)

## What was wrong

`bin/agents/eindri-send.sh` refused to send to almost every worker pane, saying the input box
"already holds someone's text". The text was the harness's own grey prompt suggestion. The box line
is `ESC[2m<suggestion>ESC[0m`, SGR 2 (dim), a hint that was never typed. `bin/seat/herdr-editor.py`
read the pane as plain text, lost the colour, and judged the hint as `text`. Measured on four live
panes on 2026-11-25.

## What changed

- `herdr-editor.py` reads the pane with `herdr pane read --format ansi` and tracks SGR 2 per
  character. A box whose only content is dim gets the new verdict `suggestion`. Text in normal colour
  is still `text` and still refuses; a dim hint beside real text is `text`.
- `eindri-send.sh` reads the far pane in ANSI too, and treats `suggestion` like `empty` (it sends; a
  lost line after a send is resent once).
- `test_herdr_editor.sh` gains four ANSI cases: dim suggestion, normal text, dim beside real text,
  empty. The reader passes 12 of 12.

## Proof

Live pane `wBA:p3P` read `text` ("ok, keep going") before and reads `suggestion` after.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #942
