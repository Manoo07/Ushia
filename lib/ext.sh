#!/usr/bin/env bash
# ext.sh - GNOME Shell extensions: install from extensions.gnome.org for the
# running shell version, enable, disable, and track what we added.
#
# On Wayland a newly installed extension cannot be loaded into the running
# shell, so anything we install sets REA_NEEDS_LOGOUT and the installer says so
# at the end instead of leaving the user wondering why nothing changed.

REA_EGO="https://extensions.gnome.org"
REA_NEEDS_LOGOUT=0

rea_ext_installed() {
  have gnome-extensions || return 1
  gnome-extensions list 2>/dev/null | grep -qx "$1"
}

rea_ext_enabled() {
  have gnome-extensions || return 1
  gnome-extensions list --enabled 2>/dev/null | grep -qx "$1"
}

# _ext_download_url <uuid> <shell-major> - resolves the matching release.
_ext_download_url() {
  local uuid="$1" ver="$2" json path
  json="$(curl -fsSL --max-time 30 "$REA_EGO/extension-info/?uuid=$uuid&shell_version=$ver" 2>/dev/null)" || return 1
  [[ -n "$json" ]] || return 1
  if have python3; then
    path="$(printf '%s' "$json" | python3 -I -c 'import json,sys
try:
    print(json.load(sys.stdin).get("download_url") or "")
except Exception:
    pass')"
  else
    path="$(printf '%s' "$json" | tr ',' '\n' | sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p' | head -n1)"
    path="${path//\\\//\/}"
  fi
  [[ -n "$path" ]] || return 1
  printf '%s%s' "$REA_EGO" "$path"
}

# rea_ext_install <uuid> [label]
rea_ext_install() {
  local uuid="$1" label="${2:-$1}" url dir zip
  if ! have gnome-extensions; then
    rea_warn "gnome-extensions CLI missing; cannot install $label"
    return 1
  fi
  if rea_ext_installed "$uuid"; then
    rea_skip "$label already installed"
    return 0
  fi
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would install extension $uuid"
    return 0
  fi

  if ! url="$(_ext_download_url "$uuid" "${REA_SYS_SHELL_MAJOR:-45}")"; then
    rea_warn "$label has no release for GNOME ${REA_SYS_SHELL_VER:-?} (skipping)"
    return 1
  fi

  dir="$(rea_cache_dir_for "ext-${uuid%%@*}")"
  zip="$dir/extension.zip"
  if ! run curl -fsSL --retry 2 --max-time 120 -o "$zip" "$url"; then
    rea_warn "Could not download $label"
    return 1
  fi
  if ! run gnome-extensions install --force "$zip"; then
    rea_warn "Could not install $label"
    return 1
  fi
  rea_record ext "$uuid"
  REA_NEEDS_LOGOUT=1
  rea_ok "Installed $label"
}

# rea_ext_enable <uuid> [label]
rea_ext_enable() {
  local uuid="$1" label="${2:-$1}"
  if ! rea_ext_installed "$uuid"; then
    rea_warn "$label is not installed; cannot enable"
    return 1
  fi
  rea_ext_enabled "$uuid" && { rea_skip "$label already on"; return 0; }
  if run gnome-extensions enable "$uuid"; then
    rea_ok "Enabled $label"
    rea_record ext-enabled "$uuid"
  else
    # On Wayland this is normal for a brand-new extension: dconf still records
    # it and the shell picks it up after the next login.
    rea_warn "Could not enable $label in the running shell; it will load after logout"
    REA_NEEDS_LOGOUT=1
  fi
}

# rea_ext_disable <uuid> <why>
rea_ext_disable() {
  local uuid="$1" why="${2:-conflicts with Rea}"
  rea_ext_enabled "$uuid" || return 0
  if run gnome-extensions disable "$uuid"; then
    rea_ok "Disabled $uuid ($why)"
    rea_record ext-disabled "$uuid"
  else
    rea_warn "Could not disable $uuid; expect visual conflicts"
  fi
}

# rea_ext_restore_disabled - used by uninstall: re-enable what we turned off.
rea_ext_restore_disabled() {
  local uuid
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    rea_ext_installed "$uuid" && run gnome-extensions enable "$uuid" \
      && rea_ok "Re-enabled $uuid"
  done < <(rea_receipt_values ext-disabled)
}

# rea_ext_uninstall_recorded - removes only extensions Rea installed.
rea_ext_uninstall_recorded() {
  local uuid n=0
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    rea_ext_installed "$uuid" || continue
    run gnome-extensions disable "$uuid" || true
    if run gnome-extensions uninstall "$uuid"; then n=$((n + 1)); fi
  done < <(rea_receipt_values ext)
  rea_ok "Removed $n extension(s) Rea installed"
}
