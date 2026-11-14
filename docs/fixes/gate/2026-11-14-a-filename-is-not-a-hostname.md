# A filename is not a hostname

**Date:** 2026-11-14 · **Component:** gate (`bin/gates/guards/rules-compliance-guard.sh`) · **Plan:** 275 item 22

## What was wrong

RULES/39's ward refuses an internal address or an mDNS name in a line a push **adds**. Its pattern for an mDNS host is
a token ending in the mDNS suffix (not followed by a slash), so the house's own env file — `$YMIR_HOME/.env.local` — read as a *host* called `.env`, and every
new document that named it was refused:

```
"docs/fixes/bridge/2026-11-14-…md","added","RULES/39 · network N1/N7",
"address or plain-HTTP URL in a new line: … OPENCODE_GO_API_KEY sat in `$YMIR_HOME/"
```

The ward was right about the shape and wrong about the token: the file is the one the operator contract itself names,
and a ward that refuses it is a ward the next hand must override — and a routinely overridden ward is one nobody
trusts.

## The fix

One exclusion, with its reason written beside the others in the ward: a line whose mDNS suffix is the tail of the
house's env filename is not an address. A host that genuinely ends in that suffix is still refused — the exclusion is
the *filename*, not the suffix. The XDG data path under the home already passed, because the pattern requires the
suffix not to be followed by a slash.

## Verified

`bin/gates/tests/test_rules_compliance_env_file.sh` — a throwaway repo carrying the ward at its own path, three
claims: a new line naming the house's env file is **clean**; a real mDNS host is still **refused**; a private LAN address
is still **refused**. Wired into `bin/gates/ci-verify.sh` as `rules-compliance-env-file`.

The specific document that tripped it (the bridge fix note) now passes the ward unchanged, which is the point: the
note did not need rewording, the ward needed to know a filename from a host.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #750
