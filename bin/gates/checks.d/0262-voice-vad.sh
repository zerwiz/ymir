#!/usr/bin/env bash
# voice-vad
gate voice-vad   "the detector weights are fetched and checksummed, never committed, and both doors name one file (plan 288)" \
               bash "$ROOT/bin/voice/tests/test_voice_vad_model.sh"
