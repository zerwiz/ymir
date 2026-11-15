#!/usr/bin/env python3
"""hermes-rebind.py <home> — keep an agent's Hermes conversations reachable when its home is renamed (plan 275).

WHY. Hermes stores a binding receipt for every API conversation in <home>/state.db (state_meta,
`gateway.api.binding.v1.<session>`), and the receipt records the profile path the conversation was opened under. On
2026-11-13 every Bilskirnir agent refused every message with `profile_mismatch`: their conversations had been opened
while the home was named through a link (/home/<user>/ymir/apps/bilskirnir/data/engines/<agent>, later
~/ymir-runtime/…), and the gateway now names the same folder by its real path. The conversations were intact; only
the name in the receipt was stale.

WHAT. A receipt whose recorded path leads to THIS home (the same folder, by real path) is rebound to the home as it is
named now. A receipt that names another folder is left alone. state.db is copied to state.db.bak-rebind-<stamp> first,
and nothing is written when no receipt needs it. Run it while the agent's gateway is down.

`--check <home>` changes nothing and exits 1 when a receipt is stale.

Prints one line: `rebind <home> <n> receipt(s) rebound` (or `current`, or `no state.db`).
"""
import json
import os
import shutil
import sqlite3
import sys
import time

PREFIX = "gateway.api.binding.v1."


def real(p):
    try:
        return os.path.realpath(p)
    except OSError:
        return p


def main():
    args = sys.argv[1:]
    check = args[:1] == ["--check"]   # --check: exit 1 when a receipt is stale, change nothing
    if check:
        args = args[1:]
    if len(args) != 1:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    home = args[0]
    db = os.path.join(home, "state.db")
    if not os.path.isfile(db):
        print(f"rebind\t{home}\tno state.db")
        return 0
    here = real(home)
    con = sqlite3.connect(db, timeout=10)
    try:
        rows = con.execute("SELECT key, value FROM state_meta WHERE key LIKE ?", (PREFIX + "%",)).fetchall()
        stale = []
        for key, value in rows:
            try:
                receipt = json.loads(value)
            except ValueError:
                continue
            old = receipt.get("profile_id")
            if old and old != home and real(old) == here:
                receipt["profile_id"] = home
                stale.append((json.dumps(receipt), key))
        if not stale:
            print(f"rebind\t{home}\tcurrent")
            return 0
        if check:
            print(f"rebind\t{home}\t{len(stale)} receipt(s) stale")
            return 1
        shutil.copy2(db, f"{db}.bak-rebind-{time.strftime('%Y%m%d-%H%M%S')}")
        with con:
            con.executemany("UPDATE state_meta SET value=? WHERE key=?", stale)
        print(f"rebind\t{home}\t{len(stale)} receipt(s) rebound")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
