#!/usr/bin/env bash
# graphics-lib.sh — the machine's graphics truth, shared by every reader.
#
# One question drove this file: can a desktop shell RENDER? The old sense was
# blind to GPUs (omarchy-sense recorded monitors, never drivers), and the only
# GPU guard read mem_info_vram_total — a file Intel's i915 does not expose, so
# on an Intel + discrete hybrid the guard never fired and Electron's GPU
# process died for want of a fence (2026-09-24: SIGABRT in
# dri_create_fence_fd ← EGL_CreateSyncKHR, with gbm_pixmap_wayland SCANOUT
# failures and 108 GiB of RAM untouched — a GPU-buffer fault, not an OOM).
#
# This lib classifies the DRM devices (integrated / discrete / hybrid), reads
# GTT where the driver exposes it, names the drivers and their versions, and
# decides the EFFECTIVE policy the shells will use: software rendering on a
# fragile hybrid unless a verified acceleration override exists. Source-safe;
# functions only. The installer consumes it (omarchy-sense records the block),
# Eir reports it, and scripts/electron.sh obeys the policy it derives.
#
#   graphics_drm_cards         one line per card: <card> <driver> <name> <render> <vram_mib> <gtt_mib>
#   graphics_class             integrated | discrete | other   (a card, by driver + VRAM)
#   graphics_hybrid_fragile    0/1 — a shared-memory iGPU beside a discrete one
#   graphics_policy            gpu | software — the effective policy the shells use
#   graphics_block [--json]    the whole truth as one block
set -u

have_g() { command -v "$1" >/dev/null 2>&1; }

graphics_drm_cards() {  # one line per real CARD — driver symlink truth; connectors (cardN-DP-x) are
  # not cards and are filtered by their PCI link (a connector links to ../../cardN,
  # a card to 0000:bb:dd.f)
  local card drv name render vram gtt v link
  for card in /sys/class/drm/card[0-9]*; do
    [ -e "$card" ] || continue
    link="$(readlink "$card/device" 2>/dev/null || true)"
    case "$link" in *:* ) ;; *) continue ;; esac     # only PCI-linked cards
    [ -e "$card/device/driver" ] || continue
    drv="$(basename "$(readlink "$card/device/driver" 2>/dev/null || true)" 2>/dev/null || true)"
    [ -n "$drv" ] || continue
    name="$(sed -n 's/^DRIVER=//p' "$card/device/uevent" 2>/dev/null | head -1)"
    [ -n "$name" ] || name="$drv"
    render="-"
    local rdev r
    for r in /sys/class/drm/renderD*; do
      [ -e "$r" ] || continue
      rdev="$(readlink -f "$r" 2>/dev/null || true)"
      # a renderD's PCI device is its grandparent dir; match it to the card's device
      if [ -n "$rdev" ] \
         && [ "$(dirname "$(dirname "$rdev")")" = "$(readlink -f "$card/device" 2>/dev/null || true)" ]; then
        render="$(basename "$r")"; break
      fi
    done
    vram=0; gtt=0
    if [ -r "$card/device/mem_info_vram_total" ]; then
      v=$(( $(cat "$card/device/mem_info_vram_total" 2>/dev/null || echo 0) / 1048576 ))
      [ "$v" -gt 0 ] && vram=$v
    fi
    if [ -r "$card/device/mem_info_gtt_total" ]; then
      v=$(( $(cat "$card/device/mem_info_gtt_total" 2>/dev/null || echo 0) / 1048576 ))
      [ "$v" -gt 0 ] && gtt=$v
    fi
    printf '%s %s %s %s %s %s\n' "$(basename "$card")" "$drv" "$name" "$render" "$vram" "$gtt"
  done
}

# A card's class, from the driver and its declared VRAM. i915 is always the
# integrated half; amdgpu is integrated when it declares no real VRAM (an APU
# exports its carve-out, a dGPU its frames); nvidia is discrete. Any other
# driver is a display that does not render 3D — never classified as a rival.
graphics_class() {  # <driver> <vram_mib>
  case "${1-}" in
    i915)   printf 'integrated' ;;
    nvidia) printf 'discrete' ;;
    amdgpu) [ "${2:-0}" -ge 1024 ] && printf 'discrete' || printf 'integrated' ;;
    *)      printf 'other' ;;
  esac
}

