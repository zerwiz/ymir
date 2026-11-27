# A Trello map of another shape is refused in words

**2026-11-26.** `trello-map.sh --resolve` expects `boards` to be a list. A map in the home held a mapping there, and
the reader crashed with a traceback. It now says the file is not this door's map and exits 2, as it does when there
is no map.

Not changed: a refresh writes to the same path and would replace that file.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #964
