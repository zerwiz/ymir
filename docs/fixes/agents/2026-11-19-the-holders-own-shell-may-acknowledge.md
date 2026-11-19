# The holder's own shell may acknowledge its queue

**2026-11-19.** With the arm held by session 477836, `saga-wake-drain.sh ack` refused:

> error: the arm is held by session 477836; this queue is its to acknowledge, not yours

The ownership test used `lock owned --shell-pid $$`, which judges the **shell**, so a tool run by the
holder — the ordinary way the helm drains its own queue — was refused and needed the loud override
`YMIR_ACK_ANY=1`. Measured: 26 pending wakes sat from 12:30 to 18:08 for exactly this reason.

The test now also accepts the case where the **session** that holds the lock is this shell's session, so
the holder acknowledges from any of its children. Rödd and Bilskirnir, which ask through the same door,
get an answer instead of a refusal.

Proved by: a drain and ack from the holding session with no override, and a refusal still recorded for a
stranger's session.
