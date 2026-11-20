## agents · 2026-10-22 — Brokk hears voice notes too, through the house's own ear

**His question:** *"can brokk also take sound messages and lissen to them in telegram?"* The bridge already
had the surface — `inboundHandlers` in `telegram.json`, matched on `mime: "audio/*"` — and the house already
had the ear. Nothing new was needed but the wire.

```
wired[3]{piece,value,note}:
  "inbound","`{\"mime\": \"audio/*\", \"template\": [\"bash\", \".../bin/assistant/ear.sh\", \"--file={file}\"]}`","pi-telegram downloads the note and hands it to the SAME ear Snotra and Skírnir use — one transcription path, not three"
  "outbound","`{\"type\": \"voice\", \"template\": [\"bash\", \".../mouth.sh\", \"{text}\", \"{ogg}\"], \"output\": \"ogg\"}`","a voice reply is Kokoro in the switcher's voice, encoded OGG/Opus by the same mouth the assistant uses"
  "policy","`voice.replyMode: \"mirror\"`","a voice note in gets a voice note back; typed words still get typed words"
```

**`ear.sh` gained `--file=`** so the bridge's shell-free template can call it (`--file={file}`); the
positional form still works for every other caller.

**Measured:** `ear.sh --file=/tmp/note.ogg` → *"Skírnir, what is OptiCat? The inspection is on Friday."* — the
exact shape the handler template passes.

**What the operator must do once:** `/telegram-connect` in the TUI, because `telegram.json` is read at
connect time — a config change without a reconnect is a config that never loaded.
