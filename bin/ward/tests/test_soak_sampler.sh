#!/usr/bin/env bash
# test_soak_sampler.sh — the leak ledger's proof, without a real leak (plan 286 P0).
#
# No systemd, no GPU, no /proc: a planted process tree, a planted cgroup, a stand-in systemctl
# and a stand-in nvidia-smi. What is asserted is the ROW — every number the plan asks for is in
# it, taken from the source that owns it, and a target that cannot be measured says so instead of
# quietly reporting zero.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N="$HERE/../soak-sampler.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

# ── a planted process tree ──────────────────────────────────────────────────────
mkpid() {  # <pid> <ppid> <state> <start> <rss_kb> <fds> <inotify-watches> <cmdline>
  local pid="$1" ppid="$2" state="$3" start="$4" rss="$5" nfd="$6" nwatch="$7" cmd="$8"
  local d="$T/proc/$pid"
  mkdir -p "$d/fd" "$d/fdinfo"
  # /proc/<pid>/stat: field 3 state, 4 ppid, 22 starttime → after ")" index 0 is state, 19 start.
  {
    printf '%s (planted) %s %s 100 100 0 -1 4194560 100 0 0 0 1 1 0 0 20 0 1 0 %s 100000 200' \
      "$pid" "$state" "$ppid" "$start"
  } > "$d/stat"
  printf 'Name:\tplanted\nVmRSS:\t   %s kB\n' "$rss" > "$d/status"
  printf 'Max open files            %s              %s              files\n' "$rss" "$rss" > "$d/limits"
  local i=0
  while [ "$i" -lt "$nfd" ]; do : > "$d/fd/$i"; i=$((i + 1)); done
  if [ "$nwatch" -gt 0 ]; then
    : > "$d/fdinfo/9"
    i=0
    while [ "$i" -lt "$nwatch" ]; do
      printf 'inotify wd:%x ino:1 sdev:1 mask:2\n' "$i" >> "$d/fdinfo/9"
      i=$((i + 1))
    done
  fi
  if [ -n "$cmd" ]; then printf '%s\0' $cmd > "$d/cmdline"; else : > "$d/cmdline"; fi
}
# svc-a: main 100 + child 101, and a zombie grandchild 102 (a leaked child that never got reaped)
mkpid 100 1 S 5000 12345 3 2 "/usr/bin/fake-service --serve"
mkpid 101 100 S 5001 2048 2 0 "fake-service --worker"
mkpid 102 101 Z 5002 0 0 0 ""
# bilskirnir: an app root and its renderer
mkpid 200 1 S 6000 40000 5 1 "/opt/electron /home/x/apps/bilskirnir/start.js"
mkpid 201 200 S 6001 30000 4 0 "/opt/electron --type=renderer"

mkdir -p "$T/cg/user.slice/app.slice/svc-a.service" "$T/cg/user.slice/app.slice/svc-b.service"
printf '100\n101\n102\n' > "$T/cg/user.slice/app.slice/svc-a.service/cgroup.procs"
: > "$T/cg/user.slice/app.slice/svc-b.service/cgroup.procs"

cat > "$T/nvidia-smi" <<'S'
#!/usr/bin/env bash
printf '100, 512\n'
printf '201, 300\n'
S
chmod +x "$T/nvidia-smi"

# ── stand-in systemctl: three units, one of them the distribution's ─────────────
cat > "$T/systemctl" <<S
#!/usr/bin/env bash
case "\$*" in
  *list-units*)
    printf 'svc-a.service loaded active running Planted A\n'
    printf 'svc-b.service loaded failed failed Planted B\n'
    printf 'svc-c.service loaded active exited Planted C (a one-shot that is over)\n'
    printf 'vendor.service loaded active running The distribution'"'"'s own\n'
    exit 0 ;;
  *show*)
    cat <<'B'
Id=svc-a.service
ActiveState=active
SubState=running
MainPID=100
NRestarts=2
ControlGroup=/user.slice/app.slice/svc-a.service
Result=success
ExecMainStatus=0
ExecMainStartTimestamp=Fri 2026-11-14 01:00:00 CET
FragmentPath=$HOME/.config/systemd/user/svc-a.service
Restart=on-failure

Id=svc-b.service
ActiveState=failed
SubState=failed
MainPID=0
NRestarts=4
ControlGroup=/user.slice/app.slice/svc-b.service
Result=exit-code
ExecMainStatus=1
ExecMainStartTimestamp=Fri 2026-11-14 02:00:00 CET
FragmentPath=$HOME/.config/systemd/user/svc-b.service
Restart=on-failure

Id=svc-c.service
ActiveState=active
SubState=exited
MainPID=0
NRestarts=0
ControlGroup=/user.slice/app.slice/svc-c.service
Result=success
ExecMainStatus=0
ExecMainStartTimestamp=Fri 2026-11-14 02:10:00 CET
FragmentPath=$HOME/.config/systemd/user/svc-c.service
Restart=no

Id=vendor.service
ActiveState=active
SubState=running
MainPID=1
NRestarts=0
ControlGroup=/system.slice/vendor.service
Result=success
ExecMainStatus=0
ExecMainStartTimestamp=Fri 2026-11-14 02:10:00 CET
FragmentPath=/usr/lib/systemd/system/vendor.service
Restart=always
B
    exit 0 ;;
  *) exit 0 ;;
esac
S
chmod +x "$T/systemctl"

printf 'bilskirnir\n' > "$T/apps.txt"

