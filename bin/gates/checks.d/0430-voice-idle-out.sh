#!/usr/bin/env bash
# voice-idle-out
gate voice-idle-out "the voice engine lets the card go after a quiet window, and never cuts a call" \
     bash "$ROOT/bin/voice/tests/test_voice_idle.sh"
