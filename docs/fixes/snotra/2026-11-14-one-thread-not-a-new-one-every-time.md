# One thread, not a new one every time

**Date:** 2026-11-14 · **Component:** snotra · **Door:** `systems/snotra/services/letters/mail-send.sh` · **Plan:** 293 (the port), plan 250 §7 (the letters)

## What was wrong

The Allfather: *"we need to update the logic in one thread. we are sending new threads all the time."*

The threading itself was already correct — `--reply-to` reads the message and carries `In-Reply-To`, `References` and the
`threadId`, so a reply joins its conversation in Gmail and in any other client. What was missing was a way to **name** a
thread: the flag wanted a Gmail message id, and no person knows one. So every letter was drafted without it, and every
letter started a new conversation — including the letters whose own first line says *"let us keep everything in one
thread"*.

## What was forged

`--reply-to` now accepts three forms:

| Form | What it means |
|---|---|
| `<message-id>` | the exact message (unchanged) |
| `last:<address>` | the newest message **to or from** that address — `last:<their address>` |
| `q:<search>` | the newest message matching a Gmail search — `q:subject:"Friday synch"` |

The search is resolved with one `GET /users/me/messages?maxResults=1&q=…`, the chosen id is printed on stderr so the
chosen thread is visible in the run, and a search that matches nothing is a refusal with its reason — never a silent new
thread.

## Proved

```
$ mail-send.sh draft --to a partner,craig@way-of.com \
    --reply-to "last:<their address>" --subject "…" --body … --dry-run
thread	last:<their address> -> 1a1dab212fce2bdf
eml	/tmp/tmp.PlclxvquDi.eml
```

A dry run, so nothing was created; the resolved id is the newest message in that thread.

## The rule this makes usable

A group gets **one thread**, and it is opened once, deliberately: the first letter says so, and every following letter to
the same people about the same thing answers inside it. A new thread is for a **new subject or a new audience**, and it
should be a decision, not an accident. The runbook's rule is in `hodd/docs/runbooks/email.md` ("One thread, not many").

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #751