Y() {  # run the sampler inside the planted world
  env YMIR_HOME="$T/home" \
      YMIR_SOAK_PROC="$T/proc" YMIR_SOAK_CGROUP="$T/cg" \
      YMIR_SOAK_SYSTEMCTL="$T/systemctl" YMIR_NVIDIA_SMI="$T/nvidia-smi" \
      YMIR_SOAK_APP_REGISTRY="$T/apps.txt" \
      bash "$N" "$@" 2>&1
}
mkdir -p "$T/home"

out="$(Y pass --dry-run --no-ward)"
printf '%s\n' "$out" > "$T/out1"

# ── the service rows ───────────────────────────────────────────────────────────
row_a="$(printf '%s\n' "$out" | grep '"name":"svc-a.service"')"
[ -n "$row_a" ] && ok "a running service has a row" || no "no row for svc-a: $out"
for f in rss_kb fds inotify_watches pids zombies gpu_mib restarts fd_limit; do
  grep -q "\"$f\":" <<<"$row_a" || no "svc-a row lacks $f"
done
grep -q '"rss_kb":14393' <<<"$row_a" && ok "RSS is the cgroup's whole sum (12345+2048)" \
  || no "rss: $row_a"
grep -q '"pids":3' <<<"$row_a" && ok "the cgroup's process count is measured" || no "pids: $row_a"
grep -q '"fds":5' <<<"$row_a" && ok "fds are summed over the tree (3+2)" || no "fds: $row_a"
grep -q '"inotify_watches":2' <<<"$row_a" && ok "inotify watches are counted from fdinfo" || no "watches: $row_a"
grep -q '"zombies":1' <<<"$row_a" && ok "the zombie child is named as one" || no "zombies: $row_a"
grep -q '"gpu_mib":512' <<<"$row_a" && ok "GPU memory is the process's own MiB" || no "gpu: $row_a"
grep -q '"restarts":2' <<<"$row_a" && ok "restarts come from systemd's own counter" || no "restarts: $row_a"

row_b="$(printf '%s\n' "$out" | grep '"name":"svc-b.service"')"
grep -q '"state":"failed"' <<<"$row_b" && ok "a failed unit keeps its row (it has restarted)" \
  || no "failed unit: ${row_b:-missing}"
grep -q '"result":"exit-code"' <<<"$row_b" && ok "a failed unit carries its result" || no "result: $row_b"

printf '%s\n' "$out" | grep -q '"name":"svc-c.service"' && no "a finished one-shot should not be sampled" \
  || ok "a finished one-shot (active/exited, no process) is left out"
printf '%s\n' "$out" | grep -q '"name":"vendor.service"' && no "a distribution unit should be left out" \
  || ok "the distribution's own unit is not the house's to sample"

row_app="$(printf '%s\n' "$out" | grep '"name":"bilskirnir"')"
grep -q '"kind":"app"' <<<"$row_app" && ok "the app registry's app has a row" || no "app row: ${row_app:-missing}"
grep -q '"pids":2' <<<"$row_app" && ok "an app row counts its renderer too" || no "app pids: $row_app"
grep -q '"gpu_mib":300' <<<"$row_app" && ok "an app's GPU memory is its renderer's" || no "app gpu: $row_app"

pass_row="$(printf '%s\n' "$out" | grep '"kind":"pass"')"
grep -q '"kind":"pass"' <<<"$pass_row" && ok "each pass closes with a pass row" || no "no pass row"
grep -q '"gpu_source":"nvidia-smi"' <<<"$pass_row" && ok "the pass says where the GPU numbers came from" \
  || no "gpu_source: $pass_row"

# ── the ledger is where the plan says, and a dry run writes it nowhere ─────────
[ -e "$T/home/state/soak/services" ] && no "a dry run must not write the ledger" || ok "a dry run writes nothing"

Y pass --no-ward > "$T/out2" || no "a real pass failed: $(cat "$T/out2")"
ledger="$T/home/state/soak/services/$(date +%F).jsonl"
[ -s "$ledger" ] && ok "the ledger is <home>/state/soak/services/<date>.jsonl" || no "no ledger at $ledger"
grep -q '"name":"svc-a.service"' "$ledger" 2>/dev/null && ok "the real pass wrote the service rows" \
  || no "ledger lacks the service row"

# ── an app that restarts gets its generation counted, and a registry that cannot
#    be read leaves a row that says so (never a silent zero) ────────────────────
gen1="$(grep '"name":"bilskirnir"' "$ledger" | tail -n1)"
mkpid 200 1 S 7000 40000 5 1 "/opt/electron /home/x/apps/bilskirnir/start.js"
Y pass --no-ward > /dev/null 2>&1
gen2="$(grep '"name":"bilskirnir"' "$ledger" | tail -n1)"
grep -q '"restarts":1' <<<"$gen2" && ok "the app's main process changing is one restart" \
  || no "generation did not move: $gen1 → $gen2"

env YMIR_HOME="$T/home" YMIR_SOAK_PROC="$T/proc" YMIR_SOAK_CGROUP="$T/cg" \
    YMIR_SOAK_SYSTEMCTL="$T/systemctl" YMIR_NVIDIA_SMI="$T/nvidia-smi" \
    YMIR_SOAK_APP_REGISTRY="$T/does-not-exist" \
    bash "$N" pass --dry-run --no-ward 2>&1 | grep -q '"name":"app-registry","state":"unreadable"' \
  && ok "an unreadable app registry is a row, not silence" || no "no discovery row for a missing registry"

# ── the config reaches the pass ────────────────────────────────────────────────
mkdir -p "$T/home/config"
printf 'sample:\n  include_vendor: true\n  scope: user\n' > "$T/home/config/soak.yaml"
Y pass --dry-run --no-ward | grep -q '"name":"vendor.service"' \
  && ok "sample.include_vendor brings the vendor unit in, by config" \
  || no "include_vendor from the config had no effect"

exit $fail
