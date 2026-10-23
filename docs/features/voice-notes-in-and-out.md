# Voice notes — speaking to Ymir and hearing it answer

**What it is.** You can send Ymir a voice note on Telegram instead of typing, and ask for the answer
back as speech. Your voice is transcribed by the house's own ear (Whisper, on this machine) and the
reply is spoken by its own mouth (Kokoro). Nothing leaves the box.

**What you need.** A Telegram chat paired with Ymir — that is all. The models are already installed;
the mouth is started on demand and lowered again after five quiet minutes to give the graphics card
back.

**The commands.** There are none to learn: send a voice note, and Ymir hears it. To hear the answer,
send a voice note (the reply mirrors your voice) or press the key that speaks the selection on the
desktop. On the desktop, F10 reads the current selection aloud and F9 holds the microphone.

If you need to raise the voice by hand after a long silence:

```
bin/assistant/voice.sh test          # say a line out loud
systemctl --user status kokoro-serve # is the mouth up?
```

**Limits.** The ear is English (`small.en`) and every note is transcribed locally, so a noisy room
costs accuracy. The mouth speaks in a fixed voice; change it with `~/.local/bin/kokoro-voice`.
Nothing from your voice is sent anywhere, and nothing is kept after the transcript is written.

**If it does not work.** If you get text back instead of a voice, the mouth could not be raised: check
`systemctl --user status kokoro-serve` — it gives the card back after five idle minutes and is raised
again by the next voice note or by the command above. If your note comes back empty, the ear could not
reach its model: run `bin/assistant/ear.sh <file>` by hand and read the error it prints.
