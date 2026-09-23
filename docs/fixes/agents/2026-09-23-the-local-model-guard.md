## agents · unversioned · 2026-09-23 — the local-model guard: the law is now enforced at every seat road

### Why
- **The one-local-model law was built as a tool and wired into nothing.**
  `bin/local-model-lock.sh` exists — its own header: *"only one local inference
  is active per host"* — and **no seat road called it**:

  ```
  herdr-run.sh        0 references
  pi-seat.sh          0
  eindri-start.sh     0
  ```

  So three agents (`bragi`, `snotra`, `huginn`) were inferring against one rail
  at once, on a machine whose law is one at a time. The Allfather caught it, not
  the code.
- **A new seat road repeated the mistake.** `bin/research-round.sh` was written
  with no guard either — a fourth road, the same omission.
- **The lock's own interface did not fit a seat.** It wraps a *command* in
  `flock`, which is right for a one-shot inference and awkward for a long-lived
  herdr pane. What a seat needs is not "wait for the lock" but "refuse if the
  host is at capacity".

### Fix
- **`bin/local-model-lock.sh`** gains a **`check`** verb: it counts the seats
  currently inferring locally and exits **0** when a slot is free, **3** when the
  host is at capacity (`local_concurrency`, default 1).
- **A detection trap, found live.** The first version read the pane with
  `herdr agent read <agent> --lines 6`. That returns **empty output** — the
  option is not honoured — so the guard reported `used=0` and waved every seat
  through. Two further facts settled it: the model marker sits at the far right
  of the status line where a narrow pane can truncate it, and `pi` carries no
  `--model` in its process args, so `/proc` cannot answer either. The guard now
  reads the **whole pane** and matches the provider name anywhere in it —
  verified: a seat on `llama-swap` yields two matches in the full read.
- **Every seat road now calls it** — `bin/herdr-run.sh` (via a new
  `local_model_guard()` beside `seat_guard()`), `bin/pi-seat.sh`, and the new
  `bin/research-round.sh`. A local seat is refused with exit 3 and a plain
  instruction: wait, or use a remote/online model.

### Verification
- **Refusal, live:** with one local seat running, the lock reported
  `"busy",1,1,…` (exit 3), `research-round.sh` exited **3**, `pi-seat.sh` **1**
  (its own guard), `herdr-run.sh` **1**.
- **Clearance, live:** closing the seat made the lock report `"free",1,0,"go"`
  (exit 0).
- **A real dispatch through the fixed road:** `research-round.sh` seated Huginn
  on `llama-swap/qwen3.6-35b-a3b@q2_k_xl`, armed `watch-huginn`, and the guard
  then reported `"busy",1,1` — so a second local seat could not start.
- `bash -n` clean on all four scripts.

### Files
- `bin/local-model-lock.sh`
- `bin/herdr-run.sh`
- `bin/pi-seat.sh`
- `bin/research-round.sh`
