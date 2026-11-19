# The ack door has its test

**2026-11-19**, plan 325 step 3. The note before this one
(`2026-11-19-the-holders-own-shell-may-acknowledge.md`) says the holder now acknowledges its own queue, and a
stranger's session is still refused. It said "proved by", but the repository held no test, so nothing would catch it
coming undone.

`bin/time/tests/test_ack_holder.sh` is that test. It is fenced: `HOME`, the state dir and the machine state dir all
point into a throwaway folder, and two `sleep` processes stand in for the holder's session and a stranger's
(`BROKK_SESSION_PID`, the harness's own door).

It checks four things:

- the stranger is refused with exit 3;
- the stranger leaves the queue whole;
- the holder acknowledges with exit 0 and no `YMIR_ACK_ANY`;
- the holder consumes the wake that was presented.

Measured: **4 passed, 0 failed** on the fixed door. On the door as it stood at `3354412b1` it scores **2 passed, 2
failed**, refusing the holder with *"the arm is held by session …; this queue is its to acknowledge, not yours"*. So
the test bites on exactly the fault the fix mends.
