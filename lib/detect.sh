#!/usr/bin/env bash
# detect.sh - read-only system audit. Sets REA_SYS_* globals, writes no state.

REA_DETECT_DONE=0

_d_gsettings() { have gsettings && gsettings get "$1" "$2" 2>/dev/null | sed "s/^'//;s/'$//" || printf 'n/a'; }

rea_detect_all() {
  [[ "$REA_DETECT_DONE" == "1" ]] && return 0

  # ---- distribution -------------------------------------------------------
  REA_SYS_OS_ID="unknown"; REA_SYS_OS_NAME="unknown"; REA_SYS_OS_VER="0"; REA_SYS_OS_CODENAME=""; REA_SYS_OS_LIKE=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    REA_SYS_OS_ID="$(. /etc/os-release && printf '%s' "${ID:-unknown}")"
    REA_SYS_OS_NAME="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")"
    REA_SYS_OS_VER="$(. /etc/os-release && printf '%s' "${VERSION_ID:-0}")"
    REA_SYS_OS_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
    REA_SYS_OS_LIKE="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
  fi

  REA_SYS_KERNEL="$(uname -r 2>/dev/null || printf 'unknown')"
  REA_SYS_ARCH="$(uname -m 2>/dev/null || printf 'unknown')"

  # ---- desktop / session --------------------------------------------------
  REA_SYS_DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
  REA_SYS_SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
  REA_SYS_SHELL_VER="none"
  if have gnome-shell; then
    REA_SYS_SHELL_VER="$(gnome-shell --version 2>/dev/null | awk '{print $3}')"
    [[ -n "$REA_SYS_SHELL_VER" ]] || REA_SYS_SHELL_VER="unknown"
  fi
  REA_SYS_SHELL_MAJOR="${REA_SYS_SHELL_VER%%.*}"
  [[ "$REA_SYS_SHELL_MAJOR" =~ ^[0-9]+$ ]] || REA_SYS_SHELL_MAJOR=0
  REA_SYS_IS_GNOME=0
  _desk_lc="$(printf %s "$REA_SYS_DESKTOP" | tr "[:upper:]" "[:lower:]")"; [[ "$_desk_lc" == *gnome* || "$_desk_lc" == *ubuntu* ]] && REA_SYS_IS_GNOME=1

  # ---- hardware -----------------------------------------------------------
  REA_SYS_CPU="unknown"; REA_SYS_CORES=0
  if [[ -r /proc/cpuinfo ]]; then
    REA_SYS_CPU="$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"
    REA_SYS_CORES="$(grep -c '^processor' /proc/cpuinfo)"
  fi
  REA_SYS_RAM_MB=0
  [[ -r /proc/meminfo ]] && REA_SYS_RAM_MB="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"

  REA_SYS_GPU="unknown"
  if have lspci; then
    REA_SYS_GPU="$(lspci 2>/dev/null | grep -E 'VGA compatible|3D controller|Display controller' \
      | sed 's/.*: //' | paste -sd '; ' - )"
  fi
  [[ -n "$REA_SYS_GPU" ]] || REA_SYS_GPU="unknown"

  REA_SYS_GPU_DRIVERS=""
  if [[ -d /sys/module ]]; then
    local m
    for m in i915 xe amdgpu radeon nvidia nvidia_drm nouveau virtio_gpu vmwgfx; do
      [[ -d "/sys/module/$m" ]] && REA_SYS_GPU_DRIVERS+="${REA_SYS_GPU_DRIVERS:+,}$m"
    done
  fi
  [[ -n "$REA_SYS_GPU_DRIVERS" ]] || REA_SYS_GPU_DRIVERS="none-detected"

  REA_SYS_MESA="unknown"
  have glxinfo && REA_SYS_MESA="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL version/{print $2; exit}')"
  [[ -n "$REA_SYS_MESA" ]] || REA_SYS_MESA="unknown"

  REA_SYS_BATTERY="no"
  compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1 && REA_SYS_BATTERY="yes"

  REA_SYS_TOUCHPAD="no"
  if [[ -r /proc/bus/input/devices ]]; then
    grep -qiE 'name=.*(touchpad|trackpad)' /proc/bus/input/devices && REA_SYS_TOUCHPAD="yes"
  fi

  # ---- displays -----------------------------------------------------------
  REA_SYS_OUTPUTS=""; REA_SYS_MONITOR_COUNT=0
  local card mode name
  for card in /sys/class/drm/card*-*/; do
    [[ -r "${card}status" ]] || continue
    [[ "$(cat "${card}status" 2>/dev/null)" == "connected" ]] || continue
    name="$(basename "${card%/}")"; name="${name#card*-}"
    mode="$(head -n1 "${card}modes" 2>/dev/null || true)"
    REA_SYS_OUTPUTS+="${REA_SYS_OUTPUTS:+, }${name}@${mode:-unknown}"
    REA_SYS_MONITOR_COUNT=$((REA_SYS_MONITOR_COUNT + 1))
  done
  [[ -n "$REA_SYS_OUTPUTS" ]] || REA_SYS_OUTPUTS="unknown"

  REA_SYS_TEXT_SCALE="$(_d_gsettings org.gnome.desktop.interface text-scaling-factor)"
  REA_SYS_FRACTIONAL="$(_d_gsettings org.gnome.mutter experimental-features)"

  # ---- current appearance -------------------------------------------------
  REA_SYS_GTK_THEME="$(_d_gsettings org.gnome.desktop.interface gtk-theme)"
  REA_SYS_ICON_THEME="$(_d_gsettings org.gnome.desktop.interface icon-theme)"
  REA_SYS_CURSOR_THEME="$(_d_gsettings org.gnome.desktop.interface cursor-theme)"
  REA_SYS_FONT="$(_d_gsettings org.gnome.desktop.interface font-name)"
  REA_SYS_MONO_FONT="$(_d_gsettings org.gnome.desktop.interface monospace-font-name)"
  REA_SYS_COLOR_SCHEME="$(_d_gsettings org.gnome.desktop.interface color-scheme)"
  REA_SYS_BUTTON_LAYOUT="$(_d_gsettings org.gnome.desktop.wm.preferences button-layout)"
  REA_SYS_SHELL_THEME="$(_d_gsettings org.gnome.shell.extensions.user-theme name)"
  REA_SYS_ANIMATIONS="$(_d_gsettings org.gnome.desktop.interface enable-animations)"

  # ---- extensions ---------------------------------------------------------
  REA_SYS_EXT_ENABLED=""
  if have gnome-extensions; then
    REA_SYS_EXT_ENABLED="$(gnome-extensions list --enabled 2>/dev/null | paste -sd ',' - )"
  fi
  REA_SYS_EXT_COUNT=0
  [[ -n "$REA_SYS_EXT_ENABLED" ]] && REA_SYS_EXT_COUNT="$(printf '%s' "$REA_SYS_EXT_ENABLED" | tr ',' '\n' | grep -c .)"

  # ---- tooling ------------------------------------------------------------
  REA_SYS_HAS_APT=0;      have apt-get && REA_SYS_HAS_APT=1
  REA_SYS_HAS_SNAP=0;     have snap && REA_SYS_HAS_SNAP=1
  REA_SYS_HAS_FLATPAK=0;  have flatpak && REA_SYS_HAS_FLATPAK=1
  REA_SYS_HOME_FREE_MB="$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
  [[ -n "$REA_SYS_HOME_FREE_MB" ]] || REA_SYS_HOME_FREE_MB=0

  # ---- conflicts ----------------------------------------------------------
  REA_SYS_CONFLICTS=""
  local ext
  for ext in ubuntu-dock@ubuntu.com dash-to-panel@jderose9.github.com \
             dash-to-dock@micxgx.gmail.com plank cairo-dock latte-dock; do
    case ",$REA_SYS_EXT_ENABLED," in
      *",$ext,"*) REA_SYS_CONFLICTS+="${REA_SYS_CONFLICTS:+, }extension:$ext" ;;
    esac
  done
  for ext in plank picom compton cairo-dock; do
    pgrep -x "$ext" >/dev/null 2>&1 && REA_SYS_CONFLICTS+="${REA_SYS_CONFLICTS:+, }process:$ext"
  done
  [[ -n "$REA_SYS_CONFLICTS" ]] || REA_SYS_CONFLICTS="none"

  REA_DETECT_DONE=1
}

