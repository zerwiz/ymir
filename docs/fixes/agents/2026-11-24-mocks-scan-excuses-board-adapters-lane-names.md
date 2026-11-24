# 2026-11-24 — the mocks scan excuses the board adapters' lane words

The compliance `mocks` row failed on `bin/boards/board_adapters.py`, which carries a lane synonym table
with the quoted word `"todo"` (Plane and Trello both ship a list called "Todo"). That is data, the same
class as the table in `bin/boards/cardlib.py`, which the scan already excused.

`mocks-scan.sh` now excuses quoted `"todo"` lines in both files. Nothing else in them is excused, so a
real `stub` or `placeholder` there is still caught.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #923
