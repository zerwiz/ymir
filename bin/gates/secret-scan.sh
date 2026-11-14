#!/usr/bin/env bash
# secret-scan.sh — the secret scan's door, and the generator for the operator's own rules.
#
# The scan has two halves, and they live in two places on purpose (RULES/04):
#
#   THE SHARED RULES    the key shapes every project shares — cloud keys, provider
#                       tokens, private-key headers. They are gitleaks' own defaults and
#                       they are named in the repository's `.gitleaks.toml` (`useDefault`).
#
#   THE OPERATOR'S OWN  a person, a client, a company, a mail domain, a host name, a
#                       user name. Private — so the repository carries NO word of them.
#                       They live in the operator's home, and this door turns them into
#                       gitleaks rules AT RUN TIME, into a config that EXTENDS the
#                       repository's own and lives beside the list, never in the tree.
#
# Two halves of one question, and this door is the gate's half (see the note on the twice-daily
# sweep in `docs/features/secret-scanning.md`):
#
#   THE GATE (this door)     at the moment a change is OFFERED — pre-commit over the staged diff,
#                            CI over every PR and main and the whole history. It FAILS the change.
#   THE CLOCK (the sweep)    twice a day on the server's clock, over the tree's content, in
#                            categories (secret · address · person · business · private record);
#                            it QUEUES and seats a triage errand, and never blocks.
#
# Both read the same home lists (below), so a word is defined in one place and enforced at two
# moments.
#
# A stranger who installs Ymir gets the shared half from the tree and the second half
# from their own list — or nothing, cleanly said, when they keep none. A CI run has no
# home, so it scans the shared half: CI proves no credential SHAPE ships, and the
# operator's own machine proves no WORD of his ships.
#
# Usage:
#   bin/gates/secret-scan.sh config            write the operator config, print its path
#   bin/gates/secret-scan.sh config --print    print the generated config instead
#   bin/gates/secret-scan.sh status            what a scan would use (counts, never words)
#   bin/gates/secret-scan.sh tree              scan the tree AND the whole git history
#   bin/gates/secret-scan.sh dir               scan the working tree only (no history)
#   bin/gates/secret-scan.sh staged            scan what is staged (a pre-commit check)
#
# Environment:
#   YMIR_HOME             the operator's home (resolved by bin/vault/hoard-lib.sh)
#   YMIR_SECRET_SCAN_OUT  where the generated config is written
#                         (default <home>/state/gitleaks/gitleaks.toml)
#   YMIR_GITLEAKS         the gitleaks binary (default: `gitleaks` on PATH)
#   YMIR_SECRET_SCAN_CONFIG  a config to use exactly as given (the pre-commit hook names
#                         the shared `.gitleaks.toml`, so a commit is judged on shapes)
#
# Exit: 0 clean · 1 a finding · 2 usage · 3 gitleaks is absent.
#
# The deny list ships as a template: hodd/identity/public-deny.txt.example. This door
# never prints a word from it — a count and a path only, because a gate that prints the
# word it hid has re-created the leak (RULES/04, RULES/18).
set -u

VERSION="1.0.0"
SELF="${BASH_SOURCE[0]}"
ROOT="$(cd "$(dirname "$SELF")/../.." && pwd)"
BASE_CONFIG="$ROOT/.gitleaks.toml"

usage() { sed -n '2,34p' "$SELF" | sed 's/^# \{0,1\}//'; }

# ── the home, through its one resolver ───────────────────────────────────────────────────────
home=""
if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1090
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  if declare -f ymir_home_root >/dev/null 2>&1; then
    ymir_home_root home || home=""
  fi
fi
[ -n "$home" ] || home="${YMIR_HOME:-}"

# The deny list, read from the home, in the order the house keeps it. All three are read when they
# exist, because three tools now ask the same question and must not diverge: plan 287 seats
# `hodd/identity/public-deny.txt` for the whole-tree audit, the NDA gate keeps
# `hodd/identity/nda-names.txt`, and the public ward has kept `hodd/security/operator-words.txt`
# since 2026-10-01. The union heals the names without asking any owner to move a file, and the
# bare-word lists (the last two) are read as `name:`.
DENY_CANDIDATES=(
  "$home/hodd/identity/public-deny.txt"
  "$home/hodd/identity/nda-names.txt"
  "$home/hodd/security/operator-words.txt"
)

