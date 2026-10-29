#!/usr/bin/env bash
# verify.sh - checks the acceptance criteria against the live system.
#
# Every check reads real state: a setting's current value, a file on disk, an
# extension's enabled list. Nothing is assumed from the fact that the installer
# ran. Exit status is 0 when nothing failed, 1 when something did.

REA_V_PASS=0
REA_V_WARN=0
REA_V_FAIL=0
REA_V_JSON=""

_v() {
  local verdict="$1" name="$2" detail="$3" mark colour
  case "$verdict" in
    pass) REA_V_PASS=$((REA_V_PASS + 1)); mark="✓"; colour="$C_GRN" ;;
    warn) REA_V_WARN=$((REA_V_WARN + 1)); mark="!"; colour="$C_YEL" ;;
    fail) REA_V_FAIL=$((REA_V_FAIL + 1)); mark="✗"; colour="$C_RED" ;;
  esac
  printf '  %s%s%s %-34s %s%s%s\n' "$colour" "$mark" "$C_RESET" "$name" "$C_DIM" "$detail" "$C_RESET"
  REA_V_JSON+="${REA_V_JSON:+,}{\"check\":\"$(json_escape "$name")\",\"verdict\":\"$verdict\",\"detail\":\"$(json_escape "$detail")\"}"
  _rea_write_log "VERIFY $verdict $name - $detail"
}

_v_gset_contains() {
  local name="$1" schema="$2" key="$3" want="$4" level="${5:-fail}" val
  if ! rea_schema_exists "$schema"; then _v warn "$name" "schema $schema not on this system"; return; fi
  val="$(gsettings get "$schema" "$key" 2>/dev/null)"
  if [[ "$val" == *"$want"* ]]; then _v pass "$name" "$val"
  else _v "$level" "$name" "expected $want, found ${val:-nothing}"; fi
}

