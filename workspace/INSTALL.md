# Ymir — first setup

Provisioned by `bin/ymir-install.sh` at 2026-09-13T06:48:11Z.

## Workspaces

- work (company: wayof)
- personal

## Engines

- Yggdrasil → treehouse
- Utgard → sandcastle
- Mjollnir/Glitnir → no-mistakes
- Hermes → hermes-agent (worker runtime)
- Sessrúmnir → pi-desktop (desktop GUI, vendored at apps/sessrumnir)

## Next

1. `gh auth login` (your own GitHub login).
2. Fill each project's `git{}` block in `hodd/identity/projects.yaml`.
3. `scripts/start.sh` then open http://127.0.0.1:3888/.
4. To let someone else try it, share the invite code printed above
   (or mint another: `bin/ymir-invite.sh mint <n>`). They register at the
   login screen; `bin/ymir-invite.sh list` shows what is spent.
