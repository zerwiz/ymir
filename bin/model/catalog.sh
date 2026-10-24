#!/usr/bin/env bash
# catalog.sh — THE door to what this machine can serve.
#
# WHY THIS EXISTS (audit 2026-10-24, hodd/docs/audits/2026-10-24-the-model-knowledge-audited.md): pi already
# knows every model on the machine — `pi --list-models` answered 496 models across 5 providers, including the
# 30 opencode-go models — but nothing told an agent so at boot, and three other places kept their own opinion
# (model-resolve's table, the spawn guard's heuristic, and a prose provider table in AGENTS.md naming LM Studio
# on :1234, a door the Allfather retired). A session therefore rediscovered the catalogue by probing, and the
# answers disagreed. This door is the one answer.
#
#   catalog.sh              every model, TOON (provider · model · context · max-out)
#   catalog.sh --providers  the providers and how many models each serves
#   catalog.sh --has <provider/model>   exit 0 when the pair is listed, 1 when it is not
#   catalog.sh --check      exit 0 when the catalogue can be read at all; 1 (loudly) when it cannot
#
# The harness rule follows from the catalogue rather than from prose: a model pi lists is pi's to serve.
set -euo pipefail

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

read_catalog() {  # prints raw `pi --list-models`
  local out
  out="$(pi --list-models 2>/dev/null)" || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

toon_table() {
  read_catalog | awk '
    NR==1 { next }                       # the header line
    NF>=2 {
      n++; prov[n]=$1; model[n]=$2;
      ctx[n]=(NF>=3?$3:""); out[n]=(NF>=4?$4:"")
    }
    END {
      printf "catalog[%d]{provider,model,context,max_out}:\n", n
      for (i=1;i<=n;i++) printf "  \"%s\",\"%s\",\"%s\",\"%s\"\n", prov[i], model[i], ctx[i], out[i]
    }'
}

providers() {
  read_catalog | awk '
    NR==1 { next }
    NF>=2 { c[$1]++ }
    END {
      n=0; for (p in c) n++;
      printf "providers[%d]{provider,models}:\n", n
      for (p in c) printf "  \"%s\",\"%d\"\n", p, c[p]
    }' | ( read -r hdr; printf '%s\n' "$hdr"; sort )
}

case "${1:-}" in
  ""|list) toon_table ;;
  --providers) providers ;;
  --has)
    want="${2-}"
    [ -n "$want" ] || { printf 'error: --has needs <provider/model>\n' >&2; exit 2; }
    if read_catalog | awk -v w="$want" 'NR>1 && ($1"/"$2)==w {found=1} END{exit(found?0:1)}'; then
      printf 'has[1]{model,state}:\n  "%s","listed"\n' "$want"; exit 0
    fi
    printf 'has[1]{model,state}:\n  "%s","NOT IN THE CATALOG"\n' "$want"
    printf 'help: catalog.sh --providers — and a model this machine cannot serve is a refusal, not a guess\n' >&2
    exit 1 ;;
  --check)
    if read_catalog >/dev/null; then
      n="$(read_catalog | awk 'NR>1 && NF>=2' | wc -l)"
      printf 'check{catalog}:\n  pi catalogue readable                 PASS -> %s models\n' "$n"
      exit 0
    fi
    printf 'check{catalog}:\n  pi catalogue readable                 FAIL\n' >&2
    printf 'error: this machine cannot say what it can serve — `pi --list-models` answered nothing\n' >&2
    printf 'help: a machine that cannot answer this must say so loudly, never serve a guess\n' >&2
    exit 1 ;;
  -h|--help) usage ;;
  *) printf 'error: unknown verb %s\n' "$1" >&2; usage >&2; exit 2 ;;
esac
