#!/usr/bin/env bash
# dock.sh - the Dock.
#
# Two flavours, because no single GNOME extension does everything macOS's Dock
# does:
#
#   animated  Dash2Dock Animated. The only maintained extension with real
#             pointer magnification (the parabolic zoom), plus Trash and
#             mounted-volume icons. Slightly more GPU work per frame.
#   classic   Dash to Dock. Rock solid, huge install base, but it has no hover
#             magnification - icons stay a fixed size.
#
# Ubuntu ships its own Dash to Dock fork (ubuntu-dock) which conflicts with
# both, so it is disabled first. That is the single most common cause of
# "I installed a dock and now I have two docks".

rea_dock_resolve_conflicts() {
  local uuid
  for uuid in "${REA_EXT_CONFLICTS[@]}"; do
    [[ "$uuid" == "ding@rastersoft.com" ]] && continue   # desktop icons: harmless
    rea_ext_disable "$uuid" "would stack a second dock on screen"
  done
  if pgrep -x plank >/dev/null 2>&1 || pgrep -x cairo-dock >/dev/null 2>&1; then
    rea_warn "Another dock process (plank/cairo-dock) is running; quit it to avoid two docks"
  fi
}

_dock_favorites() {
  # Keep the user's existing favourites; only ensure a file manager and a
  # terminal are pinned, the way a fresh Mac pins Finder and Terminal.
  local current want app
  current="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || printf '[]')"
  want=""
  for app in org.gnome.Nautilus.desktop org.gnome.Settings.desktop; do
    case "$current" in *"$app"*) ;; *) want+="${want:+ }$app" ;; esac
  done
  [[ -z "$want" ]] && return 0
  local merged="${current%]}"
  for app in $want; do
    [[ "$merged" == "[" ]] && merged+="'$app'" || merged+=", '$app'"
  done
  rea_gset org.gnome.shell favorite-apps "${merged}]"
}

rea_dock_install() {
  local flavour="${REA_DOCK_FLAVOUR:-animated}"
  case "$flavour" in
    none) rea_skip "Dock disabled by profile"; return 0 ;;
    animated)
      if rea_ext_install "$REA_EXT_DOCK_ANIMATED" "Dash2Dock Animated (magnifying dock)"; then
        rea_ext_enable "$REA_EXT_DOCK_ANIMATED" "Dash2Dock Animated"
      else
        rea_warn "Falling back to Dash to Dock (no hover magnification)"
        REA_DOCK_FLAVOUR="classic"
        rea_ext_install "$REA_EXT_DOCK_CLASSIC" "Dash to Dock" \
          && rea_ext_enable "$REA_EXT_DOCK_CLASSIC" "Dash to Dock"
      fi
      ;;
    classic)
      rea_ext_install "$REA_EXT_DOCK_CLASSIC" "Dash to Dock" \
        && rea_ext_enable "$REA_EXT_DOCK_CLASSIC" "Dash to Dock"
      ;;
    *) rea_warn "Unknown dock flavour '$flavour'"; return 1 ;;
  esac
}

