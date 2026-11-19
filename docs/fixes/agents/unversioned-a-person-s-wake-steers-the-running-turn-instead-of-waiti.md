## agents · unversioned · 2026-11-19 — a person's wake steers the running turn instead of waiting for its end

### Why
Plan 328 step 5, the delivery gap. The pi arm extension (.pi/extensions/gna-pi-watch.ts) delivered every watcher wake as deliverAs followUp, which waits until the running turn has finished all its tools, so a spoken todo sat unseen behind a long turn while the queue already held it. Before delivering, the extension now asks the drain's own read-only verb (saga-wake-drain.sh classes, so no second classifier lives in the extension). When a voice or an ask is waiting it delivers as deliverAs steer, which the harness hands over after the current tool calls rather than after the whole turn, names the shape in the wake ('people first — voice n · ask n · report n'), and raises a window notification through the session's ui.notify (captured at session_start). Reports alone still wait for the turn boundary as before. Proved: the classes verb it reads (the test above) and a clean type-check of the changed lines. NOT proved: a live steer in a real pi window mid-turn — that needs the arm holder's own session.

### Files
- `.pi/extensions/gna-pi-watch.ts`