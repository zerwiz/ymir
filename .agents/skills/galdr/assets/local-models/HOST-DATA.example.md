# HOST-DATA.example — the shape of a host record

A host record is **private to the machine it describes** and lives in that
machine's Hoard: `hodd/docs/modeltesting/`. This file is the tracked `*.example`
shape (Rule 04) so a new operator knows what belongs there without inheriting
anyone's data.

Copy this skeleton into the Hoard and fill it in per host.

---

## `<hostname>` — `<device summary>`

| | |
|---|---|
| Serving GPU | `<vendor model, VRAM, link>` |
| Other GPU(s) | `<device, role>` |
| System RAM | `<size>` |
| Driver / runtime | `<versions>` |
| Model directory | `<path>` where the weights actually live |

## Serving stack on this host

| Part | Path / endpoint |
|---|---|
| Registry (single source of truth) | `<path>` |
| Launcher / engine | `<path>` |
| Router / gateway | `<path>` `:<port>` |
| Secondary endpoint (other device/backend) | `<path>` `:<port>` |
| Autostart | `<systemd unit or equivalent>` |
| Client wiring | `<pi / editor / other>` |

## Models on this host, verified

One row per model. `ctx` is the **verified** window — the largest value that
survived a real request — never the file's maximum.

| Model | quant | weights | KV bytes/token | ctx | prefill t/s | decode t/s | peak memory | alias |
|---|---|---|---|---|---|---|---|---|
| `<name>` | `<quant>` | `<GiB>` | `<KiB>` | `<ctx>` | `<n>` | `<n>` | `<MiB>` | `<alias>` |

## Configurations tried and rejected

The most useful part of the record. Keep what failed and why.

| Config | Result | Cause |
|---|---|---|
| `<ctx / kv / batch / device>` | `<load failure, crash on request, etc.>` | `<measured cause>` |

## Measured rules this host produced

Short, falsifiable statements, each traceable to a table above. For example:
"a smaller context ceiling changes memory and not speed — measured identical
decode at two ceilings" or "KV size, not weight size, decides how much context
fits on this device".

## Traps specific to this host

| Symptom | Cause | Fix |
|---|---|---|
| `<observable>` | `<mechanism>` | `<what to do>` |

## Reference points for a new model on this host

The budget formula with this box's numbers filled in, so the next model can be
sized before it is downloaded:

```
usable_context = (free_memory - weights - compute_buffer) / kv_bytes_per_token
```
