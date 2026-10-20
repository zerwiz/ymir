## snotra · unversioned · 2026-10-20 — one brief, one draft

### What

`bin/time/snotra/snotra-dispatch.sh` prepares **one Gmail draft per participant**
from `briefs/<person>.md`, stores the ids in `<meeting>/dispatch.json`, and sends only
on `send`. It replaces the sed extraction of the draft id with field parsing, which had
silently skipped one recipient.

### Verified

- Synteon pilot: 4 briefs, **4 drafts prepared** (Reygan, Isabella, Craig, Lars-Josef);
  none sent.
- The manual draft path was proven separately with `mail-send.sh draft`.

### Not verified

- No send was executed; approval is the Allfather's.