deny_sources() {  # the lists that EXIST on this machine, one path per line
  local f
  for f in "${DENY_CANDIDATES[@]}"; do [ -r "$f" ] && printf '%s\n' "$f"; done
}

# An entry is `<kind>:<word>`, and the KIND is the difference between two rules (plan 287 §6):
#
#   name: · domain:   judged ANYWHERE as a whole word — a person, a client, a company or a
#                     mail domain is a finding wherever it appears.
#   host: · user:     judged only where the word is USED as one — after `@`, `//`, `/home/`,
#                     `host=`, `host:` or `ssh`, or before a port, a dot-local (mDNS) name or a tailnet
#                     suffix. The lore and the fleet share names (a subsystem named for a
#                     figure is the craft; the box named for him is the operator's life), so
#                     a host rule that fired anywhere would bury real findings under craft.
#
# A bare word is read as `name:`. The strongest kind wins when a word appears in both lists.
deny_entries() {  # "<rank><TAB><kind><TAB><word>" per line: rank 2 = anywhere, 1 = host position
  local f
  for f in "${DENY_CANDIDATES[@]}"; do
    [ -r "$f" ] || continue
    sed -e 's/#.*//' "$f"
  done | awk '
    { gsub(/^[ \t]+|[ \t]+$/, "", $0); if ($0 == "") next
      kind = "name"; word = $0
      i = index($0, ":")
      if (i > 0) { kind = substr($0, 1, i - 1); word = substr($0, i + 1) }
      gsub(/^[ \t]+|[ \t]+$/, "", word)
      if (word == "" || length(word) < 3) next
      k = tolower(kind); w = tolower(word)
      rank = (k == "host" || k == "user") ? 1 : 2
      if (rank == 2) k = (k == "domain") ? "domain" : "name"; else k = "host"
      if (!(w in seen) || rank > seen[w]) { seen[w] = rank; kindof[w] = k }
    }
    END { for (w in seen) printf "%s\t%s\t%s\n", seen[w], kindof[w], w }
  ' | sort -t "$(printf '\t')" -k3,3
}

deny_count() { deny_entries | wc -l | tr -d ' '; }