# The fragile case: a shared-memory integrated device coexisting with a
# discrete one. The iGPU's command/buffer path is where Electron's GPU process
# died (2026-09-24) — Intel exposes no mem_info_vram_total and i915 exposes no
# GTT file, so the mere PRESENCE of i915 beside a dGPU is the signal; GTT is
# read where amdgpu exposes it as the supporting number, never as the gate.
graphics_hybrid_fragile() {
  local drv vram dis=0 intgr=0 cls
  while read -r _card drv _name _render vram _gtt; do
    [ -n "$drv" ] || continue
    cls="$(graphics_class "$drv" "${vram:-0}")"
    case "$cls" in integrated) intgr=1 ;; discrete) dis=1 ;; esac
  done < <(graphics_drm_cards)
  [ "$intgr" = 1 ] && [ "$dis" = 1 ]
}

# The EFFECTIVE policy the shells will use — one decision, several readers
# (scripts/electron.sh, the recorders, Eir). YMIR_DESKTOP_DISABLE_GPU is the
# human's override: 1 forces software, 0 forces the GPU path, unset (auto)
# trusts the classification.
graphics_policy() {
  case "${YMIR_DESKTOP_DISABLE_GPU:-auto}" in
    1|true|yes) printf 'software' ;;
    0|false|no) printf 'gpu' ;;
    *) if graphics_hybrid_fragile; then printf 'software'; else printf 'gpu'; fi ;;
  esac
}

graphics_versions() {  # what the drivers are, from the package manager where known
  if have_g pacman; then
    local p v
    for p in mesa libdrm nvidia intel-media-driver; do
      v="$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')"
      [ -n "$v" ] && printf '%s %s\n' "$p" "$v"
    done
  fi
}

# The whole truth in one block. --json for the recorders; default prints
# short TOON lines for the eye. Assembled in bash — the card loop is the one
# source, JSON and TOON are two renderings of it.
graphics_block() {
  local json=0
  [ "${1-}" = "--json" ] && json=1
  local card drv name render vram gtt cls cards_json="" display classification
  local anyint=0 anydis=0 display_pci
  while read -r card drv name render vram gtt; do
    [ -n "$card" ] || continue
    cls="$(graphics_class "$drv" "${vram:-0}")"
    case "$cls" in integrated) anyint=1 ;; discrete) anydis=1 ;; esac
    cards_json="$cards_json{"
    cards_json="$cards_json\"card\":\"$card\",\"driver\":\"$drv\",\"name\":\"$name\","
    cards_json="$cards_json\"render\":\"${render:--}\",\"vram_mib\":$([ "${vram:-0}" -gt 0 ] && echo "$vram" || echo 0),"
    cards_json="$cards_json\"gtt_mib\":$([ "${gtt:-0}" -gt 0 ] && echo "$gtt" || echo 0),"
    cards_json="$cards_json\"class\":\"$cls\"},"
  done < <(graphics_drm_cards)
  cards_json="${cards_json%,}"
  # The display card: fb0's owning PCI device maps to the card that scans it out.
  display=""
  display_pci="$(basename "$(readlink /sys/class/graphics/fb0/device 2>/dev/null || true)" 2>/dev/null || true)"
  if [ -n "$display_pci" ]; then
    local c dl
    for c in /sys/class/drm/card[0-9]*; do
      [ -e "$c" ] || continue
      dl="$(readlink "$c/device" 2>/dev/null || true)"
      case "$dl" in *"$display_pci"*) display="$(basename "$c")"; break ;; esac
    done
    [ -n "$display" ] || display="$display_pci"
  fi
  if [ "$anyint" = 1 ] && [ "$anydis" = 1 ]; then classification="hybrid"
  elif [ "$anyint" = 1 ]; then classification="integrated"
  elif [ "$anydis" = 1 ]; then classification="discrete"
  else classification="other"; fi
  policy="$(graphics_policy)"
  frag=no; graphics_hybrid_fragile && frag=yes
  if [ "$json" = 1 ]; then
    printf '{"cards":[%s],"display":"%s","classification":"%s","fragile_hybrid":"%s","policy":"%s","versions":{' "$cards_json" "$display" "$classification" "$frag" "$policy"
    local first=1 p v
    while read -r p v; do
      [ -n "$p" ] || continue
      [ "$first" = 1 ] || printf ','
      printf '"%s":"%s"' "$p" "$v"; first=0
    done < <(graphics_versions)
    printf '}}'
  else
    printf 'graphics[1]{classification,display,policy,fragile}:\n  "%s","%s","%s","%s"\n' "$classification" "$display" "$policy" "$frag"
    while read -r card drv name render vram gtt; do
      printf '  "%s","%s","%s",%s,%s\n' "$card" "$drv" "$name" "${render:--}" "$([ "${vram:-0}" -gt 0 ] && echo "$vram" || echo 0)"
    done < <(graphics_drm_cards)
  fi
}