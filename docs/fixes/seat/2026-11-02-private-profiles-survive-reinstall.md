# Seat profiles survive reinstall

`seat-identity.sh` now resolves private home profiles before distro profiles for
`--file`, install, render and check. A missing profile refuses installation
without replacing the existing seat file. Check detects profile drift as well
as primary/host drift. Roster strings are passed as Python arguments.

Native Windows hostname probing no longer uses `-s`. Python is selected by
successfully importing PyYAML, with an explicit `YMIR_PYTHON` override that fails
closed. Git Bash paths exported to native Python are converted with cygpath.

Evidence: `tests/test_seat_identity.sh` covers private profile reinstall/render,
missing-profile preservation and interpreter refusal alongside the original
seat tests. Native Windows read-only check also exercised the real profile.
