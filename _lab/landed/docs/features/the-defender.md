# Víðarr — the defender: contain, and leave an account

**What it is.** The hand of the house's defence. Garmr *notices* (the hound), Vörðr *refuses* (the
gates), and Víðarr *contains*: closes a door an intruder opened, stops a unit, kills a process that
should not run, quarantines a file, blocks egress — and keeps the evidence and the report.

**What you need.** The guardian's config (`$YMIR_HOME/config/guardian.yaml`) and a rules file
(`$YMIR_HOME/config/garmr-rules.yaml`, copied from the shipped example). The hound's senses need one
root install: `sudo bin/ward/garmr.sh install`.

## Do it

```bash
bin/ward/vidarr.sh status            # the switch, armed classes, incidents, quarantine
bin/ward/vidarr.sh respond --dry-run # what it WOULD contain, and the undo for each
bin/ward/vidarr.sh respond           # the pass, within the switch and the armed classes
bin/ward/vidarr.sh incident open "a port opened by nobody I named"
bin/ward/vidarr.sh evidence <id>     # a hashed bundle: listeners, units, findings, bites
bin/ward/vidarr.sh report <id>       # the account, into hodd/security/incidents/
bin/ward/vidarr.sh stand-down        # the Allfather's hand: bite=report, nothing contained

bin/ward/vidarr-agent.sh up          # seat him as a live agent (room name: vidarr)
```

## Limits — read these before arming anything

- **A bite needs a written rule.** An unarmed class is a bark, and the refusal names the line to edit.
- **The model advises, the rules dispose.** `opencode-go/deepseek-v4.1-flash` sees *metadata only* —
  never a payload — and may answer only with one of the six or `none`.
- **Nothing leaves the machine.** No counter-scan, no retaliation: a blocked destination is a door we
  closed.
- **Never the operator's hands**: not his terminal, not an open vault, not a model mid-generation.
- **Every bite names its un-bite**, and the report says so.

## If it does not work

```bash
bin/ward/garmr.sh status      # are the senses alive at all?
bin/ward/garmr.sh verify      # a silent guardian is a CRITICAL, not a quiet night
bin/ward/garmr-bite.sh status # the switch, the rules file, the bites taken
bin/ward/vidarr.sh incident list
```
