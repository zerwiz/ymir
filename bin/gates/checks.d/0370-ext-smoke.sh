#!/usr/bin/env bash
# ext-smoke — every Ymir tool ANSWERS when called like Pi calls it.
gate ext-smoke  "every Ymir tool ANSWERS when called like Pi calls it" \
               node --experimental-strip-types "$ROOT/tools/extension-smoke.mjs"
