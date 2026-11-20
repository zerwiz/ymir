#!/usr/bin/env bash
# app-kind.sh — what kind of window an app declares (electron | tauri), and which launcher opens it, on THIS platform.
#
# Read from the app's own app.yaml, never from a table here, so the drawer door (bin/desktop/ymir-app) names no
# app to learn its kind. Sourced; three functions:
#
#   app_kind <app> <home>            → electron | tauri   (default electron — the window every app has today)
#   app_launcher <home> <kind>       → the absolute path of the launcher app.yaml names for that kind here
#   app_window_class <home>          → app.yaml's window_class (empty when it declares none)
#
# The app.yaml shape (both forms of `kind:` are accepted):
#
#   kind: electron                     # one kind on every platform
#   kind: { default: electron, linux: tauri }      # or per platform (also as an indented block)
#   launch:
#     tauri:
#       linux:   tauri/launch.sh       # relative to the app's home
#       macos:   tauri/launch.sh
#       windows: tauri/launch.ps1
#
# A trial without editing the app: YMIR_APP_KIND_<APP>=tauri (or YMIR_APP_KIND=tauri for one launch).
# Platform: linux | macos | windows, from uname (YMIR_APP_PLATFORM overrides, for tests).

app_platform() {
  if [ -n "${YMIR_APP_PLATFORM:-}" ]; then printf '%s' "$YMIR_APP_PLATFORM"; return; fi
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf macos ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) printf windows ;;
    *) printf linux ;;
  esac
}

# _app_yaml_get <file> <dotted.key> — the subset of YAML app.yaml uses: nested blocks by indent, and one-line
# flow maps ({ a: b, c: d }). Prints a scalar, or nothing. Never evaluates anything it reads.
_app_yaml_get() {
  [ -r "$1" ] || return 1
  python3 - "$1" "$2" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2].split(".")
def scalar(v):
    v = re.sub(r"\s+#.*$", "", v).strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1]
    return v
def flow(v):
    v = scalar(v)
    if not (v.startswith("{") and v.endswith("}")):
        return None
    out = {}
    for part in v[1:-1].split(","):
        if ":" in part:
            k, x = part.split(":", 1)
            out[k.strip()] = scalar(x)
    return out
tree, stack = {}, [(-1, None)]
stack[0] = (-1, tree)
for raw in open(path, encoding="utf-8"):
    if not raw.strip() or raw.lstrip().startswith("#") or raw.lstrip().startswith("-"):
        continue
    m = re.match(r"^(\s*)([A-Za-z0-9_.-]+)\s*:\s*(.*)$", raw.rstrip("\n"))
    if not m:
        continue
    ind, k, v = len(m.group(1)), m.group(2), m.group(3)
    while stack and stack[-1][0] >= ind:
        stack.pop()
    parent = stack[-1][1]
    if not isinstance(parent, dict):
        continue
    if scalar(v) == "":
        parent[k] = {}
        stack.append((ind, parent[k]))
    else:
        f = flow(v)
        parent[k] = f if f is not None else scalar(v)
node = tree
for k in key:
    if not isinstance(node, dict) or k not in node:
        sys.exit(1)
    node = node[k]
if isinstance(node, dict):
    sys.exit(2)
print(node)
PY
}

app_kind() {  # <app> <home>
  local app="$1" home="$2" var k plat
  var="YMIR_APP_KIND_$(printf '%s' "$app" | tr '[:lower:]-' '[:upper:]_')"
  k="${!var:-${YMIR_APP_KIND:-}}"
  if [ -z "$k" ]; then
    plat="$(app_platform)"
    k="$(_app_yaml_get "$home/app.yaml" "kind.$plat" 2>/dev/null)" \
      || k="$(_app_yaml_get "$home/app.yaml" kind.default 2>/dev/null)" \
      || k="$(_app_yaml_get "$home/app.yaml" kind 2>/dev/null)" || k=""
  fi
  case "$k" in
    tauri) printf tauri ;;
    electron|'') printf electron ;;
    *) printf 'app-kind: %s declares an unknown kind "%s" (electron | tauri)\n' "$app" "$k" >&2; return 1 ;;
  esac
}

app_launcher() {  # <home> <kind>
  local home="$1" kind="$2" rel plat
  plat="$(app_platform)"
  rel="$(_app_yaml_get "$home/app.yaml" "launch.$kind.$plat" 2>/dev/null)" \
    || rel="$(_app_yaml_get "$home/app.yaml" "launch.$kind" 2>/dev/null)" || {
      printf 'app-kind: %s/app.yaml names no %s launcher for %s\n' "$home" "$kind" "$plat" >&2; return 1; }
  case "$rel" in /*) ;; *) rel="$home/$rel" ;; esac
  [ -f "$rel" ] || { printf 'app-kind: the %s launcher is missing: %s\n' "$kind" "$rel" >&2; return 1; }
  printf '%s' "$rel"
}

app_window_class() {  # <home>
  _app_yaml_get "$1/app.yaml" window_class 2>/dev/null || true
}
