# systems/ — the records' shapes and the templates

This shelf holds what a meeting record and a letter **are**, so that the code that enforces them has one written
authority and a reader has one place to look. It holds shapes, not data: a real meeting's record lives in the
operator's home (`$YMIR_HOME/.../meetings/<slug>/record.json`), never in this tree (Rule 04).

| file | what it pins | enforced by |
|---|---|---|
| `the-record.md` | a meeting is a DIRECTORY, and the files inside it | `services/record/snotra-store.sh`, `services/record/snotra-layout.py` |
| `the-letter.md` | one letter per participant, from the record, and the approval bound to its bytes | `services/letters/snotra-letter.sh`, `services/approve/snotra-approve.sh` |
| `the-board.md` | a board is a PROJECTION of the record, made once per place | `services/cron/snotra-board.sh`, `services/cron/snotra-project.sh` |

A file lands here when it is a *shape* — a schema, a template, a contract a door checks. A file does not land here
because it is about a meeting: **code belongs in `services/`, records belong in the home.** When a shape changes,
the code that enforces it changes in the same pass, and this shelf is updated in the same pass or it is the second
place that disagrees.
