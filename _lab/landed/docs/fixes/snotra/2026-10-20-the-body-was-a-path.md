## snotra · unversioned · 2026-10-20 — the body was a path, not the letter

### What

`mail-send.sh --body FILE` passed the **path string** into the MIME body, so every
"brief" and the feedback email arrived with one line: the path to the Markdown file. The
subject was correct; the letter was missing.

`draft()` now reads the file when `--body` names one, and still accepts a plain string.

### Verified

- The sent test message `1a15a821bdd4beef` had subject *The meeting record — does this
  work for you?* and a body that was only the path (diagnosed from Gmail metadata).
- After the fix, a re-sent test carries the full letter; attachments unchanged.

### Not verified

- Client rendering of `.md` attachments on a phone; no HTML alternative part yet.
