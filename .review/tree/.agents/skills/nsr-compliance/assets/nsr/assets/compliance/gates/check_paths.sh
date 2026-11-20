#!/usr/bin/env bash
# Gate: enforce RELATIVE filepaths only. Rejects absolute paths in scripts/configs.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

violations=0
for ext in sh py yaml yml json; do
  for f in $(find . -type f -name "*.$ext" -not -path './.git/*' -not -path './.compliance/telemetry/*'); do
    while IFS= read -r line; do
      case "$line" in
        /*|C:*|D:*) echo "[check_paths] ABSOLUTE PATH: $f -> $line"; violations=1 ;;
      esac
    done < "$f"
  done
done

[ "$violations" -ne 0 ] && { echo "[check_paths] FAIL"; exit 1; }
echo "[check_paths] PASS"
exit 0