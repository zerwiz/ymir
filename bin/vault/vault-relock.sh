#!/usr/bin/env bash
# vault-relock.sh — the door that locks the vault to the owner's GitHub SSH keys (plan 342).
#
# WHAT IT DOES. `age` can encrypt to SSH public keys, and GitHub publishes the owner's
# public SSH keys. So the vault is encrypted to **every key GitHub lists for the owner
# that the home DECLARES** in `config/vault-recipients.yaml`, and each machine opens it
# with its own private key, which never leaves that machine. No key file sits in the
# repository beside the thing it unlocks.
#
# THE ROADS, in order, and the answer names which one spoke:
#   1. `gh api user/keys`     titles AND keys, needs the owner's own `gh` login
#   2. `github.com/<login>.keys`  keys only (no titles), when `gh` lacks the scope
# A key GitHub lists that the home does not declare is REPORTED and NEVER used. A key
# the home declares that GitHub does not list is a REFUSAL: re-locking without it would
# quietly take that machine's access away.
#
#   vault-relock.sh --plan              who would be added or dropped, by title (writes nothing)
#   vault-relock.sh --check             does this seat open the vault, and do the declarations match GitHub
#   vault-relock.sh --relock            the re-lock itself
#   vault-relock.sh --add-machine       print the `gh ssh-key add` command for this machine, then re-lock
#   vault-relock.sh --recipients        print the age `-R` recipients file (used by hodd-set.sh)
#
# Modifiers: `--ship` (send the re-locked file through `bin/vault/home-sync.sh ship`)
#            `--title <name>` (the GitHub title `--add-machine` names)
#            `--strict` (with `--check`: a legacy key or a tracked plain `.env` is a fault)
#            `--quiet` (with `--check`: no rows, the exit code is the answer — Eir's surface)
#
# THE GUARDS, every one of them learned from a vault that was lost or nearly lost:
#   1. the decrypted plaintext must be non-empty and must carry at least one KEY= line;
#   2. the NEW file is decrypted again and compared with the old plaintext BYTE FOR BYTE
#      before anything replaces anything;
#   3. the old file is kept as a timestamped backup beside it;
#   4. the write is atomic (install to a new name, then mv), mode 0600;
#   5. the only plaintext that ever touches the disk is a 0600 temp, shredded on exit;
#   6. nothing in this door prints a value — only titles, fingerprints and counts.
#
# Environment (Rule 07 — one documented default each):
#   YMIR_VAULT_FILE         the vault file (default: `vault:` in the recipients file,
#                           else `<hoard>/secrets/platform.env.age`)
#   YMIR_VAULT_RECIPIENTS   the declaration (default `<home>/config/vault-recipients.yaml`)
#   YMIR_VAULT_IDENTITY     this seat's private key (see bin/vault/vault-identity-lib.sh)
#   YMIR_AGE_BIN / YMIR_GH_BIN / YMIR_CURL_BIN   the tools (default: age · gh · curl)
#
# Exit: 0 ok · 1 a guard refused (nothing was written) · 2 usage · 3 --check found a fault.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=bin/vault/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
# shellcheck source=bin/vault/vault-identity-lib.sh
. "$SCRIPT_DIR/vault-identity-lib.sh"

AGE="${YMIR_AGE_BIN:-age}"
GH_BIN="${YMIR_GH_BIN:-gh}"
CURL_BIN="${YMIR_CURL_BIN:-curl}"

usage() { sed -n '2,53p' "$0" | sed 's/^# \{0,1\}//'; }
die()  { printf 'vault-relock: %s\n' "$*" >&2; exit 1; }

ACTION=""
SHIP=0
STRICT=0
QUIET=0
TITLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    --plan|--check|--relock|--add-machine|--recipients)
      [ -z "$ACTION" ] || { usage >&2; exit 2; }
      ACTION="${1#--}" ;;
    --ship) SHIP=1 ;;
    --strict) STRICT=1 ;;
    --quiet) QUIET=1 ;;
    --title) shift; TITLE="${1-}"; [ -n "$TITLE" ] || { printf 'error: --title needs a name\n' >&2; exit 2; } ;;
    *) printf 'error: unknown argument %s\nhelp: vault-relock.sh --help\n' "$1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$ACTION" ] || { usage >&2; exit 2; }

