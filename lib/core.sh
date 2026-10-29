#!/usr/bin/env bash
# core.sh - logging, prompts, command execution, state paths.
# Sourced by the rea entrypoint; never executed directly.

REA_VERSION="1.0.0"

# ---------------------------------------------------------------- paths -----
REA_ROOT="${REA_ROOT:?REA_ROOT must be set by the entrypoint}"
REA_CONFIG_DIR="$REA_ROOT/config"
REA_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rea"
REA_SNAPSHOT_DIR="$REA_STATE_DIR/snapshots"
REA_BENCH_DIR="$REA_STATE_DIR/bench"
REA_LOG_DIR="$REA_STATE_DIR/logs"
REA_PREFS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/rea/rea.conf"

# ----------------------------------------------------------- behaviour ------
REA_DRY_RUN="${REA_DRY_RUN:-0}"   # 1 = print commands, change nothing
REA_ASSUME_YES="${REA_ASSUME_YES:-0}"
REA_NO_SUDO="${REA_NO_SUDO:-0}"
REA_LOG_FILE=""
REA_WARN_COUNT=0
REA_STEP_INDEX=0
REA_STEP_TOTAL=0

# ---------------------------------------------------------------- colour ----
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m';  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m';  C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m';  C_CYA=$'\033[36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""
fi

# ----------------------------------------------------------------- log ------
rea_log_init() {
  mkdir -p "$REA_LOG_DIR"
  REA_LOG_FILE="$REA_LOG_DIR/rea-$(date +%Y%m%d-%H%M%S).log"
  {
    echo "rea $REA_VERSION"
    echo "date: $(date -Is)"
    echo "argv: $*"
    echo "dry-run: $REA_DRY_RUN"
  } >"$REA_LOG_FILE" 2>/dev/null || REA_LOG_FILE=""
}

_rea_write_log() {
  [[ -n "$REA_LOG_FILE" ]] || return 0
  printf '%s %s\n' "$(date +%H:%M:%S)" "$1" >>"$REA_LOG_FILE" 2>/dev/null || true
}

rea_say()  { printf '%s\n' "$1"; _rea_write_log "$1"; }
rea_info() { printf '  %s\n' "$1"; _rea_write_log "INFO  $1"; }
rea_dim()  { printf '  %s%s%s\n' "$C_DIM" "$1" "$C_RESET" >&2; _rea_write_log "DIM   $1"; }
rea_ok()   { printf '  %s✓%s %s\n' "$C_GRN" "$C_RESET" "$1"; _rea_write_log "OK    $1"; }
rea_skip() { printf '  %s•%s %s\n' "$C_DIM" "$C_RESET" "$1"; _rea_write_log "SKIP  $1"; }
rea_warn() {
  REA_WARN_COUNT=$((REA_WARN_COUNT + 1))
  printf '  %s!%s %s\n' "$C_YEL" "$C_RESET" "$1" >&2
  _rea_write_log "WARN  $1"
}
rea_err()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; _rea_write_log "ERROR $1"; }
rea_die()  { rea_err "$1"; [[ -n "$REA_LOG_FILE" ]] && printf '  %slog: %s%s\n' "$C_DIM" "$REA_LOG_FILE" "$C_RESET" >&2; exit "${2:-1}"; }

rea_head() {
  printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"
  _rea_write_log "==== $1"
}

