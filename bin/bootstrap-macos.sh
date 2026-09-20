#!/usr/bin/env bash
# bootstrap-macos.sh — give a macOS operator the Linux host Ymir needs.
#
# Ymir's core is portable, but what it installs is a Linux runtime (service
# scripts, apt/deb package work, /proc and systemd-adjacent assumptions in the
# Omarchy-first layer). So macOS gets its Linux host the way Windows does — a
# VM. This raises one with **Lima** (lightest, brew-installable, no GUI) and then
# hands the install to bin/ymir-install.sh *inside* the VM.
#
# It is a bootstrap, not a hack: the VM is the Ymir host, and the Mac is the
# desktop in front of it.
#
# Usage:
#   bin/bootstrap-macos.sh                 # raise the VM + install Ymir in it
#   bin/bootstrap-macos.sh --check         # report readiness, change nothing
#   bin/bootstrap-macos.sh --name ymir     # VM name (default: ymir)
#   bin/bootstrap-macos.sh --repo <url>    # clone source (default: this checkout's origin)
#   bin/bootstrap-macos.sh --version
#
# Gated on its host (Rule 05): off macOS it skips cleanly and points at
# bin/host-sense.sh.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VM="ymir"; CHECK=0; REPO=""
# The VM's home is resolved, never assumed (Rule 07). Inside the Lima VM the
# operator is `ubuntu`, but that is the VM's fact, not this script's — it comes
# from env with one documented default, and the guest user is overridable so a
# host that provisions a different user still works. The directory name is the
# distro's ONE default (`Documents/ymirhome`, owned by bin/hoard-lib.sh) — a
# guest path, so it stays absolute with the guest user as its variable.
VM_USER="${YMIR_VM_USER:-ubuntu}"
VM_HOME="${YMIR_HOME:-/home/${VM_USER}/Documents/ymirhome}"

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --name) VM="${2:-ymir}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --version|-v|-V) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/bootstrap-macos.sh [--check] [--name VM] [--repo URL]\n' "$1" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# ── host gate ────────────────────────────────────────────────────────────────
if [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
  printf 'macos-bootstrap[1]{step,status,detail}:\n'
  printf '  "layer","SKIP","not macOS — this layer applies on a Mac; run bin/host-sense.sh for THIS machine"\n'
  exit 0
fi

BREW=no; have brew && BREW=yes
LIMA=no; have limactl && LIMA=yes
ARCH="$(uname -m 2>/dev/null || printf unknown)"

if [ -z "$REPO" ] && git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
  REPO="$(git -C "$ROOT" remote get-url origin)"
fi

if [ "$CHECK" = 1 ]; then
  printf 'macos-bootstrap[5]{step,status,detail}:\n'
  printf '  "host","OK","macOS %s (%s)"\n' "$(sw_vers -productVersion 2>/dev/null || printf '?')" "$ARCH"
  printf '  "homebrew","%s","%s"\n' "$([ "$BREW" = yes ] && printf OK || printf MISSING)" \
    "$([ "$BREW" = yes ] && printf 'brew present' || printf 'install Homebrew first: https://brew.sh')"
  printf '  "lima","%s","%s"\n' "$([ "$LIMA" = yes ] && printf OK || printf 'MISSING (installable: brew install lima)')" \
    "$([ "$LIMA" = yes ] && printf 'limactl present' || printf 'the VM engine has not been installed yet')"
  printf '  "repo","%s","%s"\n' "$([ -n "$REPO" ] && printf OK || printf MISSING)" "${REPO:-no origin remote and no --repo given}"
  printf '  "next","%s","%s"\n' "$([ "$BREW" = yes ] && [ -n "$REPO" ] && printf 'ready' || printf 'resolve the rows above')" \
    "bin/bootstrap-macos.sh"
  exit 0
fi

# ── 1. the VM engine ─────────────────────────────────────────────────────────
if [ "$LIMA" = no ]; then
  if [ "$BREW" = no ]; then
    printf 'error: Homebrew is required to install Lima\nhelp: https://brew.sh, then re-run bin/bootstrap-macos.sh\n' >&2
    exit 1
  fi
  echo "installing Lima (the Linux VM engine)…" >&2
  brew install lima >/dev/null 2>&1 || { printf 'error: brew install lima failed\nhelp: run it by hand to see why\n' >&2; exit 1; }
fi

# ── 2. the Ubuntu host ───────────────────────────────────────────────────────
if limactl list --format '{{.Name}}' 2>/dev/null | grep -qx "$VM"; then
  echo "VM '$VM' already exists — starting it" >&2
  limactl start --name="$VM" >/dev/null 2>&1 || true
else
  echo "raising Ubuntu in Lima as '$VM' (downloads an image; this takes a while)…" >&2
  limactl start --name="$VM" --mount-writable --tty=false template://ubuntu >/dev/null 2>&1 \
    || { printf 'error: could not raise the VM\nhelp: limactl start --name=%s template://ubuntu\n' "$VM" >&2; exit 1; }
fi

# ── 3. Ymir inside it ────────────────────────────────────────────────────────
if [ -n "$REPO" ]; then
  echo "installing Ymir inside '$VM'…" >&2
  limactl shell "$VM" -- bash -lc "set -e
    command -v git >/dev/null 2>&1 || sudo apt-get update -qq && sudo apt-get install -y -qq git
    [ -d \"\$HOME/Ymir/.git\" ] || git clone '$REPO' \"\$HOME/Ymir\"
    cd \"\$HOME/Ymir\" && git pull --ff-only || true
    YMIR_HOME='$VM_HOME' bin/ymir-install.sh --yes" >&2 \
    || { printf 'error: the in-VM install failed\nhelp: limactl shell %s -- bash -lc "cd ~/Ymir && bin/ymir-install.sh"\n' "$VM" >&2; exit 1; }
fi

printf 'macos-bootstrap[3]{step,status,detail}:\n'
printf '  "vm","OK","%s (Lima)"\n' "$VM"
printf '  "engine","OK","%s"\n' "$([ "$LIMA" = yes ] && printf 'limactl (pre-existing)' || printf 'limactl (just installed)')"
printf '  "ymir","%s","%s"\n' "$([ -n "$REPO" ] && printf OK || printf SKIP)" \
  "$([ -n "$REPO" ] && printf 'installed inside the VM' || printf 'no repo to clone — run: limactl shell %s -- bash -lc "cd ~/Ymir && bin/ymir-install.sh --yes"' "$VM")"
printf '\nnext: limactl shell %s            # the Linux host\n      open http://127.0.0.1:3888/  # Hlidskjalf, forwarded by Lima\n' "$VM"
