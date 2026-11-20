# The seated engine refreshes — a stale unit no longer survives a fix

**Dated:** 2026-10-01 · **Component:** snotra · **Branch:** `eindri/snotra-ear-seat-refresh`
**Corrects:** [`2026-10-01-the-ear-follows-the-gate.md`](./2026-10-01-the-ear-follows-the-gate.md) (PR #258, `e904aa1`)

## The defect, in one line

```bash
[ -f "$dst" ] && return 0        # ← ear_seat_unit, as shipped in #258
```

It tested whether the seated engine unit **existed**, not whether it was **right**.
So it seeded a seat that had no unit, and left every seat seated by an earlier
version of the tree holding that version's unit indefinitely.

## Why that is the worst possible direction to be wrong in

The unit an earlier tree version shipped is the one carrying:

```ini
[Install]
WantedBy=ymir.target
```

And that section is the whole point of the exercise. It can put the engine back
into `ymir.target` with a single `systemctl --user enable` — by the next
`fleet-ensure`, by a boot-time re-enable, or by a hand.

```
who_benefits[2]{seat,outcome_under_the_seeded_only_fix}:
  "never had the unit","freed — the fix works on it"
  "always had the unit","STILL PINNED — and it is the one holding [Install]"
```

So the fix would have freed the seats that were never provisioned and left pinned
every seat that **always** had the unit — which is the population that actually
had the 900 MiB problem. The seats that need the fix most are the seats it would
have skipped.

Found on heimdall within a minute of PR #258 landing: the seated unit at
`~/.config/systemd/user/snotra-ear.service` was dated **Sep 27**, still carried
`[Install]` / `WantedBy=ymir.target`, and the newly-hooked watch would have started
it forever without ever replacing it.

## The correction

Compare, do not test for existence. `cmp -s` the seated copy against the tree's;
refresh when they differ, return quietly when they match.

```
seat[3]{state_of_seated_copy,before,after}
  "absent","seeded from the tree","the tree's copy — 0 [Install] sections"
  "STALE (an earlier tree version)","left pinned to the old unit","REFRESHED — [Install] 1 -> 0, byte-identical to the tree"
  "current","left alone","left alone — no copy, no daemon-reload, no churn"
```

**A hand-written unit is not refused.** If neither tree carries a template, the
watch warns and leaves the seat's own copy standing. Silently replacing a unit a
hand made is the same sin as the one being fixed — an engine nobody can account for
— so the watch says so out loud instead and lets the Allfather decide.

## Verified — by probe, not by assertion

`ear_seat_unit` was extracted and run against a temporary `$HOME` with `systemctl`
stubbed, so the file behaviour is observed directly:

| pass | seated copy | rc | observed |
|---|---|---|---|
| 1 | stale, carrying `[Install] WantedBy=ymir.target` | 0 | refreshed — **`[Install]` sections 1 → 0**, byte-identical to the tree |
| 2 | already the tree's copy | 0 | silent; no copy, no `daemon-reload` |
| 3 | no template in either tree | 0 | the seat's own copy **stands**, with a warning |

Also: `bash -n` clean · 12/12 `snotra-iscall` assertions ·
`compliance-check.sh` 15 PASS / 1 expected NOTE (`assets: governed assets current`
PASS) · secret scan clean on the staged diff.

**Still not verified, and unchanged from the note it corrects:** the
`ear_up` → `ear_down` round trip on a real meeting. The hooks are placed and read
correctly; they have not been run against a live call. First thing to watch on the
next real meeting.

## The lesson, one layer deeper than the last note's

The first fix modelled a seat as *provisioned or not*. It is neither: a seat is
provisioned **to some version**, and the versions are exactly where a stale
`[Install]` hides — invisible, because a file that exists looks like a file that
works.

**Idempotence is not "do nothing if the file exists." It is "make the file be what
it should be."** A guard that skips work because the artefact is present is not a
guard; it is an assumption wearing one.
