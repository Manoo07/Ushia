#!/usr/bin/env bash
# install.sh - orchestration. The order here is load-bearing: packages before
# builds, extensions before their settings, settings before verification.

REA_APPEARANCE="${REA_APPEARANCE:-light}"

rea_profile_load() {
  local name="$1" file
  file="$REA_CONFIG_DIR/profiles/$name.conf"
  [[ -r "$file" ]] || { rea_err "No such profile: $name"; return 1; }
  # shellcheck source=/dev/null
  . "$file"
  rea_prefs_set REA_PROFILE "$name"
  return 0
}

rea_profile_list() {
  local f name
  for f in "$REA_CONFIG_DIR"/profiles/*.conf; do
    [[ -r "$f" ]] || continue
    name="$(basename "$f" .conf)"
    printf '  %s%-10s%s %s\n' "$C_BOLD" "$name" "$C_RESET" \
      "$(sed -n 's/^REA_PROFILE_DESC="\(.*\)"$/\1/p' "$f")"
  done
}

# ---------------------------------------------------------------- wallpaper --
# Rea's own gradient, drawn here as SVG. No Apple artwork is copied or shipped.
rea_wallpaper_apply() {
  local dir="$REA_STATE_DIR/wallpapers" light dark
  light="$dir/rea-light.svg"; dark="$dir/rea-dark.svg"
  if [[ "$REA_DRY_RUN" == "1" ]]; then rea_dim "would install the Rea wallpapers"; return 0; fi
  mkdir -p "$dir"
  cp -f "$REA_CONFIG_DIR/assets/rea-light.svg" "$light"
  cp -f "$REA_CONFIG_DIR/assets/rea-dark.svg"  "$dark"
  rea_record dir "$dir"
  rea_gset org.gnome.desktop.background picture-uri "'file://$light'"
  rea_gset org.gnome.desktop.background picture-uri-dark "'file://$dark'"
  rea_gset org.gnome.desktop.background picture-options "'zoom'"
  rea_gset org.gnome.desktop.screensaver picture-uri "'file://$dark'"
  rea_ok "Wallpaper set (Rea gradient; your own wallpaper is one click away in Settings)"
}

# ------------------------------------------------------------------- install --
rea_install_run() {
  local profile="${1:-}" bench_before=0 snap

  rea_detect_all
  local blockers; blockers="$(rea_detect_blockers)"
  if [[ -n "$blockers" ]]; then
    rea_head "Cannot install"
    while IFS= read -r l; do [[ -n "$l" ]] && rea_err "$l"; done <<<"$blockers"
    if [[ "${REA_FORCE:-0}" == "1" ]]; then
      rea_warn "--force given: continuing anyway. Expect breakage."
    else
      rea_say ""
      rea_die "Fix the above, or re-run with --force if you know better." 3
    fi
  fi

  # ---- choose a profile ---------------------------------------------------
  if [[ -z "$profile" ]]; then
    rea_head "Choose a profile"
    rea_profile_list
    local pick
    pick="$(ask_choice "Which one?" 2 "full - everything, needs a capable GPU" \
                                     "balanced - recommended" \
                                     "lite - theme only, lowest cost")"
    case "$pick" in 1) profile=full ;; 3) profile=lite ;; *) profile=balanced ;; esac
  fi
  rea_profile_load "$profile" || return 1

  # ---- appearance ---------------------------------------------------------
  if [[ "$REA_ASSUME_YES" != "1" ]]; then
    local a; a="$(ask_choice "Appearance" 1 "Light" "Dark")"
    [[ "$a" == "2" ]] && REA_APPEARANCE="dark" || REA_APPEARANCE="light"
  fi
  rea_prefs_set REA_APPEARANCE "$REA_APPEARANCE"

  # ---- plan ---------------------------------------------------------------
  rea_head "Plan"
  printf '  %-22s %s\n' "profile" "$REA_PROFILE_NAME ($REA_PROFILE_DESC)"
  printf '  %-22s %s\n' "appearance" "$REA_APPEARANCE"
  printf '  %-22s %s\n' "dock" "$REA_DOCK_FLAVOUR, ${REA_DOCK_ICON_SIZE}px, magnify=$REA_DOCK_MAGNIFY"
  printf '  %-22s %s\n' "blur" "$REA_BLUR (sigma ${REA_BLUR_SIGMA})"
  printf '  %-22s %s\n' "fonts" "$REA_FONT_UI / $REA_FONT_MONO"
  printf '  %-22s %s\n' "session" "$REA_SYS_SESSION_TYPE on GNOME $REA_SYS_SHELL_VER"
  printf '  %-22s %s\n' "writes to" "\$HOME only (apt is used for ${C_BOLD}listed${C_RESET} packages)"
  printf '  %-22s %s\n' "reversible" "yes - a snapshot is taken before anything changes"
  rea_say ""
  ask_yes_no "Go ahead?" y || { rea_skip "Nothing was changed."; return 0; }

  # ---- baseline measurement ----------------------------------------------
  if [[ "$REA_SYS_SESSION_TYPE" != "unknown" ]] && ask_yes_no "Measure performance first (${REA_BENCH_SAMPLE_SECONDS}s, so the result can be compared after)?" y; then
    rea_bench_run "before-$REA_PROFILE_NAME"
    bench_before=1
  fi

  # ---- snapshot -----------------------------------------------------------
  rea_steps_total 12
  rea_step "Saving a restore point"
  snap="$(rea_snapshot_create "pre-install")"
  rea_ok "Snapshot $snap - 'rea rollback $snap' undoes everything below"
  rea_prefs_set REA_PREINSTALL_SNAPSHOT "$snap"

  rea_step "Base tools"
  rea_pkg_ensure "Rea itself" curl git unzip dconf-cli fontconfig || \
    rea_warn "Some base tools are missing; later steps may skip"

  rea_step "Typography"
  rea_fonts_install
  rea_fonts_rendering

  rea_step "Theme"
  rea_theme_deps
  rea_theme_install_gtk || rea_warn "Continuing without the GTK theme"
  rea_theme_install_icons || rea_warn "Continuing with the current icons"
  rea_theme_install_cursors || true

  rea_step "Shell extensions"
  rea_panel_install
  rea_dock_resolve_conflicts
  rea_dock_install
  rea_wm_install

  rea_step "Applying the appearance"
  rea_theme_apply "$REA_APPEARANCE"
  rea_theme_css
  rea_fonts_apply
  rea_theme_flatpak
  rea_wallpaper_apply

  rea_step "Top bar"
  rea_panel_configure

  rea_step "Dock"
  rea_dock_configure

  rea_step "Windows and keyboard"
  rea_wm_configure
  rea_wm_keybindings

  rea_step "File manager"
  rea_files_install
  rea_files_configure
  rea_files_bookmarks

  rea_step "Input"
  rea_input_configure
  rea_input_gestures

  rea_step "Cleaning up"
  rea_cache_clean
  rea_gset_summary
  rea_record install "$REA_PROFILE_NAME"

  # ---- summary ------------------------------------------------------------
  rea_rule
  rea_head "Done"
  rea_ok "Profile $REA_PROFILE_NAME, $REA_APPEARANCE appearance"
  rea_ok "Dock: $(rea_dock_report)"
  ((REA_WARN_COUNT)) && rea_warn "$REA_WARN_COUNT warning(s) above - none of them stop the desktop working"

  rea_head "Finish the install"
  if [[ "$REA_SYS_SESSION_TYPE" == "wayland" ]]; then
    rea_say "  ${C_BOLD}Log out and back in.${C_RESET} Wayland cannot load new shell extensions into"
    rea_say "  a running session, so the dock and top bar appear after you log in again."
  elif ((REA_NEEDS_LOGOUT)); then
    rea_say "  Press ${C_BOLD}Alt+F2${C_RESET}, type ${C_BOLD}r${C_RESET}, press Enter to restart the shell."
    rea_say "  (Or log out and back in, which always works.)"
  else
    rea_say "  Log out and back in so every application picks up the new theme and fonts."
  fi
  rea_say ""
  rea_say "  Then:"
  rea_say "    ${C_BOLD}rea verify${C_RESET}    check every acceptance criterion against the live system"
  ((bench_before)) && rea_say "    ${C_BOLD}rea bench after${C_RESET} then ${C_BOLD}rea bench --compare${C_RESET}   what it cost"
  rea_say "    ${C_BOLD}rea rollback${C_RESET}  put everything back"

  rea_head "Shortcuts"
  rea_wm_shortcut_table
  rea_say ""
  [[ -n "$REA_LOG_FILE" ]] && rea_dim "full log: $REA_LOG_FILE"
  return 0
}

# ----------------------------------------------------------------- re-apply --
# Switching profile or appearance without re-downloading anything.
rea_reapply_run() {
  rea_detect_all
  rea_theme_apply "$REA_APPEARANCE"
  rea_theme_css
  rea_fonts_apply
  rea_panel_configure
  rea_dock_configure
  rea_wm_configure
  rea_wm_keybindings
  rea_files_configure
  rea_input_configure
  rea_gset_summary
  rea_ok "Re-applied profile $REA_PROFILE_NAME ($REA_APPEARANCE)"
}

# ----------------------------------------------------------------- uninstall --
rea_uninstall_run() {
  local snap="${REA_PREINSTALL_SNAPSHOT:-}"
  rea_detect_all

  rea_head "Remove Rea"
  rea_say "  This restores the desktop to the snapshot taken before Rea ran,"
  rea_say "  turns off the extensions it enabled, and optionally removes the"
  rea_say "  themes, fonts and packages it installed."
  rea_say ""

  [[ -n "$snap" && -d "$REA_SNAPSHOT_DIR/$snap" ]] || snap="$(rea_snapshot_list | grep pre-install | head -n1)"
  if [[ -z "$snap" ]]; then
    rea_warn "No pre-install snapshot found; settings will be reset to GNOME defaults instead"
  else
    rea_info "Will restore snapshot: $snap"
  fi
  ask_yes_no "Continue?" n || { rea_skip "Cancelled"; return 0; }

  rea_steps_total 5

  rea_step "Turning off what Rea enabled"
  rea_ext_restore_disabled
  rea_ext_uninstall_recorded

  rea_step "Restoring settings"
  if [[ -n "$snap" ]]; then
    rea_snapshot_restore "$snap"
  else
    local p
    for p in "${REA_DCONF_PATHS[@]}"; do run dconf reset -f "$p"; done
    rea_ok "Reset Rea's settings paths to defaults"
  fi

  rea_step "Flatpak overrides"
  rea_theme_flatpak_reset

  rea_step "Themes, icons and fonts"
  if ask_yes_no "Delete the theme, icon and font files Rea downloaded?" n; then
    local d
    while IFS= read -r d; do
      [[ -n "$d" && -d "$d" ]] || continue
      case "$d" in "$HOME"/*) run rm -rf "$d"; rea_ok "Removed $d" ;; esac
    done < <(rea_receipt_values dir)
  else
    rea_skip "Keeping the downloaded files (they are inert once unselected)"
  fi

  rea_step "System packages"
  rea_pkg_remove_recorded || true

  rea_cache_clean
  rea_head "Removed"
  rea_say "  Log out and back in to return to the stock desktop."
  [[ -f "$REA_RECEIPT" ]] && run mv -f "$REA_RECEIPT" "$REA_RECEIPT.removed-$(date +%Y%m%d)"
  return 0
}