rea_rule() { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────" "$C_RESET"; }

rea_steps_total() { REA_STEP_TOTAL="$1"; REA_STEP_INDEX=0; }
rea_step() {
  REA_STEP_INDEX=$((REA_STEP_INDEX + 1))
  if ((REA_STEP_TOTAL > 0)); then
    printf '\n%s[%d/%d]%s %s%s%s\n' "$C_BLU" "$REA_STEP_INDEX" "$REA_STEP_TOTAL" \
      "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
  else
    printf '\n%s▸%s %s%s%s\n' "$C_BLU" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
  fi
  _rea_write_log "STEP  $1"
}

# ------------------------------------------------------------- execution ----
# run <cmd...>  - honours --dry-run, logs stdout/stderr, returns the exit code.
run() {
  _rea_write_log "RUN   $*"
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
    return 0
  fi
  if [[ -n "$REA_LOG_FILE" ]]; then
    "$@" >>"$REA_LOG_FILE" 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
}

# run_show <cmd...> - like run, but the user sees the output (long downloads).
run_show() {
  _rea_write_log "RUN*  $*"
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
    return 0
  fi
  "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ sudo ----
rea_sudo_available() {
  [[ "$REA_NO_SUDO" == "1" ]] && return 1
  have sudo || return 1
  return 0
}

# rea_sudo_warm <reason> - ask once, up front, explaining why.
rea_sudo_warm() {
  rea_sudo_available || return 1
  [[ "$REA_DRY_RUN" == "1" ]] && return 0
  if sudo -n true 2>/dev/null; then return 0; fi
  rea_info "Administrator password needed: $1"
  sudo -v || return 1
}

# ----------------------------------------------------------------- input ----
# ask_yes_no <question> <default y|n>
ask_yes_no() {
  local q="$1" def="${2:-y}" reply hint
  if [[ "$REA_ASSUME_YES" == "1" ]]; then
    _rea_write_log "ASK   $q -> auto-$def"
    [[ "$def" == "y" ]] && return 0 || return 1
  fi
  if [[ ! -t 0 ]]; then
    _rea_write_log "ASK   $q -> non-interactive default $def"
    [[ "$def" == "y" ]] && return 0 || return 1
  fi
  [[ "$def" == "y" ]] && hint="[Y/n]" || hint="[y/N]"
  while true; do
    printf '  %s %s ' "$q" "$hint"
    read -r reply || reply=""
    reply="${reply:-$def}"
    case "$(printf %s "$reply" | tr "[:upper:]" "[:lower:]")" in
      y|yes) _rea_write_log "ASK   $q -> yes"; return 0 ;;
      n|no)  _rea_write_log "ASK   $q -> no";  return 1 ;;
      *)     printf '  Please answer y or n.\n' ;;
    esac
  done
}

# ask_choice <prompt> <default-index> <label...> - echoes the 1-based index.
ask_choice() {
  local prompt="$1" def="$2"; shift 2
  local -a labels=("$@")
  local i reply
  if [[ "$REA_ASSUME_YES" == "1" || ! -t 0 ]]; then printf '%s' "$def"; return 0; fi
  printf '\n  %s\n' "$prompt"
  for i in "${!labels[@]}"; do
    printf '    %s%d%s) %s\n' "$C_BOLD" "$((i + 1))" "$C_RESET" "${labels[$i]}"
  done
  while true; do
    printf '  Choice [%s]: ' "$def"
    read -r reply || reply=""
    reply="${reply:-$def}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#labels[@]})); then
      printf '%s' "$reply"; return 0
    fi
    printf '  Enter a number between 1 and %d.\n' "${#labels[@]}"
  done
}

# ------------------------------------------------------------- utilities ----
# version_ge <a> <b> - true when version a >= version b (dotted numerics).
version_ge() {
  [[ "$1" == "$2" ]] && return 0
  local hi
  hi="$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)"
  [[ "$hi" == "$1" ]]
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/}"
  printf '%s' "$s"
}

# atomic_write <path> - writes stdin to path via a temp file (honours dry-run).
atomic_write() {
  local path="$1" tmp
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ write %s%s\n' "$C_DIM" "$path" "$C_RESET" >&2
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.rea.XXXXXX")"
  cat >"$tmp"
  mv -f "$tmp" "$path"
}

rea_prefs_load() { [[ -r "$REA_PREFS_FILE" ]] && . "$REA_PREFS_FILE"; return 0; }

rea_prefs_set() {
  local key="$1" val="$2" tmp
  mkdir -p "$(dirname "$REA_PREFS_FILE")"
  touch "$REA_PREFS_FILE"
  tmp="$(mktemp)"
  grep -v -E "^${key}=" "$REA_PREFS_FILE" >"$tmp" 2>/dev/null || true
  printf '%s=%q\n' "$key" "$val" >>"$tmp"
  mv -f "$tmp" "$REA_PREFS_FILE"
}
