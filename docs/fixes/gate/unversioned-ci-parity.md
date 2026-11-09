# Fix: CI fetches the base on push too

Date: 2026-11-09
Component: gates

Workflow now fetches origin/main (or the PR base) for push events as well, so
nodelete_base resolves a base on both events and the no-delete gate runs the same
range on one sha.
