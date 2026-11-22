# 2026-11-22 — the Mánagandr tool finds its door again

The pi tool `ymir_calendar` answered *"Mánagandr is not answering: Command failed: bash …/bin/time/snotra/calendar-ask.sh"*. The shims under `bin/time/snotra/` were retired (2026-11-17); the door lives at `systems/snotra/services/calendar/calendar-ask.sh`, and it answers (status ok, measured). The extension now calls that path.
