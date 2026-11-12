## voice · 2026-11-12 — a hold names the seat and charter, and the helm check reads the hold

### Why
`rodd-arm.sh hold` wrote the sidecar as `role=rodd session=N` into the home's state dir, which is not always the dir the arm lease names. It also left out the seat and the charter. The lease then carried no role, and Eir's `roddhelm` row read "the lease names role 'unknown'".

Now the hold reads the seat and charter from the roster (the same row the holder gate checks), writes `role= session= seat= charter=` and puts the sidecar in the state dir the lease names when a lease exists. `rodd-helm.sh --check` falls back to the sidecar when the lease has no role, but only when the sidecar's session is the lease's session; a sidecar from another session is ignored.

### Files
- `bin/voice/rodd-arm.sh`
- `bin/voice/rodd-helm.sh`
- `bin/voice/tests/test_rodd_arm.sh`
- `bin/voice/tests/test_rodd_helm.sh`
