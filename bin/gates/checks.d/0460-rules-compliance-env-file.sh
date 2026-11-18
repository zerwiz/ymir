#!/usr/bin/env bash
# The ward that guards RULES/39 read the house's own env filename (`$YMIR_HOME/.env.local`) as an
# mDNS host and refused every new document that named it. A filename is not a hostname (plan 275).
gate rules-compliance-env-file "the address ward tells a documented filename from an mDNS host, and still refuses a host" \
     bash "$ROOT/bin/gates/tests/test_rules_compliance_env_file.sh"
