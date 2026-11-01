## gimle · 2026-11-01 — the four passwords are Authelia's help text

### What

`~/apps/gimle-gate/config/users_database.yml` holds four accounts — **zerwiz, craig, reygan, isabella** — and
**not one of them has a password hash.** Each `password:` value is a quoted multi-line blob that begins
`"v4.39.28` and then reads *"open-source authentication via documentation / [flags] / [command] / --config"*:
the output of `authelia crypto hash generate --help`, pasted where the hash belonged.

```
measured[4]{item,value,meaning}:
  "lines in the file","221","four users, ~54 lines each — because each password blob is ~50 lines of help text"
  "argon2id hashes in the file","**0**","Authelia verifies argon2; nothing here can verify"
  "accounts that can authenticate","**0 of 4**","the door answers, the login cannot succeed"
  "the gate itself","healthy, serving :8484 and :8481","so the fault is silent: a 302 to a login nobody can pass"
```

### Why this matters more than a missing account

It is the difference between *"Sebastian has no Gimle account yet"* and *"nobody has a working Gimle account."* The
desk, the board and every place behind that gate have been unreachable by login, and the symptom — a login page
that rejects every password — reads like a forgotten password rather than a corrupt file.

### The repair (needs root: the directory is `root:root`)

```bash
# 1 · generate a real hash with the container's own CLI, and keep it quoted on ONE line
HASH=$(docker exec gimle-gate authelia crypto hash generate argon2 --password 'CHANGE-ME' | grep -oE '\$argon2id\$[^ ]+')
echo "$HASH"    # must start $argon2id$v=19$m=... and be a single line

# 2 · rewrite the file with valid single-line hashes, keeping the existing users and groups
sudo python3 - "$HASH" <<'PY'
import re, sys, pathlib
hash_value = sys.argv[1]
p = pathlib.Path('/home/zerwizserver/apps/gimle-gate/config/users_database.yml')
text = p.read_text()
p.with_suffix('.yml.bak-help-' + __import__('datetime').date.today().isoformat()).write_text(text)
# replace each multi-line quoted password blob with one valid hash line
text = re.sub(r'password: "v4\.39\.28.*?\n(?=    groups:)', f'password: "{hash_value}"\n', text, flags=re.S)
p.write_text(text)
print('users:', len(re.findall(r'^  [a-z]+:$', text, flags=re.M)))
PY

# 3 · restart, then prove it
sudo docker restart gimle-gate
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8481/api/health   # 200
```

**Then each person sets a password of their own** — the hash above is a placeholder, so the sequence is: generate a
one-time password per user, hand it over out of band, and let them change it. A hash is not a password and must never
be reused across accounts.

### Verified

Read from the server: 221 lines, zero `argon2id` occurrences, four `password: "v4.39.28` openers, and Authelia
answering on :8481. Not yet repaired — the file is root-owned and no passwordless sudo exists on this seat.

### The lesson

A config file that parses is not a config file that works. `grep argon2id` takes one second and would have caught
this the day it was written; every gate install should end with that one line, not with "the container is healthy".

### The repair script, ready and tested (appended 2026-11-01)

The Allfather settled the roster: **keep `zerwiz` (him) and `craig`, remove `reygan` and `isabella`, add
`sebastian`, `andre`, `michael`.** The script that does it is on the server at
`~/gimle/gate-accounts-repair.sh` (mode 700), and one command runs it:

```bash
sudo bash ~/gimle/gate-accounts-repair.sh
```

**What it does, in order:** backs the file up with a timestamp · generates a random one-time password per person and
hashes it **with the container's own CLI** · writes the five users with their emails
(`WhyNot_10@hotmail.com`, `andre.matejic@gmail.com`, `michael-lind@live.se`) and the group `team` · **refuses to
install** unless the result has exactly five users, five `argon2id` hashes and zero help-text blobs · keeps the file's
owner and mode · restarts the gate · proves `/api/health`.

**The one-time passwords are written once** to `~/gimle/one-time-passwords-<stamp>.txt`, mode 600, and printed
nowhere else. Hand each person their own line, then delete the file. A hash is not a password and is never shared
between accounts.

**Tested before it was handed over:** the hash extraction was run against the live container (a 97-character
`$argon2id$v=19$…` digest came back), and the assembly was simulated end to end with a stub `docker` — five users,
five hashes, zero help-text blobs, and a per-person password list. `bash -n` passes on the server itself.

**Removing reygan and isabella** is a gate decision, not a deletion of their records: they stay in
`hodd/identity/collaborators.yaml`, and the record there now says their Gimlé access was withdrawn on this date.
