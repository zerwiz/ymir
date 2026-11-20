# gates · unversioned · 2026-11-20 — a mailbox has a domain, a cron role does not

The ward refused a pull request for telling the truth about the schedule. A body line read
*"The Nornir row `@dev 03:05 …` runs before the brief"*, and `bin/forge/pr-patterns.sh` matched any
`notspace@notspace` as a published address. `pr-identity-guard` therefore refused the PR, and the
hand that wrote the schedule was taught to leave it out of the record — which is worse than the
leak the ward exists to prevent.

## What was wrong

```bash
# before
printf '%s' "$line" | grep -Eo '[^[:space:]]+@[^[:space:]]+'
```

Two words joined by `@` is a shape, not an address. `@dev` and `@heart` are role tokens in the
cron rows the house writes (`config/cron.yaml`, the Nornir jobs); an address has a local part **and
a dot-separated domain**.

## What changed

- The pattern now requires the domain to be dot-separated:
  `[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+`.
- The `users.noreply.github.com` allowance is unchanged, and a mixed line (a noreply account beside
  a real address) is still refused.
- The nested test that ran the same `grep` three times to answer one question is one test now.

## Proof

```text
$ bash bin/gates/tests/test_pr_patterns_mailbox.sh
a role token is not a mailbox
  ok   clean: The Nornir row `@dev 03:05 …` runs before the brief
  ok   clean: @heart carries the brief at 07:00
an address still is
  ok   flagged mailbox: Ada Lovelace <ada.lovelace@example.org>
  ok   flagged mailbox: mixed: users.noreply.github.com and ada@example.org
the whole door, not one line
  ok   pr_pattern_match passes a body that quotes @dev
  ok   pr_pattern_match refuses a real address
all cases hold
```

The pane-id and ipv4 patterns are asserted in the same file, so a later edit to the mailbox test
cannot quietly disarm the rest of the ward.

## Files

- `bin/forge/pr-patterns.sh` — `PR_MAILBOX`, and one mailbox test instead of three
- `bin/gates/tests/test_pr_patterns_mailbox.sh` — both halves, by command
