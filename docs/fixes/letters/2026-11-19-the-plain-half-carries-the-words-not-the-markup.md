# The plain half of a letter carries the words, not the markup

**Date:** 2026-11-19 · **Component:** the letters door (`systems/snotra/services/letters/mail-send.sh`) · **Rules:** 06, 27
**Plan:** 322

## The fault

Found by reading the letter that was actually made, not the code. A nine-bold letter went out with **eighteen stray `**`**
in its `text/plain` alternative: the body is written in Markdown for the template's sake, and the door handed the same
Markdown to the plain part. A reader on a text-only client saw `**The board.**` instead of **The board**.

## What changed

The plain half unwraps the emphasis markers before the message is built — `**x**` → `x` — and leaves every other
asterisk alone:

```python
body = re.sub(r"\*\*([^*\n]+)\*\*", r"\1", body)
```

The HTML half is untouched: it is dressed by the template, which turns the same markers into `<strong>`.

## Proof

The same letter, re-drafted:

```
text/html   : 11,307 bytes · nine <strong> · <!-- letter: leemunroe-simple · sha256:… -->
text/plain  :  2,680 bytes · zero stray "**"
X-Ymir-Letter: dressed · leemunroe-simple
```

The section appended to `2026-11-19-a-letter-is-dressed-and-the-door-proves-it.md` carries the same finding; this file is
the range's own note, because a fix note is a file the gate can see.

## What is not done

The plain half is unwrapped of emphasis only — links and headings keep their Markdown, which is deliberate: a text-only
reader can use a bare URL, and a heading's `#` is louder than its absence.