rea_verify_all() {
  rea_detect_all
  rea_theme_detect_installed || true

  rea_head "Appearance"
  if [[ -n "$REA_THEME_LIGHT$REA_THEME_DARK" ]]; then
    _v pass "GTK theme installed" "${REA_THEME_LIGHT:-}${REA_THEME_DARK:+ / $REA_THEME_DARK}"
  else
    _v fail "GTK theme installed" "no WhiteSur-* in ~/.themes"
  fi
  _v_gset_contains "GTK theme selected"   org.gnome.desktop.interface gtk-theme   WhiteSur
  _v_gset_contains "Icon theme selected"  org.gnome.desktop.interface icon-theme  WhiteSur warn
  _v_gset_contains "Cursor theme"         org.gnome.desktop.interface cursor-theme McMojave warn

  if rea_ext_enabled "$REA_EXT_USER_THEME"; then
    _v_gset_contains "Shell theme selected" org.gnome.shell.extensions.user-theme name WhiteSur
  else
    _v fail "Shell theme" "User Themes extension is off, so the top bar keeps GNOME's style"
  fi

  local f
  for f in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
    if grep -q 'rea:managed' "$f" 2>/dev/null; then
      _v pass "Style overrides $(basename "$(dirname "$f")")" "present"
    else
      _v warn "Style overrides $(basename "$(dirname "$f")")" "missing; radii and scrollbars will be GNOME's"
    fi
  done

  rea_head "Typography"
  rea_font_family_present "Inter" \
    && _v pass "Interface font installed" "Inter" \
    || _v fail "Interface font installed" "Inter not found by fontconfig"
  rea_font_family_present "JetBrains Mono" \
    && _v pass "Monospace font installed" "JetBrains Mono" \
    || _v warn "Monospace font installed" "JetBrains Mono not found"
  _v_gset_contains "Interface font selected" org.gnome.desktop.interface font-name Inter
  _v_gset_contains "Monospace font selected" org.gnome.desktop.interface monospace-font-name JetBrains warn
  [[ -f "$HOME/.config/fontconfig/conf.d/99-rea-rendering.conf" ]] \
    && _v pass "Font rendering rules" "subpixel + Apple-name aliases" \
    || _v warn "Font rendering rules" "not installed"

  rea_head "Dock"
  local flav; flav="$(rea_dock_report)"
  case "$flav" in
    animated) _v pass "Dock running" "Dash2Dock Animated (with magnification)" ;;
    classic)  _v pass "Dock running" "Dash to Dock (no magnification)" ;;
    none)     _v fail "Dock running" "no dock extension is enabled" ;;
  esac
  local conflict found=0 uuid
  for uuid in "${REA_EXT_CONFLICTS[@]}"; do
    [[ "$uuid" == "ding@rastersoft.com" ]] && continue
    rea_ext_enabled "$uuid" && { conflict="$uuid"; found=1; }
  done
  ((found)) && _v fail "No duplicate dock" "$conflict is still enabled" \
            || _v pass "No duplicate dock" "ubuntu-dock and dash-to-panel are off"

  rea_head "Top bar and shell"
  rea_ext_enabled "$REA_EXT_PERFECTION" \
    && _v pass "Panel metrics extension" "Just Perfection enabled" \
    || _v warn "Panel metrics extension" "Just Perfection off; panel keeps GNOME metrics"
  if [[ "${REA_BLUR:-1}" == "1" ]]; then
    rea_ext_enabled "$REA_EXT_BLUR" \
      && _v pass "Translucency" "Blur my Shell enabled" \
      || _v warn "Translucency" "profile asks for blur but the extension is off"
  else
    _v pass "Translucency" "intentionally off in the $REA_PROFILE_NAME profile"
  fi
  _v_gset_contains "Clock format" org.gnome.desktop.interface clock-format 12h warn

  rea_head "Windows and keyboard"
  local bl; bl="$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null)"
  [[ "$bl" == "'close,minimize,maximize"* ]] \
    && _v pass "Window controls on the left" "$bl" \
    || _v fail "Window controls on the left" "found $bl"
  _v_gset_contains "Close shortcut"    org.gnome.desktop.wm.keybindings close '<Super>q'
  _v_gset_contains "Search shortcut"   org.gnome.shell.keybindings toggle-overview '<Super>space' warn
  _v_gset_contains "Spaces shortcut"   org.gnome.desktop.wm.keybindings switch-to-workspace-left Left warn
  _v_gset_contains "Animations"        org.gnome.desktop.interface enable-animations true warn
  if [[ "${REA_ROUNDED_CORNERS:-1}" == "1" ]]; then
    rea_ext_enabled "$REA_EXT_CORNERS" \
      && _v pass "Rounded window corners" "enabled" \
      || _v warn "Rounded window corners" "extension off; only GTK apps will be rounded"
  fi

  rea_head "Files"
  _v_gset_contains "Default view"      org.gnome.nautilus.preferences default-folder-viewer list-view warn
  _v_gset_contains "List tree view"    org.gnome.nautilus.list-view use-tree-view true warn
  _v_gset_contains "Breadcrumb chooser" org.gtk.Settings.FileChooser location-mode path-bar warn
  rea_pkg_installed gnome-sushi \
    && _v pass "Quick Look" "gnome-sushi installed (select a file, press Space)" \
    || _v warn "Quick Look" "gnome-sushi not installed"

  rea_head "Input"
  if [[ "$REA_SYS_TOUCHPAD" == "yes" ]]; then
    _v_gset_contains "Natural scrolling" org.gnome.desktop.peripherals.touchpad natural-scroll true warn
    _v_gset_contains "Tap to click"      org.gnome.desktop.peripherals.touchpad tap-to-click true warn
    [[ "$REA_SYS_SESSION_TYPE" == "wayland" ]] \
      && _v pass "Workspace gestures" "native three-finger swipes available" \
      || _v warn "Workspace gestures" "Xorg session: GNOME has no multi-finger workspace gestures"
  else
    _v pass "Touchpad settings" "no touchpad on this machine"
  fi

  rea_head "Recovery"
  local snap; snap="$(rea_snapshot_latest)"
  [[ -n "$snap" ]] \
    && _v pass "Restore point exists" "$snap" \
    || _v fail "Restore point exists" "no snapshot: run 'rea snapshot' now"

  local skipped
  skipped="$(grep -c 'GSET?' "${REA_LOG_FILE:-/dev/null}" 2>/dev/null || echo 0)"
  rea_head "Summary"
  printf '  %s%d passed%s · %s%d warnings%s · %s%d failed%s\n' \
    "$C_GRN" "$REA_V_PASS" "$C_RESET" "$C_YEL" "$REA_V_WARN" "$C_RESET" "$C_RED" "$REA_V_FAIL" "$C_RESET"
  ((REA_V_FAIL == 0)) || rea_say "  Failures are actionable: see docs/troubleshooting.md"
  ((REA_V_FAIL == 0))
}

rea_verify_json() {
  rea_verify_all >/dev/null 2>&1 || true
  printf '{"rea_version":"%s","checked_at":"%s","pass":%d,"warn":%d,"fail":%d,"checks":[%s]}\n' \
    "$REA_VERSION" "$(date -Is)" "$REA_V_PASS" "$REA_V_WARN" "$REA_V_FAIL" "$REA_V_JSON"
}