# Blockers that make a full install unsafe. Echoes one reason per line.
rea_detect_blockers() {
  rea_detect_all
  local -a out=()
  if [[ "$REA_SYS_OS_ID" != "ubuntu" ]]; then
    if [[ "$REA_SYS_OS_LIKE" == *debian* || "$REA_SYS_OS_ID" == "debian" || "$REA_SYS_OS_ID" == "pop" || "$REA_SYS_OS_ID" == "linuxmint" ]]; then
      : # related enough; handled as a warning, not a blocker
    else
      out+=("Not an Ubuntu/Debian-family system (detected: $REA_SYS_OS_NAME).")
    fi
  fi
  [[ "$REA_SYS_IS_GNOME" == "1" ]] || out+=("Desktop is '$REA_SYS_DESKTOP', not GNOME. Rea targets GNOME Shell.")
  ((REA_SYS_SHELL_MAJOR >= 42)) || out+=("GNOME Shell $REA_SYS_SHELL_VER is older than 42, which Rea does not support.")
  ((REA_SYS_HOME_FREE_MB >= 500)) || out+=("Less than 500 MB free in \$HOME (${REA_SYS_HOME_FREE_MB} MB).")
  have curl || out+=("'curl' is required and not installed.")
  ((${#out[@]})) && printf '%s\n' "${out[@]}"
  return 0
}

rea_audit_print() {
  rea_detect_all
  local f="  %-22s %s\n"
  rea_head "System"
  printf "$f" "OS" "$REA_SYS_OS_NAME"
  printf "$f" "Kernel / arch" "$REA_SYS_KERNEL ($REA_SYS_ARCH)"
  printf "$f" "Desktop" "$REA_SYS_DESKTOP"
  printf "$f" "GNOME Shell" "$REA_SYS_SHELL_VER"
  printf "$f" "Session" "$REA_SYS_SESSION_TYPE"
  rea_head "Hardware"
  printf "$f" "CPU" "$REA_SYS_CPU (${REA_SYS_CORES} threads)"
  printf "$f" "Memory" "${REA_SYS_RAM_MB} MB"
  printf "$f" "GPU" "$REA_SYS_GPU"
  printf "$f" "Kernel GPU drivers" "$REA_SYS_GPU_DRIVERS"
  printf "$f" "OpenGL" "$REA_SYS_MESA"
  printf "$f" "Battery / touchpad" "$REA_SYS_BATTERY / $REA_SYS_TOUCHPAD"
  printf "$f" "Displays" "$REA_SYS_OUTPUTS"
  printf "$f" "Text scale" "$REA_SYS_TEXT_SCALE"
  printf "$f" "Mutter experimental" "$REA_SYS_FRACTIONAL"
  rea_head "Current appearance"
  printf "$f" "GTK theme" "$REA_SYS_GTK_THEME"
  printf "$f" "Shell theme" "$REA_SYS_SHELL_THEME"
  printf "$f" "Icons / cursors" "$REA_SYS_ICON_THEME / $REA_SYS_CURSOR_THEME"
  printf "$f" "Interface font" "$REA_SYS_FONT"
  printf "$f" "Monospace font" "$REA_SYS_MONO_FONT"
  printf "$f" "Colour scheme" "$REA_SYS_COLOR_SCHEME"
  printf "$f" "Window buttons" "$REA_SYS_BUTTON_LAYOUT"
  printf "$f" "Animations" "$REA_SYS_ANIMATIONS"
  rea_head "Extensions & packaging"
  printf "$f" "Enabled extensions" "${REA_SYS_EXT_COUNT}"
  if [[ -n "$REA_SYS_EXT_ENABLED" ]]; then
    printf '%s' "$REA_SYS_EXT_ENABLED" | tr ',' '\n' | sed 's/^/      - /'
  fi
  printf "$f" "apt / snap / flatpak" "$REA_SYS_HAS_APT / $REA_SYS_HAS_SNAP / $REA_SYS_HAS_FLATPAK"
  printf "$f" "Free space in \$HOME" "${REA_SYS_HOME_FREE_MB} MB"
  rea_head "Potential conflicts"
  printf "$f" "Detected" "$REA_SYS_CONFLICTS"

  local blockers
  blockers="$(rea_detect_blockers)"
  rea_head "Readiness"
  if [[ -z "$blockers" ]]; then
    rea_ok "No blockers found. 'rea install' can proceed."
  else
    while IFS= read -r line; do [[ -n "$line" ]] && rea_err "$line"; done <<<"$blockers"
  fi
}

rea_audit_json() {
  rea_detect_all
  cat <<JSON
{
  "rea_version": "$REA_VERSION",
  "captured_at": "$(date -Is)",
  "os": { "id": "$(json_escape "$REA_SYS_OS_ID")", "name": "$(json_escape "$REA_SYS_OS_NAME")", "version": "$(json_escape "$REA_SYS_OS_VER")", "codename": "$(json_escape "$REA_SYS_OS_CODENAME")" },
  "kernel": "$(json_escape "$REA_SYS_KERNEL")",
  "arch": "$(json_escape "$REA_SYS_ARCH")",
  "desktop": "$(json_escape "$REA_SYS_DESKTOP")",
  "session_type": "$(json_escape "$REA_SYS_SESSION_TYPE")",
  "gnome_shell": "$(json_escape "$REA_SYS_SHELL_VER")",
  "hardware": {
    "cpu": "$(json_escape "$REA_SYS_CPU")",
    "threads": $REA_SYS_CORES,
    "ram_mb": $REA_SYS_RAM_MB,
    "gpu": "$(json_escape "$REA_SYS_GPU")",
    "gpu_drivers": "$(json_escape "$REA_SYS_GPU_DRIVERS")",
    "opengl": "$(json_escape "$REA_SYS_MESA")",
    "battery": "$REA_SYS_BATTERY",
    "touchpad": "$REA_SYS_TOUCHPAD",
    "monitors": $REA_SYS_MONITOR_COUNT,
    "outputs": "$(json_escape "$REA_SYS_OUTPUTS")"
  },
  "appearance": {
    "gtk_theme": "$(json_escape "$REA_SYS_GTK_THEME")",
    "shell_theme": "$(json_escape "$REA_SYS_SHELL_THEME")",
    "icon_theme": "$(json_escape "$REA_SYS_ICON_THEME")",
    "cursor_theme": "$(json_escape "$REA_SYS_CURSOR_THEME")",
    "font": "$(json_escape "$REA_SYS_FONT")",
    "monospace_font": "$(json_escape "$REA_SYS_MONO_FONT")",
    "color_scheme": "$(json_escape "$REA_SYS_COLOR_SCHEME")",
    "button_layout": "$(json_escape "$REA_SYS_BUTTON_LAYOUT")",
    "animations": "$(json_escape "$REA_SYS_ANIMATIONS")"
  },
  "extensions": { "enabled_count": $REA_SYS_EXT_COUNT, "enabled": "$(json_escape "$REA_SYS_EXT_ENABLED")" },
  "packaging": { "apt": $REA_SYS_HAS_APT, "snap": $REA_SYS_HAS_SNAP, "flatpak": $REA_SYS_HAS_FLATPAK, "home_free_mb": $REA_SYS_HOME_FREE_MB },
  "conflicts": "$(json_escape "$REA_SYS_CONFLICTS")"
}
JSON
}
