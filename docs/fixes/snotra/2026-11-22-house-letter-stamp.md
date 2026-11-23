# 2026-11-22 — a letter in the house design carries the shelf's stamp

Drafting a letter in the house design (a `--body` that opens with a `theme:` header) was refused by `mail-send.sh`: *"this letter carries no dressing stamp — it was not rendered by the shelf (plan 322)"*. The door renders such a letter with `letter-design.py`, but that renderer never wrote the `<!-- letter: … -->` stamp that `letter-html.py` writes, so **every** house-designed letter was refused since plan 322. It now stamps `house-<theme> · sha256:<renderer>`. The self-test's two made-by failures predate this change.
