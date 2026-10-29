#!/usr/bin/env bash
# perf.sh - measurement, not adjectives.
#
# `rea bench` samples the things a desktop customisation can actually ruin:
# shell memory, shell CPU at idle, system memory, boot time and extension
# count. Run it before installing and again afterwards; `rea bench --compare`
# prints the delta. Nothing here claims to measure frame timing - that needs a
# GPU profiler, and docs/performance.md says how.

REA_BENCH_SAMPLE_SECONDS="${REA_BENCH_SAMPLE_SECONDS:-20}"

_bench_shell_pid() { pgrep -u "$(id -u)" -x gnome-shell 2>/dev/null | head -n1; }

# _bench_proc_cpu <pid> <seconds> - average CPU% of one process over a window.
_bench_proc_cpu() {
  local pid="$1" secs="$2" tick t0 t1 c0 c1
  tick="$(getconf CLK_TCK 2>/dev/null || echo 100)"
  [[ -r "/proc/$pid/stat" ]] || { printf '0'; return 0; }
  c0="$(awk '{print $14 + $15}' "/proc/$pid/stat" 2>/dev/null)" || c0=0
  t0="$(date +%s)"
  sleep "$secs"
  [[ -r "/proc/$pid/stat" ]] || { printf '0'; return 0; }
  c1="$(awk '{print $14 + $15}' "/proc/$pid/stat" 2>/dev/null)" || c1=0
  t1="$(date +%s)"
  awk -v c0="$c0" -v c1="$c1" -v t0="$t0" -v t1="$t1" -v tk="$tick" \
    'BEGIN{d=t1-t0; if(d<=0){print 0; exit} printf "%.2f", ((c1-c0)/tk)/d*100}'
}

_bench_rss_mb() {
  local pid="$1"
  [[ -r "/proc/$pid/status" ]] || { printf '0'; return 0; }
  awk '/VmRSS/{printf "%.1f", $2/1024}' "/proc/$pid/status" 2>/dev/null || printf '0'
}

_bench_mem_used_mb() {
  [[ -r /proc/meminfo ]] || { printf '0'; return 0; }
  awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d", (t-a)/1024}' /proc/meminfo
}

_bench_boot_ms() {
  have systemd-analyze || { printf '0'; return 0; }
  # "Startup finished in 3.1s (kernel) + 12.4s (userspace) = 15.5s"
  systemd-analyze 2>/dev/null | awk '
    /Startup finished/ {
      for (i = 1; i <= NF; i++)
        if ($i ~ /^=$/) { v = $(i+1); gsub(/s$/, "", v); printf "%d", v * 1000; exit }
    }' || printf '0'
}

_bench_gpu_note() {
  if have glxinfo; then
    glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer/{print $2; exit}'
  else
    printf 'unknown (install mesa-utils for renderer detail)'
  fi
}

# rea_bench_run <label>
rea_bench_run() {
  local label="${1:-sample}" pid rss cpu mem boot ext file renderer

  pid="$(_bench_shell_pid)"
  if [[ -z "$pid" ]]; then
    rea_warn "gnome-shell is not running as this user; shell metrics will be zero"
    pid=0
  fi

  rea_info "Sampling for ${REA_BENCH_SAMPLE_SECONDS}s - leave the desktop idle"
  rss="$([[ $pid != 0 ]] && _bench_rss_mb "$pid" || printf '0')"
  cpu="$([[ $pid != 0 ]] && _bench_proc_cpu "$pid" "$REA_BENCH_SAMPLE_SECONDS" || printf '0')"
  rss="$([[ $pid != 0 ]] && _bench_rss_mb "$pid" || printf '0')"   # re-read after the window
  mem="$(_bench_mem_used_mb)"
  boot="$(_bench_boot_ms)"
  ext="${REA_SYS_EXT_COUNT:-0}"
  renderer="$(_bench_gpu_note)"

  mkdir -p "$REA_BENCH_DIR"
  file="$REA_BENCH_DIR/$(date +%Y%m%d-%H%M%S)-$label.json"
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would write $file"
  else
    cat >"$file" <<JSON
{
  "label": "$(json_escape "$label")",
  "captured_at": "$(date -Is)",
  "rea_version": "$REA_VERSION",
  "profile": "$(json_escape "${REA_PROFILE_NAME:-none}")",
  "session_type": "$(json_escape "${REA_SYS_SESSION_TYPE:-unknown}")",
  "gnome_shell": "$(json_escape "${REA_SYS_SHELL_VER:-unknown}")",
  "renderer": "$(json_escape "$renderer")",
  "sample_seconds": $REA_BENCH_SAMPLE_SECONDS,
  "metrics": {
    "shell_rss_mb": $rss,
    "shell_cpu_idle_pct": $cpu,
    "system_mem_used_mb": $mem,
    "boot_ms": $boot,
    "enabled_extensions": $ext
  }
}
JSON
  fi

  rea_head "Measurements ($label)"
  printf '  %-26s %s MB\n'  "gnome-shell memory"    "$rss"
  printf '  %-26s %s %%\n'  "gnome-shell CPU, idle" "$cpu"
  printf '  %-26s %s MB\n'  "system memory in use"  "$mem"
  printf '  %-26s %s ms\n'  "last boot"             "$boot"
  printf '  %-26s %s\n'     "enabled extensions"    "$ext"
  printf '  %-26s %s\n'     "renderer"              "$renderer"
  [[ "$REA_DRY_RUN" == "1" ]] || rea_dim "saved: $file"
}

rea_bench_list() {
  [[ -d "$REA_BENCH_DIR" ]] || return 0
  ls -1 "$REA_BENCH_DIR"/*.json 2>/dev/null
}

# _bench_get <file> <metric>
_bench_get() {
  sed -n "s/.*\"$2\": *\([0-9.]*\).*/\1/p" "$1" | head -n1
}

rea_bench_compare() {
  local first last m a b
  first="$(rea_bench_list | head -n1)"
  last="$(rea_bench_list | tail -n1)"
  if [[ -z "$first" || "$first" == "$last" ]]; then
    rea_warn "Need at least two samples. Run 'rea bench before', install, then 'rea bench after'."
    return 1
  fi

  rea_head "Before and after"
  printf '  %-26s %12s %12s %12s\n' "metric" "$(basename "$first" .json | cut -c17-)" \
    "$(basename "$last" .json | cut -c17-)" "change"
  for m in shell_rss_mb shell_cpu_idle_pct system_mem_used_mb boot_ms enabled_extensions; do
    a="$(_bench_get "$first" "$m")"; b="$(_bench_get "$last" "$m")"
    [[ -n "$a" && -n "$b" ]] || continue
    awk -v n="$m" -v a="$a" -v b="$b" \
      'BEGIN{d=b-a; s=(d>0?"+":""); printf "  %-26s %12s %12s %12s\n", n, a, b, s d}'
  done
  rea_say ""
  rea_dim "samples: $REA_BENCH_DIR"
}
