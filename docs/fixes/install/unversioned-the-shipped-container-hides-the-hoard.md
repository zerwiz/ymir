## install · unversioned · 2026-11-16 — the shipped container hides the hoard

### Files
- `deploy/quadlet/ymir.container` — a read-only tmpfs over `hodd/secrets`, and `%h` on both sides of
  every home mount
- `deploy/compose/compose.yaml` — the ready-made mask beside the volumes, for the day a home mount
  is added to that shape
- `deploy/README.md` — the section *The container never holds the vault*, and its CHANGE LOG entry
- `bin/gates/tests/test_container_hides_the_hoard.sh` — the regression test
- `bin/gates/checks.d/0495-container-hides-the-hoard.sh` — the gate that runs it
- `.agents/assets/agents/subsystem-docs.md` — `deploy/**` gets its map row (`bin/records/where.sh`
  answered "no row" for it)
- `bin/gates/guards/fixes-guard.sh` — `deploy/*` maps to the `install` component, so a deploy fix can
  be covered by an install note instead of passing on a technicality

### Why

A collaborator installed a Ymir home from the collaborator pack on 12 November and reviewed every step. His
fifth finding, in his own words on the 15:08 mail: *"The container mount gives the container the
secrets folder — key and encrypted file together. I masked it in my Quadlet; the shipped Quadlet
should do the same."*

He is right, and the fault is one line of a shipped unit. `deploy/quadlet/ymir.container` mounts the
operator's home whole, so the container could read `hodd/secrets/age.key` (the age identity) and
`hodd/secrets/platform.env.age` (the vault it unlocks) in the same breath. With both, the container
decrypts the hoard: the boundary the container exists to provide protected nothing it was built to
protect. Nothing on this seat was exposed by it — the Quadlet is not the shape this machine runs —
but it is the shape a collaborator's machine runs, which is where it was found.

A second fault sat in the same lines. Both home mounts spelled their container side as
`$HOME_SEAT/...`, and **nothing in this repo defines `HOME_SEAT`** — not `deploy/env.example`, not
the README, not the unit. A mount (or a mask) written from an unset variable lands on whatever the
literal string is, so the mask would have hidden nothing on a fresh install. Both sides are now `%h`
(the systemd specifier for the operator's home), which is what the mount always meant: the container
sees the host's home at the same path.

### Fix

An empty, read-only, size-capped tmpfs over the one path that holds the key:

```ini
Volume=%h/Documents/Ymir:%h/Documents/Ymir:Z
Tmpfs=%h/Documents/Ymir/hodd/secrets:size=1m,ro
```

The mask is derived from the mount, not typed beside it: the gate computes
`<home mount's container side>/hodd/secrets` and fails when the two disagree.

**What it costs, stated in the unit and in the README rather than discovered later.** Inside the
container `bin/vault/hodd.sh emit` can no longer decrypt. A service that needs a vault value inside
the container takes it from `ymir.env` (0600, the `EnvironmentFile`), written by the operator. The
mail desk, the Telegram seat and the Nornir jobs read the vault from the host and are unaffected.
The Compose shape mounts only the checkout and so never held the vault; it carries the mask as a
commented template.

### Verified

- `bash bin/gates/tests/test_container_hides_the_hoard.sh` — 6 ok / 0 fail.
- The negative control: deleting the `Tmpfs=` line turns the same test to 3 ok / 3 fail, so the gate
  is not a decorative green.
- The primitive, measured live on this machine (Docker, `alpine/socat` as the probe shell) with a
  fixture home holding `hodd/secrets/age.key`, `hodd/secrets/platform.env.age` and
  `hodd/docs/readme.md`:
  - before the mask — `secrets: [age.key platform.env.age]`, the key readable;
  - after the mask — `secrets: []`, `read the key: cat: can't open '.../age.key': No such file or
    directory`, `docs still read: [readme.md]`.
- `YMIR_ENV=/tmp/probe.env docker compose -f deploy/compose/compose.yaml config` renders: one bind
  mount (the checkout), `tmpfs: [/tmp]`, nothing of the home.
- `bash bin/gates/guards/subsystem-docs-guard.sh` — `"none"` (the new map row names books that
  exist).
- `bash bin/records/where.sh deploy/quadlet/ymir.container` now answers with the layer's row.

### Owed

The live container proof on a **Podman** host, because no Podman exists on this seat and the Quadlet
is a Podman shape:

```bash
quadlet -dryrun -user ~/.config/containers/systemd/ymir.container   # the generator accepts the unit
podman exec ymir ls -A ~/Documents/Ymir/hodd/secrets                # prints nothing
```

Until that runs, the claim "a container started from the shipped setup cannot list `hodd/secrets`"
rests on the shape (proven above) and on the mechanism (proven on Docker above), not on a Podman
container. A gate that reported a green for it would be claiming a proof nobody has run.

### CHANGE LOG

- **2026-11-16** — note written with the fix; the reviewer's item 5 of the 12 November review.
