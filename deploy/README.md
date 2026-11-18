# Deploy — the agnostic deployment layer

Ymir's **core is host-agnostic**: one portable runtime, no provider assumptions.
A *deployment* is a thin host-managed layer **over** that core — never inside it.
This directory ships the neutral contract and example layers; adopt whichever
matches the host.

## The neutral contract

Any deployment must provide exactly these; nothing more is expected of it:

```
contract[6]{needs,example}:
  "the checkout","the Ymir repo available at a path (bind-mount or baked image)"
  "a runtime","git · python3 · curl · bun (the core runs on any of Docker/Podman/bare)"
  "env","HLIDSKJALF_AUTH + realm/env from .env.local (never inline, never committed)"
  "persistent state","state/, workspace/, .agents/memory/, agents/, apps/*/dist — writable and durable"
  "ports","SPA :38888 · gate :38889 · Smíðja visualizer :54370 (5-digit ≤ 65535, env-driven: HLIDSKJALF_PORT · HLIDSKJALF_API_PORT · SMIDJA_VIZ_API_PORT) · well :4602 · Bifrost :4603 internal"
  "a raise command","scripts/start.sh (lower with scripts/stop.sh)"
```

The engine is resolved by the core (`bin/fleet/ymir-platform.sh` → `ymir_container_engine`),
not by the deployment. A layer never names `docker` or `podman`.

## Shapes (pick one; they are equivalent)

| Shape | When | Path |
|---|---|---|
| **Bare** | a dedicated box, or a container you already manage | `scripts/start.sh` directly |
| **Quadlet** (Podman + systemd) | a Fedora/RHEL host running rootless Podman | `deploy/quadlet/ymir.container` |
| **Compose** (Docker or `podman-compose`) | a Docker host or mixed fleet | `deploy/compose/compose.yaml` |

```
# bare
scripts/start.sh

# quadlet (rootless, per-user)
cp deploy/quadlet/ymir.container ~/.config/containers/systemd/
systemctl --user daemon-reload && systemctl --user start ymir.service

# compose
cp deploy/env.example .env   # then edit; never commit
docker compose -f deploy/compose/compose.yaml up -d
# or: podman-compose -f deploy/compose/compose.yaml up -d
```

## Baked image (optional)

Prefer an immutable release to a bind-mounted checkout? Build `deploy/Containerfile`
with either engine and point the Quadlet/Compose `Image=` at your tag:

```bash
podman build -f deploy/Containerfile -t ymir:0.1.0 .   # or: docker build …
```

Durable state still needs volumes (`state/`, `workspace/`, `.agents/memory/`,
`agents/`, `apps/*/dist`) — the image bakes only code. Validated: the Quadlet unit
passes Podman's own generator (`/usr/libexec/podman/quadlet -dryrun -user`).

## Isolation on a **shared** server

When Ymir shares a machine with other services, the **container is the boundary**:
rootless Podman gives Ymir its own mount namespace, user namespace, cgroup limits,
SELinux labels, and no host root. That is what stops Ymir from disturbing the rest
of the box — not bwrap.

The confinement layers, from the outside in:

```
isolation[3]{layer,boundary,when}:
  "Host ↔ Ymir","the container (Quadlet/Compose): rootless, cap-drop ALL, no-new-privileges, :Z labels","always, on a shared host"
  "Ymir ↔ agent command","bwrap — scopes a single model-generated command to one worktree","only when the probe passes; never required"
  "Ymir ↔ untrusted code","Utgard (a nested container) or the container itself","for code the agent writes and runs"
```

### bwrap inside the Quadlet

bwrap needs to create a **nested user namespace**. Rootless Podman containers are
already inside a user namespace, and many hardened configs disallow nesting — then
bwrap fails with `Creating new namespace failed: Operation not permitted`.

So: **do not force it.** The core probes with `bin/engine/ymir-isolation.sh probe` and falls
back to the container boundary when nested namespaces are unavailable. If you want
bwrap *inside* the Quadlet, the container must opt in (and that loosens it — weigh
it against the boundary you gain):

```ini
# deploy/quadlet/ymir.container — enable ONLY if you want bwrap inside
UserNS=keep-id
AddCapability=SYS_ADMIN
# and, where the host's seccomp profile blocks clone3/unshare:
# SecurityOpt=seccomp=unconfined
```

The recommended posture on a shared server is **no bwrap inside**: trust the
rootless container as the wall, and run untrusted code in Utgard. Enable the block
above only when you have a specific need to confine individual commands and accept
the looser container.

## The container never holds the vault

A container that mounts the operator's home can read two files that must never be read together:
`hodd/secrets/age.key` (the age identity) and `hodd/secrets/platform.env.age` (the vault it
unlocks). With both, the container decrypts the hoard, and the boundary the container exists to
provide protects nothing.

So every shape here that mounts the home masks that one path with an empty, read-only tmpfs:

```ini
# deploy/quadlet/ymir.container
Volume=%h/Documents/Ymir:%h/Documents/Ymir:Z
Tmpfs=%h/Documents/Ymir/hodd/secrets:size=1m,ro
```

**What it costs, plainly.** Inside the container `bin/vault/hodd.sh emit` can no longer decrypt.
That is the point, and it has one consequence to plan for: a service that needs a vault value
*inside* the container takes it from `ymir.env` — the `EnvironmentFile` above, mode 0600, written
by the operator's own hand. The sealed vault stays on the host, where its key already lives. The
mail desk, the Telegram seat and the Nornir jobs read the vault from the host and are unaffected.

The Compose shape mounts only the checkout, so it never holds the vault; the ready-made mask sits
commented beside the volumes for the day someone adds a home mount. The gate
`bin/gates/checks.d/0495-container-hides-the-hoard.sh` fails a shipped shape that mounts the home
and leaves `hodd/secrets` readable, and fails if the mask and the mount drift apart.

> [!IMPORTANT]
> The mask is proven by reading the shipped shape on any host. The live proof — raise the container,
> `ls hodd/secrets` inside it, get nothing — is owed on a host with Podman:
> `quadlet -dryrun -user ~/.config/containers/systemd/ymir.container` then
> `podman exec ymir ls -A /home/<you>/Documents/Ymir/hodd/secrets`.

## Portability (Rule 05)

A layer is gated on its host and reports a clean skip elsewhere — the Quadlet layer
is a no-op on macOS, and Compose is a no-op on a bare box. When the core changes,
every layer here is updated in the same change.

## CHANGE LOG

- **2026-11-16** — the container never holds the vault: the home mount is paired with a read-only
  tmpfs over `hodd/secrets`, both sides of every mount are `%h` (the undefined `$HOME_SEAT` is
  gone), and a gate holds the pair together. the reviewer's item 5 of the 12 November review.
- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
