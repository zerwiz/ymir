# Rule 05 — Platform installations

Ymir is **Omarchy-first**: the Omarchy layer is the first-class desktop
integration. Different operating systems and desktops may have their own
installation layer — macOS and Windows bring their own — while the **core stays
portable** and identical everywhere.

## The law

- **One core, many installations.** The core runtime — session digest, lock,
  watch, cron, skills, the installer's user-space prerequisites, machine-config
  rendering — runs on Linux, macOS and Windows (WSL2; MSYS best-effort).
  Anything platform-specific lives in an *installation layer* beside the core,
  never as a branch inside it.
- **A layer is gated, never assumed.** It detects its own host and reports a
  clean skip elsewhere (`/usr/share/omarchy`, `uname`, `ymir_os`). A layer that
  assumes it is present is a bug on every other machine.
- **Core changes propagate to every layer.** When a core feature changes, **every
  platform installation layer must be updated in the same change**. A layer that
  still installs the old shape is drift — and drift here means a machine that
  boots expecting a runtime it no longer has.
- **A layer owns its integration, not a copy of the core.** No layer forks a
  core script. It calls the core and adds only what its platform needs; two
  copies of one script is how the platforms silently diverge.
- **The desktop is a platform concern.** Window placement, launcher entries,
  service managers (systemd / launchd / Windows services) and GPU tooling belong
  to the layer that knows the platform.
- **Verification is per-layer.** "It works" is a claim about *one* layer. Name
  the layer that was tested; never let a core change be called verified because
  one platform's install passed.

## The layers

```
layers[4]{layer,host,owns}:
  "Omarchy (first-class)","Omarchy (Arch + Hyprland)","host sensing, numbered-desktop placement, launcher entries, shell plugins, post-update hook"
  "macOS","macOS","launchd services, .command/.app launchers, Apple GPU reporting"
  "Windows","WSL2 (MSYS best-effort)","WSL service wiring, .cmd/.lnk launchers"
  "Core (portable)","every platform","the runtime, the capability shim, generated config, user-space prerequisites"
```

## Where this shows up

| Place | What carries the rule |
|---|---|
| `bin/ymir-platform.sh` | the capability shim: the one place a platform difference is known |
| `bin/ymir-install.sh` | runs the core; Omarchy steps are gated on the host |
| the Omarchy layer (`omarchy-sense`, `omarchy-plugins`, `omarchy-hook-install`, `desktop-place`) | Omarchy only, each reporting a clean skip elsewhere |
| `galdr/assets/installation.md` | the two-layer model, and the rule for new desktop features |
| `galdr/assets/build-method.md` | the maintenance duty: a core change updates every layer |

## Maintenance duty

A core change is not complete until every layer has been checked against it. The
check is cheap and must be explicit:

```bash
# which layers does this change touch?
git grep -l "<the changed core interface>" -- bin scripts .agents/skills
```

If a layer needs a matching edit, make it in the same change, or record why it
does not. A rule that contradicts this rule must change the rule first
(append-only; never silently rewritten).

**Related:** `RULES/04-hoard.md` (what is private), `AGENTS.md` (the contract),
`.agents/skills/galdr/assets/installation.md` (the install procedure).