rea_dock_configure() {
  local size="${REA_DOCK_ICON_SIZE:-44}" op="${REA_DOCK_OPACITY:-0.4}"
  local hide="${REA_DOCK_AUTOHIDE:-1}" mag="${REA_DOCK_MAGNIFY:-1}"

  # ---- Dash2Dock Animated -------------------------------------------------
  # Key names here move between releases; rea_gset_ext skips any key this
  # version does not have and `rea verify` reports the count.
  if rea_ext_installed "$REA_EXT_DOCK_ANIMATED"; then
    local u="$REA_EXT_DOCK_ANIMATED" s=org.gnome.shell.extensions.dash2dock-lite
    rea_gset_ext "$u" "$s" dock-location 0
    rea_gset_ext "$u" "$s" icon-size "$(awk -v s="$size" 'BEGIN{printf "%.2f", s/64}')"
    rea_gset_ext "$u" "$s" edge-distance 0.0
    rea_gset_ext "$u" "$s" background-opacity "$op"
    rea_gset_ext "$u" "$s" panel-mode false
    rea_gset_ext "$u" "$s" trash-icon true
    rea_gset_ext "$u" "$s" mounted-icon true
    rea_gset_ext "$u" "$s" apps-icon true
    rea_gset_ext "$u" "$s" calendar-icon false      # a live clock face costs a redraw a second
    rea_gset_ext "$u" "$s" clock-icon false
    rea_gset_ext "$u" "$s" separator-position 0.0
    rea_gset_ext "$u" "$s" favorites-only false
    rea_gset_ext "$u" "$s" items-drag true
    rea_gset_ext "$u" "$s" multi-monitor-preference 0  # follow the primary display
    if ((mag)); then
      rea_gset_ext "$u" "$s" animation-magnify 0.45
      rea_gset_ext "$u" "$s" animation-spread 0.25
      rea_gset_ext "$u" "$s" animation-rise 0.15
    else
      rea_gset_ext "$u" "$s" animation-magnify 0.0
      rea_gset_ext "$u" "$s" animation-spread 0.0
      rea_gset_ext "$u" "$s" animation-rise 0.0
    fi
    if ((hide)); then
      rea_gset_ext "$u" "$s" autohide-dash true
      rea_gset_ext "$u" "$s" autohide-dodge true
      rea_gset_ext "$u" "$s" pressure-sense true
    else
      rea_gset_ext "$u" "$s" autohide-dash false
    fi
    rea_ok "Configured the magnifying dock (${size}px icons)"
  fi

  # ---- Dash to Dock -------------------------------------------------------
  if rea_ext_installed "$REA_EXT_DOCK_CLASSIC"; then
    local u="$REA_EXT_DOCK_CLASSIC" s=org.gnome.shell.extensions.dash-to-dock
    rea_gset_ext "$u" "$s" dock-position "'BOTTOM'"
    rea_gset_ext "$u" "$s" extend-height false            # floating, not a full-width bar
    rea_gset_ext "$u" "$s" dock-fixed "$([[ $hide == 1 ]] && echo false || echo true)"
    rea_gset_ext "$u" "$s" autohide "$([[ $hide == 1 ]] && echo true || echo false)"
    rea_gset_ext "$u" "$s" intellihide true
    rea_gset_ext "$u" "$s" intellihide-mode "'FOCUS_APPLICATION_WINDOWS'"
    rea_gset_ext "$u" "$s" require-pressure-to-show true
    rea_gset_ext "$u" "$s" animation-time 0.15
    rea_gset_ext "$u" "$s" hide-delay 0.2
    rea_gset_ext "$u" "$s" show-delay 0.25
    rea_gset_ext "$u" "$s" dash-max-icon-size "$size"
    rea_gset_ext "$u" "$s" icon-size-fixed false
    rea_gset_ext "$u" "$s" show-apps-at-top true          # Launchpad sits at the start
    rea_gset_ext "$u" "$s" show-trash true
    rea_gset_ext "$u" "$s" show-mounts true
    rea_gset_ext "$u" "$s" show-mounts-only-mounted true
    rea_gset_ext "$u" "$s" show-running true
    rea_gset_ext "$u" "$s" running-indicator-style "'DOTS'"
    rea_gset_ext "$u" "$s" click-action "'minimize-or-previews'"
    rea_gset_ext "$u" "$s" scroll-action "'cycle-windows'"
    rea_gset_ext "$u" "$s" shift-click-action "'launch'"
    rea_gset_ext "$u" "$s" middle-click-action "'launch'"
    rea_gset_ext "$u" "$s" transparency-mode "'FIXED'"
    rea_gset_ext "$u" "$s" background-opacity "$op"
    rea_gset_ext "$u" "$s" custom-background-color false
    rea_gset_ext "$u" "$s" apply-custom-theme false       # let WhiteSur style it
    rea_gset_ext "$u" "$s" custom-theme-shrink true
    rea_gset_ext "$u" "$s" multi-monitor false
    rea_gset_ext "$u" "$s" preferred-monitor -2           # -2 = primary, survives replugging
    rea_gset_ext "$u" "$s" isolate-workspaces false
    rea_ok "Configured Dash to Dock (${size}px icons)"
    ((mag)) && rea_info "Dash to Dock has no hover magnification - that is an extension limit, not a setting"
  fi

  _dock_favorites
}

rea_dock_report() {
  if rea_ext_enabled "$REA_EXT_DOCK_ANIMATED"; then printf 'animated'
  elif rea_ext_enabled "$REA_EXT_DOCK_CLASSIC"; then printf 'classic'
  else printf 'none'; fi
}
