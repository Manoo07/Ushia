#!/usr/bin/env bash
# pkg.sh - apt helpers. Rea adds no third-party repositories; everything here
# comes from the distribution's own archives.

REA_APT_UPDATED=0

rea_pkg_installed() {
  have dpkg-query || return 1
  [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == "installed" ]]
}

rea_pkg_exists() {
  have apt-cache || return 1
  apt-cache show "$1" >/dev/null 2>&1
}

rea_apt_update() {
  ((REA_APT_UPDATED)) && return 0
  rea_sudo_warm "refresh the apt package index" || return 1
  run sudo apt-get update -qq || rea_warn "apt-get update reported a problem"
  REA_APT_UPDATED=1
}

# rea_pkg_ensure <purpose> <pkg...> - installs only what is missing.
# Returns 1 if anything could not be installed, so callers can degrade.
rea_pkg_ensure() {
  local purpose="$1"; shift
  local -a missing=() unavailable=()
  local p

  if ! have apt-get || ! have dpkg-query; then
    rea_warn "No apt on this system; skipping the packages for $purpose ($*)"
    return 1
  fi

  for p in "$@"; do
    rea_pkg_installed "$p" && continue
    if rea_pkg_exists "$p"; then missing+=("$p"); else unavailable+=("$p"); fi
  done

  ((${#unavailable[@]})) && rea_warn "Not in this release's archives: ${unavailable[*]}"

  if ((${#missing[@]} == 0)); then
    rea_skip "System packages for $purpose already present"
    ((${#unavailable[@]})) && return 1
    return 0
  fi

  if ! rea_sudo_available; then
    rea_warn "Needs apt packages but sudo is unavailable: ${missing[*]}"
    return 1
  fi

  rea_info "Installing for $purpose: ${missing[*]}"
  rea_apt_update || true
  rea_sudo_warm "install: ${missing[*]}" || { rea_warn "Skipped apt install"; return 1; }

  if run sudo apt-get install -y --no-install-recommends "${missing[@]}"; then
    for p in "${missing[@]}"; do rea_record pkg "$p"; done
    rea_ok "Installed: ${missing[*]}"
    ((${#unavailable[@]})) && return 1
    return 0
  fi
  rea_warn "apt could not install: ${missing[*]}"
  return 1
}

# rea_pkg_remove_recorded - used by `rea uninstall`; only ever removes packages
# this machine's receipt says Rea installed.
rea_pkg_remove_recorded() {
  local -a pkgs=()
  while IFS= read -r p; do [[ -n "$p" ]] && rea_pkg_installed "$p" && pkgs+=("$p"); done < <(rea_receipt_values pkg)
  ((${#pkgs[@]})) || { rea_skip "No Rea-installed packages to remove"; return 0; }
  rea_info "Packages Rea installed: ${pkgs[*]}"
  ask_yes_no "Remove them with apt?" n || { rea_skip "Keeping packages"; return 0; }
  rea_sudo_warm "remove packages" || return 1
  run sudo apt-get remove -y "${pkgs[@]}" && rea_ok "Removed ${#pkgs[@]} package(s)"
}
