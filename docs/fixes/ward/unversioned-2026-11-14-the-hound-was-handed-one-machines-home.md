## ward · unversioned · 2026-11-14 — the hound's unit was handed one machine's home

The private sweep reported, in an earlier pass of the same day, a machine home baked into a shipped
unit template: `tools/mill/systemd/garmr-hound.service` carried

```
Environment=YMIR_HOME=/home/heimdall/Documents/ymirhome
```

The hound runs as **root**, whose `HOME` is `/root`, so it cannot resolve the hoard by itself — the
unit has to be told. But *which* home is a fact of the machine that renders the unit, not of the
public repository.

> [!IMPORTANT]
> `__YMIR_OPERATOR_HOME__` is the house's existing token for exactly this (it is what `gna-desk.service`
> uses and what `bin/fleet/fleet-ensure.sh` substitutes). The hound had simply never been moved onto it.

### What changed

| file | change |
|---|---|
| `tools/mill/systemd/garmr-hound.service` | `Environment=YMIR_HOME=__YMIR_OPERATOR_HOME__`, and the header names both tokens it carries |
| `bin/ward/garmr.sh` | `install` substitutes `__YMIR_OPERATOR_HOME__` with the hoard root it already resolved (`HOME_DIR`), beside the `__YMIR_ROOT__` it already substituted |

### Proof

`bin/engine/units.py`'s `render_template()` now fills the same token, so a unit rendered either way is
whole. The render, by hand, of the two tokens:

```
$ sed -e "s|__YMIR_ROOT__|/pin|g" -e "s|__YMIR_OPERATOR_HOME__|/x/hoard|g" \
    tools/mill/systemd/garmr-hound.service | grep -n 'YMIR_HOME=\|ExecStart='
14:Environment=YMIR_HOME=/x/hoard
19:ExecStart=/usr/bin/python3 /pin/bin/ward/garmr/hound.py
```

And the gate that reads every unit template agrees — `bin/gates/checks/unit-template-check.sh` reports
`28 checked, ok — systemd reads every key`.

### Files

- `tools/mill/systemd/garmr-hound.service`
- `bin/ward/garmr.sh`

Reported by `bin/time/nornir-job-private-scan.sh`; the home's record is
`hodd/docs/machines/zerwizserver/2026-11-14-the-machine-paths-left-the-public-repo.md`.

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #743
