#!/usr/bin/env bash
# ymir-platform.sh — the portability layer.
#
# Ymir must run on Linux, macOS and Windows (through WSL2 or MSYS/Git Bash).
# GNU coreutils are not guaranteed: BSD `readlink` has no `-f`, BSD `stat` uses
# `-f` not `-c`, macOS `date` has no `%N`, and `nproc`, `setsid`, `flock` and
# `/proc` do not exist there at all. This file is the ONE place that knows a
# platform difference; every other script calls these functions.
#
# Sourced, never executed:   . "$ROOT/bin/ymir-platform.sh"
# It defines functions only and has no side effects.
#
# Convention: every function is `ymir_*`, prints to stdout, and never exits the
# caller. A capability that is genuinely absent returns a non-zero status so the
# caller can decide; a capability with a sane fallback always succeeds.

# ── platform ─────────────────────────────────────────────────────────────────

ymir_os() {  # linux | macos | wsl | msys | unknown
  case "$(uname -s 2>/dev/null)" in
    Linux*)
      if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        printf 'wsl'
      else
        printf 'linux'
      fi ;;
    Darwin*)               printf 'macos' ;;
    MINGW*|MSYS*|CYGWIN*)  printf 'msys' ;;
    *)                     printf 'unknown' ;;
  esac
}

ymir_has_gnu() {  # true when GNU-style tool flags are available
  case "$(ymir_os)" in linux|wsl|msys) return 0 ;; *) return 1 ;; esac
}

# ── basic tools ──────────────────────────────────────────────────────────────

ymir_nproc() {  # CPU count
  if command -v nproc >/dev/null 2>&1; then nproc
  elif command -v sysctl >/dev/null 2>&1 && sysctl -n hw.ncpu >/dev/null 2>&1; then sysctl -n hw.ncpu
  elif command -v getconf >/dev/null 2>&1; then getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4'
  else printf '4'; fi
}

