#!/usr/bin/env bash
# realms-from-registry — Hlidskjalf's realm list is the home's registry, never a name in the code.
#
# RULES/04 — a realm is a shelf of the operator's home. The shipped build carries a generic pair
# and the list is READ from the registry at run time, so no realm's own name is in the public tree
# and a home with none still opens. This is the proof that it stays so.
gate realms-from-registry "Hlidskjalf's realm list is the home's registry, never a name in the code" \
     node --test "$ROOT/apps/hlidskjalf/server/realms-registry.test.ts"
