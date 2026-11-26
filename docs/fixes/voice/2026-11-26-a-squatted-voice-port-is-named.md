# A program squatting the voice's port is named

**2026-11-26.** A stray web server held the port the speech engine binds. The engine's unit crash-looped, and every
caller saw only an open port that answered HTTP 501.

`bin/voice/kokoro-lib.sh` now has `kokoro_port_squatter`. It prints the pid and command of any program on the port
that is not the engine. The mouth and Skírnir's smoke test show that line. Nothing is stopped automatically.