ymir_readlink_f() {  # resolve symlinks; BSD readlink has no -f
  [ $# -ge 1 ] || return 1
  local p=$1
  if readlink -f -- "$p" >/dev/null 2>&1; then readlink -f -- "$p"; return 0; fi
  # Portable resolution: follow one link at a time, keeping the result absolute.
  local dir base target hops=0
  case "$p" in /*) : ;; *) p="$PWD/$p" ;; esac
  while [ -L "$p" ] && [ "$hops" -lt 40 ]; do
    hops=$((hops+1))
    dir=$(dirname "$p"); base=$(basename "$p")
    target=$(readlink "$p") || break
    case "$target" in /*) p="$target" ;; *) p="$dir/$target" ;; esac
  done
  # normalise . and .. lexically
  local resolved
  resolved=$(printf '%s' "$p" | awk -F/ '{
    n=0; for (i=1;i<=NF;i++) { if ($i==""||$i==".") continue; if ($i=="..") { if (n>0) n--; continue } a[++n]=$i }
    out=""; for (i=1;i<=n;i++) out=out"/"a[i]; if (out=="") out="/"; print out }')
  # Mirror GNU -f: every component but the last must exist, or the call fails
  # and prints nothing. Callers rely on that to detect a dangling link.
  if [ ! -d "$(dirname "$resolved")" ]; then return 1; fi
  printf '%s' "$resolved"
}

ymir_epoch_ns() {  # high-resolution epoch for timing (BSD date has no %N)
  local s n
  s=$(date +%s 2>/dev/null) || s=0
  n=$(date +%N 2>/dev/null)
  case "$n" in ''|*[!0-9]*) n=000000000 ;; esac
  printf '%s%s' "$s" "$n"
}

ymir_realpath_dir() {  # directory of the running script, resolved
  local src=${1:-${BASH_SOURCE[0]}}
  dirname "$(ymir_readlink_f "$src" 2>/dev/null || printf '%s' "$src")"
}

# ── stat: GNU -c vs BSD -f ───────────────────────────────────────────────────

ymir_stat_mtime() {  # epoch seconds
  if ymir_has_gnu; then stat -c %Y -- "$1" 2>/dev/null
  else stat -f %m -- "$1" 2>/dev/null; fi
}

ymir_stat_size() {   # bytes
  if ymir_has_gnu; then stat -c %s -- "$1" 2>/dev/null
  else stat -f %z -- "$1" 2>/dev/null; fi
}

ymir_stat_id() {     # "<device>:<inode>" — identity of a file
  if ymir_has_gnu; then stat -c '%d:%i' -- "$1" 2>/dev/null
  else stat -f '%d:%i' -- "$1" 2>/dev/null; fi
}

ymir_stat_birth() {  # birth/creation time as epoch seconds, or 0 when unknown
  local b=''
  if ymir_has_gnu; then
    b=$(stat -c %W -- "$1" 2>/dev/null)
  else
    b=$(stat -f %B -- "$1" 2>/dev/null)   # macOS: %B is birth time
  fi
  case "$b" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$b" ;; esac
}

ymir_stat_mode() {   # "file" | "dir" | "link" | "other"
  local f
  if ymir_has_gnu; then f=$(stat -c %F -- "$1" 2>/dev/null)
  else f=$(stat -f %HT -- "$1" 2>/dev/null); fi
  case "$f" in
    *directory*)                printf 'dir' ;;
    *symbolic*|*link*)          printf 'link' ;;
    *regular*|*"regular file"*) printf 'file' ;;
    '')                         printf 'other' ;;
    *)                          printf 'other' ;;
  esac
}

# ── processes ────────────────────────────────────────────────────────────────

ymir_pid_alive() {  # 0 when the pid exists
  [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null
}

ymir_pid_cmdline() {  # the command line of a pid, one line; empty when gone
  local pid=${1:-}
  [ -n "$pid" ] || return 1
  if [ -r "/proc/$pid/cmdline" ]; then
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null
  else
    ps -o command= -p "$pid" 2>/dev/null     # works on macOS and BSD
  fi
}

ymir_pid_matches() {  # 0 when the pid is alive AND its cmdline contains the mark
  local pid=${1:-} mark=${2:-}
  ymir_pid_alive "$pid" || return 1
  [ -n "$mark" ] || return 0
  ymir_pid_cmdline "$pid" 2>/dev/null | grep -q -- "$mark"
}

ymir_detach() {  # run a command detached from this shell's lifetime
  # setsid where available (Linux/WSL); MSYS has it; macOS does not.
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@" < /dev/null &
  else
    nohup "$@" < /dev/null > /dev/null 2>&1 &
  fi
  printf '%s' "$!"
}

# ── locking: flock vs a portable mkdir lock ─────────────────────────────────

ymir_lock() {  # <lockfile> <cmd...> — run cmd under an exclusive lock, or fail
  local lock=$1; shift
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$lock" 2>/dev/null || return 1
    flock -n 9 || return 1
    "$@"; local rc=$?
    exec 9>&- 2>/dev/null || true
    return $rc
  fi
  # Portable fallback: mkdir is atomic on every filesystem we care about.
  local d="${lock}.d"
  mkdir "$d" 2>/dev/null || return 1
  "$@"; local rc=$?
  rmdir "$d" 2>/dev/null || true
  return $rc
}

# ── services: systemd (Linux) vs launchd (macOS) vs nothing ─────────────────

ymir_service_backend() {  # systemd | launchd | none
  if command -v systemctl >/dev/null 2>&1 && systemctl --user >/dev/null 2>&1; then printf 'systemd'
  elif command -v launchctl >/dev/null 2>&1; then printf 'launchd'
  else printf 'none'; fi
}

ymir_service_active() {  # <name> -> 0 when running
  case "$(ymir_service_backend)" in
    systemd) systemctl --user is-active --quiet "$1" 2>/dev/null ;;
    launchd) launchctl list 2>/dev/null | grep -q -- "$1" ;;
    *)       return 1 ;;
  esac
}

# ── GPUs: report what exists, without assuming NVIDIA ───────────────────────

ymir_gpu_name() {  # best-effort device name, or empty
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1
  elif command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi --showproductname 2>/dev/null | head -2 | tr '\n' ' '
  elif [ "$(ymir_os)" = macos ]; then
    printf 'Apple Silicon (unified memory)'
  else
    printf ''
  fi
}

ymir_gpu_mem_used() {  # MiB in use, or "?" when unknown
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 || printf '?'
  elif command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi --showmemuse 2>/dev/null | grep -oE '[0-9]+' | head -1 || printf '?'
  else
    printf '?'
  fi
}

ymir_llama_server() {  # locate a llama-server without assuming a path
  local c
  for c in "${LLAMA_SERVER:-}" llama-server; do
    [ -n "$c" ] || continue
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  for c in /opt/homebrew/bin/llama-server /usr/local/bin/llama-server; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# ── paths ────────────────────────────────────────────────────────────────────

ymir_tmp() {  # a private temporary directory, on every OS
  local base=${TMPDIR:-${TEMP:-/tmp}}
  mktemp -d "${base%/}/ymir.XXXXXX" 2>/dev/null || mktemp -d
}

ymir_expand_tilde() {  # expand a leading ~ in a user-supplied path
  case "${1:-}" in
    '~')   printf '%s' "$HOME" ;;
    '~/'*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *)     printf '%s' "$1" ;;
  esac
}
