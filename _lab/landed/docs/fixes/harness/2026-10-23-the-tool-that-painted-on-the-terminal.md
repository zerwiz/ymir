# The tool that painted on the terminal, and the fresh pi

**Date:** 2026-10-23 · **Component:** harness (`.pi/extensions`)

## The report

The Allfather: *"what are breaking pi?? a lot of times things breaks the chat interface for the
user. it comes up random texts over the ui from some tool."*

## What the record says

Two faults, found in pi's own records rather than guessed:

```
evidence[3]{record,what_it_says}:
  "~/.pi/agent/pi-tui-crash.log (2026-09-30T16:51:21Z)","Terminal width: 2 · Line 264561 visible width: 3 — the TUI rendered into a 2-column terminal and threw; the screen is left holding an old frame, which is why old tool text reappears fused with the status line"
  "~/.pi/agent/crashes.json","the same width error twice, and setRawMode EIO on a suspended terminal"
  "installed version","pi 1.3.0 — one release behind 1.4.0, whose notes fix exactly this class: terminal modes (mouse tracking, focus reporting, Kitty keyboard, alternate screen) left on when pi exits without teardown, and stacked inline custom() dialogs"
```

## The three fixes

```
fixes[3]{path,was,is}:
  ".pi/extensions/eindri.ts","einherjar-spawn.sh · eindri-send.sh · eindri-acclaim.sh · eindri-control.sh ran with stdio:\"inherit\"","captured into the tool result (head 3,000 chars, the rest named) — a child's tables no longer land on the editor pi owns"
  ".pi/extensions/constellation/index.ts","console.error on every session start","ctx.ui.setStatus(\"constellation\", \"mesh: …\") when there is a UI; the console channel stays for headless runs"
  ".pi/extensions/excalidraw/index.ts","console.error on every session start","ctx.ui.setStatus(\"excalidraw\", …) the same way"
```

And the harness itself: **pi 1.3.0 → 1.4.0** (`npm i -g @earendil-works/pi-coding-agent@1.4.0`).
That release carries the terminal-teardown fix for "pi exits without normal teardown, flooding the
shell with escape sequences" — the same symptom as "random texts over the UI".

## Why stdio:\"inherit\" was the leak

A tool that hands a child our stdio gives the child the terminal pi has taken over. The child draws
wherever its cursor is: over the prompt, over the status line, over the spinner. Pi never sees the
bytes, so nothing in its renderer can repair the damage. The contract is that a tool **returns**
text and pi renders it; the only legitimate inherited-stdio use left is the terminal-editor
suspend in `open-editor.ts`, which stops the TUI first.

## What is verified, and what is not

- `bash bin/seat/valknut-load.sh --check` — PASS (extension tree one home, no duplicate load path).
- `pi --version` — 1.4.0.
- The two extensions and the errand tool were edited in the live (project) tree with no other change.
- **Not verified:** a full session start after the upgrade in this same turn (the running process
  keeps the code it loaded). The next seated session is the proof.
