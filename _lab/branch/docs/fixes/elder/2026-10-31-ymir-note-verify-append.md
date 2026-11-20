# Fix note — ymir_note now verifies its own append

**Component:** elder
**Date:** 2026-10-31

## Why

ymir_note returned "appended to <path>" even when the body was silently dropped.
The old implementation used `printf '%s' ... && cat >> "$1"` where the `%s`
had no argument (heading never passed) and `cat >> "$1"` read from stdin that was
never provided. The result: only a `---` separator and blank lines were written.

## What changed

Rewrote the append to write heading + body in one atomic `printf '%s'` call,
then read the file back and verify the heading is present. If the heading is not
found, returns a WARNING instead of a false success.

## Files
- .pi/extensions/elder.ts (ymir_note tool)
