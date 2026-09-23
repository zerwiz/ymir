#!/usr/bin/env bash
# npm-token-seat.sh — seat the NPM_TOKEN into the vault BY PATH (stdin, never
# a transcript or a file). Then: bin/npm-publish.sh publishes.
set -u
HOME_ROOT="${BROKK_HOME:-$HOME/Documents/ymirhome}"
ENV="$HOME_ROOT/hodd/secrets/platform.env"
AGE="$HOME_ROOT/hodd/secrets/age.key"
tok="$(cat)"
[ -n "$tok" ] || { echo "error: pipe the token on stdin" >&2; exit 2; }
umask 077
age -d -i "$AGE" "$ENV.age" > "$ENV" 2>/dev/null || { echo "error: cannot decrypt the vault" >&2; exit 1; }
sed -i '/^NPM_TOKEN=/d' "$ENV"
printf 'NPM_TOKEN=%s\n' "$tok" >> "$ENV"
age -e -i "$AGE" -o "$ENV.age.new" "$ENV" && mv "$ENV.age.new" "$ENV.age"
rm -f "$ENV"
echo "npm token seated in the vault (by path, never shown)"
