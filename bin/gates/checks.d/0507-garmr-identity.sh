#!/usr/bin/env bash
# garmr-identity — 2026-11-20: a CRITICAL names the file it says changed, or it is not a CRITICAL.
# The identity watch fired with an empty target every quarter hour and called it "passwd, shadow,
# sudoers or an authorised key"; the proof is that an unnamed target is HIGH and claims nothing, and
# a named path is still CRITICAL.
gate garmr-identity "an identity alert with no path is HIGH and claims no file; a named path stays CRITICAL" \
     bash "$ROOT/bin/ward/tests/test_garmr_identity_named.sh"