# A word is used INSIDE a regex, so only the characters that would change a regex' meaning
# are escaped; the word itself is never altered.
regex_escape() { printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g'; }

out_config() {  # [path] — the config a scan writes: this tree's rules, plus the home's
  local n=0 rank kind word re
  printf '%s\n\n' \
    "# GENERATED by bin/gates/secret-scan.sh — do not edit, do not commit." \
    "# It carries the operator's own words, so it lives in the home, never in the tree."
  printf '[extend]\npath = "%s"\n\n' "$BASE_CONFIG"
  printf '%s\n' \
    "# One rule per denied word. A rule id is positional, never the word, so a finding" \
    "# names a rule number and a file — never the word the rule is hiding."
  while IFS="$(printf '\t')" read -r rank kind word || [ -n "${word-}" ]; do
    [ -n "${word-}" ] || continue
    n=$((n + 1))
    re=$(regex_escape "$word")
    printf '\n[[rules]]\nid = "operator-%s-%s"\n' "$kind" "$n"
    printf 'description = "a word the operator keeps out of the public repository"\n'
    if [ "$rank" = "1" ]; then
      printf "regex = '''(?i)((@|//|/home/|host= *|host: *|ssh +)%s\\\\b|\\\\b%s\\\\.(local|ts\\\\.net)\\\\b|\\\\b%s:[0-9]{2,5}\\\\b)'''\n" "$re" "$re" "$re"
    else
      printf "regex = '''(?i)\\\\b%s\\\\b'''\n" "$re"
    fi
    printf 'tags = ["operator-word"]\n'
  done <<EOF
$(deny_entries)
EOF
}

gitleaks_bin() { printf '%s' "${YMIR_GITLEAKS:-gitleaks}"; }

require_gitleaks() {
  command -v "$(gitleaks_bin)" >/dev/null 2>&1 && return 0
  printf 'secret-scan: gitleaks is not on PATH — nothing was scanned.\n' >&2
  printf 'secret-scan: fetch the one binary from github.com/gitleaks/gitleaks/releases,\n' >&2
  printf 'secret-scan: or name one with YMIR_GITLEAKS=/path/to/gitleaks.\n' >&2
  exit 3
}

generated_path() { printf '%s' "${YMIR_SECRET_SCAN_OUT:-$home/state/gitleaks/gitleaks.toml}"; }

write_config() {  # [dest] — write the generated config, print the path it wrote
  local dest=${1:-}
  [ -n "$dest" ] || dest="$(generated_path)"
  mkdir -p "$(dirname "$dest")" || { printf 'secret-scan: cannot create %s\n' "$(dirname "$dest")" >&2; exit 1; }
  out_config >"$dest" || { printf 'secret-scan: cannot write %s\n' "$dest" >&2; exit 1; }
  printf '%s\n' "$dest"
}

config_for_scan() {  # the home's config when there is a list; the tree's otherwise
  # A caller may name a config exactly: the pre-commit hook does, so a commit is judged on the
  # SHARED shapes and never on the operator's word list (that half is the whole-tree audit's
  # work, and a commit that merely touches a file with older history would be refused for it).
  if [ -n "${YMIR_SECRET_SCAN_CONFIG:-}" ]; then printf '%s' "$YMIR_SECRET_SCAN_CONFIG"; return 0; fi
  if [ "$(deny_count)" -gt 0 ]; then
    write_config 2>/dev/null || printf '%s' "$BASE_CONFIG"
  else
    printf '%s' "$BASE_CONFIG"
  fi
}

CMD="${1-}"; [ $# -gt 0 ] && shift
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;

  config)
    [ -r "$BASE_CONFIG" ] || { printf 'secret-scan: no %s in this tree\n' "$BASE_CONFIG" >&2; exit 1; }
    if [ "$(deny_count)" -eq 0 ]; then
      printf 'secret-scan: no deny list on this machine — nothing to generate.\n'
      printf 'secret-scan: the scan runs on the shared rules alone (%s).\n' "$BASE_CONFIG"
      printf 'secret-scan: a list belongs at %s (template: hodd/identity/public-deny.txt.example).\n' "${DENY_CANDIDATES[0]}"
      exit 0
    fi
    case "${1-}" in
      --print) out_config ;;
      "")      write_config
               printf 'secret-scan: %s word(s) from %s list(s), extending %s\n' \
                 "$(deny_count)" "$(deny_sources | wc -l | tr -d ' ')" "$(basename "$BASE_CONFIG")" >&2 ;;
      *)       write_config "$1" ;;
    esac
    ;;

  status)
    require_gitleaks
    printf 'secret_scan[7]{fact,value}:\n'
    printf '  "gitleaks","%s"\n' "$("$(gitleaks_bin)" version 2>/dev/null | head -n1)"
    printf '  "shared rules","%s"\n' "$BASE_CONFIG"
    if [ -n "$(deny_sources)" ]; then
      printf '  "deny list","%s"\n' "$(deny_sources | head -n1)"
      printf '  "deny sources","%s"\n' "$(deny_sources | wc -l | tr -d ' ')"
      printf '  "operator words","%s"\n' "$(deny_count)"
      printf '  "generated config","%s"\n' "$(generated_path)"
    else
      printf '  "deny list","none — the scan runs on the shared rules alone"\n'
      printf '  "generated config","%s"\n' "$BASE_CONFIG"
    fi
    printf '  "history","every commit on every branch (gitleaks git --all)"\n'
    ;;

  tree)
    require_gitleaks
    cfg="$(config_for_scan)"
    printf 'secret-scan: %s · history + tree\n' "$cfg" >&2
    "$(gitleaks_bin)" git "$ROOT" --config "$cfg" --no-banner --redact \
      --log-opts="--all" --max-target-megabytes 20 "$@"
    ;;

  dir)
    require_gitleaks
    cfg="$(config_for_scan)"
    printf 'secret-scan: %s · tree only\n' "$cfg" >&2
    "$(gitleaks_bin)" dir "$ROOT" --config "$cfg" --no-banner --redact \
      --max-target-megabytes 20 "$@"
    ;;

  staged)
    require_gitleaks
    cfg="$(config_for_scan)"
    "$(gitleaks_bin)" git "$ROOT" --config "$cfg" --no-banner --redact --staged "$@"
    ;;

  *)
    printf 'secret-scan: unknown command `%s`\n' "$CMD" >&2
    usage >&2
    exit 2
    ;;
esac
