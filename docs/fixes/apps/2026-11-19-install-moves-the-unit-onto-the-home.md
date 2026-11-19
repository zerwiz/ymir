## apps · 2026-11-19 — installing an app moves its Ymir-rendered unit onto the app's home

### Why
The smithy was installed end to end on the dev machine after the split. `bin/apps/apps.sh install smidja` cloned it,
built the release, flipped `current` and seated its doors, and reported `updated`. But `smidja.service`, the viewer
on `:8437`, kept serving the copy inside the pin's tree (`…/ymir-runtime/apps/smidja-factory/apps/visualizer`).

The cause is in `bin/apps/apps.py`. The viewer's unit is rendered by Ymir, from `tools/web/systemd/smidja.service`,
by `bin/fleet/fleet-ensure.sh unit smidja`, and that renderer finds the app through the resolver. Nothing on the
install road asked it to render again. `restart()` then rightly skipped the unit, because it did not run from the
app's home. So the install left the live service on the legacy road. Once the pin moves to a release without
`apps/smidja-factory`, that unit would point at a folder that no longer exists.

### What changed
- `apps.py` gains `seat_units()`, run after `activate.sh` and before `restart()` on every flip.
- It re-renders a unit only when all of these hold:
  - the app's `app.yaml` names it under `units:`;
  - Ymir ships its template in `tools/web/systemd/`;
  - this seat already carries the unit (the role that owed it stays the judge);
  - the unit does not yet run from the app's home;
  - the desk is not in a call.
- It renders through Ymir's one renderer (`fleet-ensure.sh unit <program>`), never by a second copy of the template.
  `YMIR_UNIT_RENDER_DOOR` names a different renderer, so tests never touch the seat's real units.
- The update line names what moved: `units re-seated smidja.service · restarted smidja.service`.

### Proof
- `python3 bin/apps/tests/test_apps.py`: 15 tests pass. Three are new: a Ymir-rendered unit is re-seated through the
  renderer; a unit Ymir does not render is left alone; a unit already on the home, or not owed on this seat, is left
  alone. The lifecycle tests point the render door at a path that does not exist.
- On the dev machine the unit was put back as the first install found it (the viewer's cwd was the pin's
  `apps/smidja-factory/apps/visualizer`). Then `apps.sh remove smidja --yes` and `apps.sh install smidja` printed
  `"smidja","updated","current a78eabb0e472 · activated · units re-seated smidja.service · restarted smidja.service"`.
  The viewer's cwd became `~/.local/share/ymir-apps/smidja/releases/a78eabb0e472/apps/visualizer`, and
  `/api/health` answered `{"ok":true,…,"sessions":6}`.

### Not changed
The other Ymir-rendered units (`hlidskjalf-*`, `mimir`, `bifrost`, `nornir`) belong to apps that stay in the tree, so
nothing about them moves. An app whose own repo carries its unit still seats it from its own `activate.sh`.

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