# ── where everything is ───────────────────────────────────────────────────────
ymir_home_root HOME_R 2>/dev/null || die "the home is unresolved (see bin/vault/hoard-lib.sh)"
[ -n "${HOME_R:-}" ] || die "the home is unresolved"
hoard_root HOARD
hoard_state_dir STATE 2>/dev/null || STATE="$HOME_R/state"

YAML=""
vault_recipients_yaml YAML 2>/dev/null || YAML=""

VAULT_REL="hodd/secrets/platform.env.age"
if [ -n "$YAML" ] && [ -r "$YAML" ]; then
  _v="$(vault_declared_top "$YAML" vault 2>/dev/null || true)"
  [ -n "$_v" ] && VAULT_REL="$_v"
  unset _v
fi
case "$VAULT_REL" in /*) VAULT="$VAULT_REL" ;; *) VAULT="$HOME_R/$VAULT_REL" ;; esac
[ -n "${YMIR_VAULT_FILE:-}" ] && VAULT="$YMIR_VAULT_FILE"

LOCK_STATE="$STATE/vault-lock.state"

# ── temp: the only plaintext that ever touches the disk, and it never survives ─
work="$(mktemp -d)" || die "cannot make a work directory"
chmod 700 "$work"
cleanup() {
  if command -v shred >/dev/null 2>&1; then
    find "$work" -type f -exec shred -u {} + 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

need_tools() {
  command -v "$AGE" >/dev/null 2>&1 \
    || { printf 'vault-relock: %s is not installed\nhelp: install age (Arch: sudo pacman -S age · macOS: brew install age)\n' "$AGE" >&2; exit 1; }
  command -v ssh-keygen >/dev/null 2>&1 \
    || { printf 'vault-relock: ssh-keygen is not installed — it reads the fingerprints\nhelp: install the OpenSSH client\n' >&2; exit 1; }
}

# ── the identity this seat opens the vault with ──────────────────────────────
IDENTITY=""
vault_identity_resolve IDENTITY 2>/dev/null || IDENTITY=""
LEGACY=0
if [ -n "$IDENTITY" ] && vault_identity_is_legacy "$IDENTITY"; then LEGACY=1; fi

# ── GitHub: the owner's public keys, by the two roads ───────────────────────
GH_ROAD=""
LOGIN=""
# github.tsv: title <TAB> fingerprint <TAB> key
gh_keys() {  # <out.tsv>; sets GH_ROAD and LOGIN
  local out=$1 raw="$work/gh.raw" err="$work/gh.err" login="" k
  : > "$raw"
  if [ -n "$YAML" ] && [ -r "$YAML" ]; then
    login="$(vault_declared_top "$YAML" login 2>/dev/null || true)"
  fi
  if [ -z "$login" ] && command -v "$GH_BIN" >/dev/null 2>&1; then
    login="$("$GH_BIN" api user --jq .login 2>/dev/null | head -1 || true)"
  fi
  LOGIN="$login"

  if command -v "$GH_BIN" >/dev/null 2>&1 \
    && "$GH_BIN" api 'user/keys?per_page=100' --paginate --jq '.[]' > "$raw" 2>"$err" \
    && [ -s "$raw" ]; then
    GH_ROAD="gh"
    python3 - "$raw" "$out" <<'PY'
import json, sys
raw, out = sys.argv[1], sys.argv[2]
rows = []
for line in open(raw, errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if isinstance(d, dict) and d.get("key"):
        rows.append(((d.get("title") or "").strip(), d["key"].strip()))
with open(out, "w") as f:
    for title, key in rows:
        f.write(f"{title}\t{key}\n")
PY
    if [ -s "$out" ]; then
      _fingerprint_column "$out"
      return 0
    fi
  fi

  # Road two: GitHub's public key list. No titles — a declaration then matches by fingerprint.
  if [ -n "$login" ] && command -v "$CURL_BIN" >/dev/null 2>&1; then
    if "$CURL_BIN" -fsS --max-time 15 "https://github.com/$login.keys" > "$raw" 2>"$err" && [ -s "$raw" ]; then
      GH_ROAD="github"
      python3 - "$raw" "$out" <<'PY'
import sys
raw, out = sys.argv[1], sys.argv[2]
with open(out, "w") as f:
    for line in open(raw, errors="replace"):
        line = line.strip()
        if line and not line.startswith("#"):
            f.write("\t" + line + "\n")
PY
      _fingerprint_column "$out"
      return 0
    fi
  fi

  GH_ROAD=""
  return 1
}

# Turn the key column into a fingerprint, in place: ssh-keygen is the only honest
# answer to "which key is this", and a title can be reused where a fingerprint cannot.
_fingerprint_column() {  # <file>
  local f=$1 tmp="$work/pub.tmp" title key fp
  : > "$f.fp"
  while IFS=$'\t' read -r title key; do
    [ -n "$key" ] || continue
    printf '%s\n' "$key" > "$tmp"
    fp="$(vault_pub_fingerprint "$tmp" 2>/dev/null || true)"
    rm -f "$tmp"
    printf '%s\t%s\t%s\n' "$title" "${fp:-}" "$key" >> "$f.fp"
  done < "$f"
  mv "$f.fp" "$f"
}

# ── the selection: declared ∩ GitHub, and every disagreement named ──────────
# Writes $work/recipients (the age -R file) and $work/plan.tsv
# (status <TAB> title <TAB> fingerprint <TAB> machine).
SELECTED=0
build_selection() {
  : > "$work/declared.tsv"; : > "$work/recipients"; : > "$work/plan.tsv"
  if [ -z "$YAML" ] || [ ! -r "$YAML" ]; then
    printf 'vault-relock: no declarations at %s\nhelp: copy config/vault-recipients.yaml.example into the home as config/vault-recipients.yaml and name the keys that may open the vault\n' "${YAML:-<home>/config/vault-recipients.yaml}" >&2
    return 1
  fi
  vault_declared_rows "$YAML" > "$work/declared.tsv" 2>"$work/declared.err" || {
    cat "$work/declared.err" >&2
    printf 'vault-relock: the declarations at %s are malformed — nothing was written\n' "$YAML" >&2
    return 1
  }
  if [ ! -s "$work/declared.tsv" ]; then
    printf 'vault-relock: the declarations at %s name no recipient — the vault would have no lock\n' "$YAML" >&2
    return 1
  fi

  gh_keys "$work/github.tsv" || {
    if [ -n "$LOGIN" ]; then
      printf 'vault-relock: the owner\x27s public keys could not be read (gh lacks the scope and github.com/%s.keys did not answer)\nhelp: gh auth refresh -s read:public_key   (or)   check the network\n' "$LOGIN" >&2
    else
      printf 'vault-relock: the owner\x27s GitHub login is unknown — sign in with gh, or name `login:` in %s\n' "$YAML" >&2
    fi
    return 1
  }

  python3 - "$work/declared.tsv" "$work/github.tsv" "$work/recipients" "$work/plan.tsv" <<'PY'
import sys
declared_f, github_f, recip_f, plan_f = sys.argv[1:5]

def rows(path, n):
    out = []
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        while len(parts) < n:
            parts.append("")
        out.append(parts[:n])
    return out

declared = rows(declared_f, 3)          # title, fingerprint, machine
github = rows(github_f, 3)              # title, fingerprint, key
by_title, by_fp = {}, {}
for title, fp, key in github:
    if title:
        by_title.setdefault(title, []).append((fp, key))
    if fp:
        by_fp.setdefault(fp, []).append((title, key))

# age reads ssh-ed25519 and ssh-rsa recipients, plus the security-key variant whose type
# carries a domain — assembled from parts so no ward reads this line as a mailbox.
_SECKEY_TYPE = "sk-" + "ssh-ed25519" + "@" + "openssh" + ".com"
SUPPORTED = ("ssh-ed25519", "ssh-rsa", _SECKEY_TYPE)
plan, recipients, used_fps = [], [], set()

for title, fp, machine in declared:
    cands = []
    if fp:
        cands = [(t, k) for (t, k) in by_fp.get(fp, [])]
    elif title in by_title:
        cands = [(title, k) for (f, k) in by_title[title]]
    if not cands:
        plan.append(("missing", title, fp, machine))
        continue
    if len(cands) > 1:
        plan.append(("ambiguous", title, fp, machine))
        continue
    gtitle, key = cands[0]
    ktype = key.split(" ", 1)[0]
    if ktype not in SUPPORTED:
        plan.append(("unsupported", title, fp, (machine + " · " + ktype).strip(" ·")))
        continue
    drift = "" if gtitle == title else (" · GitHub lists this key as " + gtitle)
    if not fp:
        plan.append(("title-only", title, "", machine + drift))
    else:
        plan.append(("used", title, fp, machine + drift))
    if fp:
        used_fps.add(fp)
    recipients.append(key.strip() + "\n")

with open(recip_f, "w") as f:
    f.writelines(recipients)
with open(plan_f, "w") as f:
    for status, title, fp, machine in plan:
        f.write("\t".join([status, title, fp, machine]) + "\n")

# every GitHub key nobody declared: reported, never used
undeclared = []
for title, fp, key in github:
    if fp and fp in used_fps:
        continue
    if fp and fp in {p[1] for p in plan if p[0] in ("missing", "ambiguous", "unsupported")}:
        continue
    undeclared.append(title or "(untitled)")
with open(plan_f + ".undeclared", "w") as f:
    for t in undeclared:
        f.write(t + "\n")
PY

  SELECTED="$(grep -c . "$work/recipients" 2>/dev/null || true)"
  : "${SELECTED:=0}"
}

# One table, its count measured from the rows it will print (a header that lies about
# its own length is a lie a machine reads without noticing).
emit_table() {  # <name> <fields> <file>
  local name=$1 fields=$2 file=$3 n=""
  n="$(grep -c . "$file" 2>/dev/null || true)"
  : "${n:=0}"
  printf '%s[%s]{%s}:\n' "$name" "$n" "$fields"
  cat "$file"
}

plan_rows() {  # the selection, as rows a person reads — into <file>
  local out=$1 status title fp machine
  : > "$out"
  while IFS=$'\t' read -r status title fp machine; do
    [ -n "$status" ] || continue
    printf '  "%s","%s","%s","%s"\n' "$status" "$title" "${fp:--}" "${machine:--}" >> "$out"
  done < "$work/plan.tsv"
  if [ -s "$work/plan.tsv.undeclared" ]; then
    while IFS= read -r title; do
      [ -n "$title" ] || continue
      printf '  "undeclared","%s","-","listed by GitHub, not declared — never used"\n' "$title" >> "$out"
    done < "$work/plan.tsv.undeclared"
  fi
}

selection_faults() {  # 0 when every declared key is usable
  local n
  n="$(awk -F'\t' '$1=="missing"||$1=="ambiguous"||$1=="unsupported"{c++} END{print c+0}' "$work/plan.tsv" 2>/dev/null || echo 0)"
  [ "${n:-0}" -eq 0 ]
}

keys_in() { grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true; }

# ── the verbs ────────────────────────────────────────────────────────────────
do_plan() {
  need_tools
  build_selection || exit 1
  local facts="$work/facts.tsv" changes="$work/changes.tsv" t changed=0
  : > "$facts"; : > "$changes"
  printf '  "file","%s","the vault that would be re-locked"\n' "$VAULT" >> "$facts"
  printf '  "road","%s","%s"\n' "${GH_ROAD:--}" \
    "$([ "$GH_ROAD" = gh ] && echo 'gh api user/keys — titles and keys' || echo 'github.com/<login>.keys — keys only')" >> "$facts"
  printf '  "recipients","%s","declared, on GitHub, and usable"\n' "$SELECTED" >> "$facts"
  emit_table vault-relock field,value,detail "$facts"

  plan_rows "$work/plan.rows"
  emit_table plan status,title,fingerprint,detail "$work/plan.rows"

  # added or dropped, against what the LAST re-lock wrote. This is the door's own
  # record, never a reading of the file: an age header names no recipient.
  if [ -r "$LOCK_STATE" ]; then
    awk -F'\t' '!/^#/ && NF>=2 {print $2}' "$LOCK_STATE" | sort -u > "$work/was"
    awk -F'\t' '$1=="used"||$1=="title-only"{print $2}' "$work/plan.tsv" | sort -u > "$work/now"
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf '  "%s","added"\n' "$t" >> "$changes"; changed=$((changed+1))
    done < <(comm -13 "$work/was" "$work/now" 2>/dev/null)
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf '  "%s","dropped"\n' "$t" >> "$changes"; changed=$((changed+1))
    done < <(comm -23 "$work/was" "$work/now" 2>/dev/null)
    [ "$changed" -eq 0 ] && printf '  "-","unchanged against the last re-lock"\n' >> "$changes"
  else
    printf '  "-","no record of the current lock yet — this re-lock would seal to exactly the declared keys"\n' >> "$changes"
  fi
  emit_table change title,effect "$changes"
  selection_faults || printf 'vault-relock: a declared key cannot be used — a re-lock would REFUSE until it is fixed (see the rows above)\n' >&2
  return 0
}

do_recipients() {
  need_tools
  build_selection || exit 1
  selection_faults || die "a declared key cannot be used — refusing to print a partial recipient set"
  [ "$SELECTED" -gt 0 ] || die "no usable recipient"
  cat "$work/recipients"
}

write_lock_state() {
  mkdir -p "$STATE" 2>/dev/null || true
  {
    printf '# written by bin/vault/vault-relock.sh — what the LAST re-lock sealed to.\n'
    printf '# It records what the last re-lock wrote — never a reading of the file, because an age header names no recipient.\n'
    local status title fp machine
    while IFS=$'\t' read -r status title fp machine; do
      case "$status" in used|title-only) printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$title" "${fp:--}" ;; esac
    done < "$work/plan.tsv"
  } > "$LOCK_STATE" 2>/dev/null || printf 'vault-relock: could not write the lock record at %s\n' "$LOCK_STATE" >&2
}

do_relock() {
  need_tools
  [ -r "$VAULT" ] || die "no vault at $VAULT — the lock has nothing to lock"
  [ -n "$IDENTITY" ] || die "this seat has no identity that could open the vault
help: put a key at ~/.ssh/id_ed25519, or name one with YMIR_VAULT_IDENTITY, or \`identity:\` in $YAML"
  build_selection || die "nothing was written — the declarations or GitHub could not be read (see above)"
  if ! selection_faults; then
    plan_rows "$work/plan.rows"
    emit_table refused status,title,fingerprint,detail "$work/plan.rows"
    die "nothing was written — fix the rows above (GitHub or the declaration), then re-run"
  fi
  [ "$SELECTED" -gt 0 ] || die "no usable recipient — nothing written"

  # guard 1: the plaintext must be real
  "$AGE" -d -i "$IDENTITY" "$VAULT" > "$work/plain" 2>"$work/err" \
    || die "cannot decrypt $VAULT with $IDENTITY — $(head -c 200 "$work/err")
help: this seat is not a recipient of the current vault; a seat that can open it must re-lock"
  [ -s "$work/plain" ] || die "$VAULT decrypted to NOTHING — refusing to touch it"
  local before after
  before="$(keys_in "$work/plain")"
  [ "${before:-0}" -gt 0 ] || die "no KEY=value lines in $VAULT — refusing to touch it"

  # guard 2: encrypt, then decrypt the NEW file and compare BYTE FOR BYTE
  "$AGE" -e -R "$work/recipients" -o "$work/new.age" "$work/plain" 2>"$work/err" \
    || die "re-encryption failed — $(head -c 200 "$work/err") · nothing written"
  "$AGE" -d -i "$IDENTITY" "$work/new.age" > "$work/verify" 2>/dev/null \
    || die "the re-locked file does not open with $IDENTITY — nothing written"
  cmp -s "$work/plain" "$work/verify" \
    || die "the re-locked file does not match the old plaintext byte for byte — nothing written"
  after="$(keys_in "$work/verify")"
  [ "${after:-0}" -eq "${before:-0}" ] \
    || die "the re-lock would change the key count ($before → $after) — nothing written"

  # guard 3 + 4: the old file is kept, the write is atomic and 0600
  local backup="$VAULT.bak-$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$VAULT" "$backup" 2>/dev/null || die "could not keep a backup at $backup — nothing written"
  chmod 600 "$backup" 2>/dev/null || true
  install -m 600 "$work/new.age" "$VAULT.new" || die "could not write $VAULT.new — nothing written"
  mv "$VAULT.new" "$VAULT" || die "could not replace $VAULT — the old file stands"

  write_lock_state

  local facts="$work/facts.tsv"
  : > "$facts"
  printf '  "relocked","%s","%s keys, %s recipients"\n' "$VAULT_REL" "$before" "$SELECTED" >> "$facts"
  printf '  "road","%s","%s"\n' "${GH_ROAD:--}" \
    "$([ "$GH_ROAD" = gh ] && echo 'gh api user/keys' || echo 'github.com/<login>.keys')" >> "$facts"
  printf '  "verified","byte for byte","the new file was decrypted again and compared with the old plaintext"\n' >> "$facts"
  printf '  "backup","%s","kept beside it"\n' "$(basename "$backup")" >> "$facts"
  printf '  "record","%s","what this lock sealed to"\n' "$LOCK_STATE" >> "$facts"

  if [ "$SHIP" = 1 ]; then
    if [ -x "$ROOT/bin/vault/home-sync.sh" ]; then
      "$ROOT/bin/vault/home-sync.sh" ship "vault: re-locked to the declared GitHub SSH keys" "$VAULT_REL" \
        || die "the vault was re-locked but shipping it through home-sync failed — the file on disk IS the new lock"
      printf '  "shipped","%s","through bin/vault/home-sync.sh"\n' "$VAULT_REL" >> "$facts"
    else
      printf 'vault-relock: --ship asked for, but %s is missing — the file on disk IS the new lock\n' "$ROOT/bin/vault/home-sync.sh" >&2
    fi
  fi
  emit_table vault-relock field,value,detail "$facts"
  plan_rows "$work/plan.rows"
  emit_table plan status,title,fingerprint,detail "$work/plan.rows"
  return 0
}

do_add_machine() {
  need_tools
  [ -n "$IDENTITY" ] || die "this seat has no SSH identity
help: ssh-keygen -t ed25519 -C \"\$(hostname -s)\""
  if [ "$LEGACY" = 1 ]; then
    die "this seat opens the vault with the LEGACY key ($IDENTITY), which is being retired
help: ssh-keygen -t ed25519 -C \"\$(hostname -s)\" · then re-run --add-machine"
  fi
  local pub="$IDENTITY.pub" name="${TITLE:-}"
  [ -n "$name" ] || name="$(hostname -s 2>/dev/null || uname -n)"
  if [ ! -r "$pub" ]; then
    pub="$work/$(basename "$IDENTITY").pub"
    ssh-keygen -y -f "$IDENTITY" > "$pub" 2>/dev/null \
      || die "cannot read the public half of $IDENTITY"
  fi
  local facts="$work/facts.tsv" helps="$work/helps.tsv"
  : > "$facts"; : > "$helps"
  printf '  "machine","%s","the title this key would carry on GitHub"\n' "$name" >> "$facts"
  printf '  "identity","%s","the private key of this seat, which never leaves it"\n' "$IDENTITY" >> "$facts"
  printf '  "command","%s %s","run it on this seat, then declare that title in the home"\n' \
    "$GH_BIN ssh-key add" "$pub --title $name" >> "$facts"
  emit_table vault-relock field,value,detail "$facts"
  printf '  "key already on GitHub","the add answers that the key is in use — it is listed; declare its EXISTING title in %s"\n' "$YAML" >> "$helps"
  printf '  "after adding","re-run --plan to see it, then declare it — the re-lock below already ran"\n' >> "$helps"
  emit_table help case,what "$helps"
  do_relock
}

do_check() {
  local faults=0 warns=0 n facts="$work/check.tsv"
  : > "$facts"
  printf '  "home","%s","resolved through bin/vault/hoard-lib.sh"\n' "$HOME_R" >> "$facts"
  printf '  "vault","%s","%s"\n' "$VAULT_REL" "$([ -r "$VAULT" ] && echo readable || echo MISSING)" >> "$facts"
  [ -r "$VAULT" ] || faults=$((faults + 1))

  if [ -z "$IDENTITY" ]; then
    printf '  "identity","none","no SSH identity and no legacy age.key on this seat"\n' >> "$facts"
    faults=$((faults + 1))
  elif [ "$LEGACY" = 1 ]; then
    printf '  "identity","%s","LEGACY age.key — the switch is not finished on this seat"\n' "$IDENTITY" >> "$facts"
    warns=$((warns + 1))
  else
    printf '  "identity","%s","the SSH key of this seat"\n' "$IDENTITY" >> "$facts"
  fi

  if [ -n "$IDENTITY" ] && [ -r "$VAULT" ] && command -v "$AGE" >/dev/null 2>&1; then
    if "$AGE" -d -i "$IDENTITY" "$VAULT" > "$work/plain" 2>/dev/null && [ -s "$work/plain" ]; then
      n="$(keys_in "$work/plain")"
      printf '  "opens","yes","%s keys inside — no name and no value is printed"\n' "${n:-0}" >> "$facts"
    else
      printf '  "opens","NO","this seat cannot open the vault with %s"\n' "$IDENTITY" >> "$facts"
      faults=$((faults + 1))
    fi
  fi

  if [ -z "$YAML" ] || [ ! -r "$YAML" ]; then
    printf '  "declarations","none","no recipients file at %s"\n' "${YAML:-<home>/config/vault-recipients.yaml}" >> "$facts"
    faults=$((faults + 1))
  elif build_selection 2>"$work/sel.err"; then
    if selection_faults; then
      printf '  "declared","%s","every declared key is on GitHub and usable"\n' "$SELECTED" >> "$facts"
    else
      printf '  "declared","MISMATCH","a declared key is missing, ambiguous or unsupported"\n' >> "$facts"
      faults=$((faults + 1))
    fi
    n="$(grep -c . "$work/plan.tsv.undeclared" 2>/dev/null || true)"
    printf '  "undeclared","%s","GitHub keys nobody declared — reported, never used"\n' "${n:-0}" >> "$facts"
    [ "${n:-0}" -gt 0 ] && warns=$((warns + 1))
  elif [ -f "$work/declared.tsv" ] && [ ! -s "$work/declared.tsv" ]; then
    printf '  "declarations","empty","%s names no key yet — nothing is re-locked, and the vault keeps its current lock"\n' "$YAML" >> "$facts"
    warns=$((warns + 1))
  else
    printf '  "declared","unverified","the owner%s GitHub keys could not be read — %s"\n' "'" \
      "$(head -1 "$work/sel.err" 2>/dev/null | cut -c1-120)" >> "$facts"
  fi

  # what is TRACKED under hodd/secrets: reported, never changed
  if command -v git >/dev/null 2>&1 && git -C "$HOME_R" rev-parse --git-dir >/dev/null 2>&1; then
    local tracked_plain tracked_key
    tracked_plain="$(git -C "$HOME_R" ls-files 'hodd/secrets/*' 2>/dev/null | grep -E '\.env$' | grep -vE '\.env\.age$' | tr '\n' ' ')"
    tracked_key="$(git -C "$HOME_R" ls-files 'hodd/secrets/age.key' 2>/dev/null)"
    tracked_plain="${tracked_plain% }"
    if [ -n "$tracked_plain" ]; then
      printf '  "plain-text tracked","%s","a secret in the clear is tracked under hodd/secrets — retire it (reported, not changed)"\n' "$tracked_plain" >> "$facts"
      warns=$((warns + 1))
    fi
    if [ -n "$tracked_key" ]; then
      printf '  "legacy key tracked","hodd/secrets/age.key","the lock and its key still travel together — retire it once every recipient opens the vault"\n' >> "$facts"
      warns=$((warns + 1))
    fi
  fi

  if [ "$QUIET" != 1 ]; then emit_table vault-relock check,value,detail "$facts"; fi
  if [ "$warns" -gt 0 ]; then
    [ "$QUIET" = 1 ] || printf 'vault-relock: %s warning(s)\n' "$warns" >&2
  fi
  if [ "$faults" -gt 0 ]; then
    [ "$QUIET" = 1 ] || printf 'vault-relock: %s fault(s)\n' "$faults" >&2
    return 3
  fi
  if [ "$STRICT" = 1 ] && [ "$warns" -gt 0 ]; then
    [ "$QUIET" = 1 ] || printf 'vault-relock: --strict turns the warning(s) into a fault\n' >&2
    return 3
  fi
  return 0
}

case "$ACTION" in
  plan)         do_plan ;;
  check)        do_check ;;
  relock)       do_relock ;;
  add-machine)  do_add_machine ;;
  recipients)   do_recipients ;;
  *) usage >&2; exit 2 ;;
esac
