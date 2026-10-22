## snotra · 2026-10-23 — the seat that was never in the room, and the voice that died silently

**His words, all of them measured:** *"he joined.. muted and still talking my mic… the voice in telegram are not
sending voice anymore… all skírnir's functionality are too fragile… we need to make everything functional without
breaking, production ready."*

### 1 · The meeting fault, exactly

```
the order was wrong[3]{step,what_happened,consequence}:
  "the seat joined first","Meet took `getUserMedia` while the page had no wrapper","Meet got the HOST's microphone"
  "the bridge was installed after","`Page.addScriptToEvaluateOnNewDocument` was added, but the document that held the call had already been created","the wrapper never applied to the running call"
  "the state door said in_call=True","it reported a seat","it was a seat with the wrong microphone, and nothing said so"
```

**Fixed by ordering, not by permission:** `snotra-meet.sh seat --port N --url <meet>` now does
**launch about:blank → install the bridge → navigate → join → unmute → verify `in_call && bridge`**, and
returns 4 with a sentence if either half is missing. A seat that would use the host's mic is now a
refusal, not a success.

### 2 · The Telegram fault — one dead service, every voice silent

```
root[2]{fact,evidence}:
  "kokoro-serve was inactive","`systemctl --user is-active` → inactive; `mouth.sh` → 'the synthesiser did not answer'; the adapter logged 'voice note failed' and sent text"
  "because a timer killed it five minutes after every start","`kokoro-idle-stop.timer` stops the server when `now - $RUNTIME/kokoro-last-use > 300`, and **no caller ever touched that stamp**"
```

**Fixed as a lease, not a switch-off** — the timer stays (the card is still returned when the desk is
idle), but two guards keep the voice up:
- every synthesis **touches the stamp** (`tts-lease.sh`, called from `mouth.sh`, the CDP mouth and the seat);
- Skírnir's conversations hold a **15-minute lease** (`~/.local/share/skirnir/tts.lease`), consulted by
  `~/.local/bin/kokoro-idle-stop.sh`, so a meeting with long silences never loses its voice.
- `Restart=always` on `kokoro-serve` as the belt.

**Verified:** the idle-stop, run with a fresh lease, leaves the server **active**; `mouth.sh` produced a
20 KB voice note; `tts-lease.sh status` shows both stamps at 0 s.

### 3 · What the Allfather still has to give

1. **A Google identity for Skírnir** (e.g. `skirnir@way-of.com`), signed once into
   `~/.local/share/skirnir/meet-profile`. Then: his own name, and an **invited** account walks into a Meet
   without the host admitting it (`meet.sh --snotra` already adds `SKIRNIR_MEET_IDENTITY` to every invite).
2. Or, with no account: the host sets **"Who can join: anyone with the link"** on the meeting — the seat
   then joins unnamed-but-named ("Skírnir") without admission, with the bridge as its microphone.

**The lesson, written for the next hand:** *a door that reports success while the wrong device is in the
room is worse than a door that fails* — and an idle timer with a stamp nobody touches is a scheduled
outage.
