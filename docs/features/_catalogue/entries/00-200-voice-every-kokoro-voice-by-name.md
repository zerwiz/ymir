---
section: core-install-run-operate
---
| Voice | **Every Kokoro voice, by name** (`bin/voice/voices.sh`) | Lists every voice the engine holds (54 in `voices-v1.0.bin`) with its language, gender and lang code; resolves a name to its id (`eric` → `am_eric`) and refuses a name that fits two; writes the catalogue to the hoard's `identity/voices.yaml`; and speaks a sample in any voice, or writes it to a file with `--to`. Sound is refused while the desk is held. The engine takes the voice with every request, so its configured voice stays a default | [docs/features/every-kokoro-voice.md](docs/features/every-kokoro-voice.md) |
