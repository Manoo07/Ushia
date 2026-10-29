#!/usr/bin/env bash
# panel.sh - the top bar and its translucency.
#
# Composition, not imitation: the status area stays GNOME's own Quick Settings,
# because every control in it does something real. Rea changes the metrics,
# position, typography and background so it reads as a menu bar, and adds the
# blur that GNOME has no native setting for.
#
# What Rea does NOT ship: a global application menu. The GNOME 45+ API removed
# what the old global-menu extensions relied on and no maintained replacement
# exists, so a menu bar here would be a decoration with nothing behind it. See
# docs/limitations.md.

rea_panel_install() {
  rea_pkg_ensure "shell theming" gnome-shell-extensions gnome-shell-extension-prefs || true
  rea_ext_enable "$REA_EXT_USER_THEME" "User Themes" || true

  rea_ext_install "$REA_EXT_PERFECTION" "Just Perfection (panel metrics)" \
    && rea_ext_enable "$REA_EXT_PERFECTION" "Just Perfection"

  if [[ "${REA_BLUR:-1}" == "1" ]]; then
    rea_ext_install "$REA_EXT_BLUR" "Blur my Shell (translucency)" \
      && rea_ext_enable "$REA_EXT_BLUR" "Blur my Shell"
  else
    rea_skip "Blur disabled by profile"
    rea_ext_enabled "$REA_EXT_BLUR" && rea_ext_disable "$REA_EXT_BLUR" "disabled by the $REA_PROFILE_NAME profile"
  fi
}

rea_panel_configure() {
  local u="$REA_EXT_PERFECTION" s=org.gnome.shell.extensions.just-perfection

  # ---- metrics and layout -------------------------------------------------
  rea_gset_ext "$u" "$s" panel-size "${REA_PANEL_SIZE:-28}"
  rea_gset_ext "$u" "$s" panel-button-padding-size 6
  rea_gset_ext "$u" "$s" panel-indicator-padding-size 4
  rea_gset_ext "$u" "$s" clock-menu-position 2        # 2 = right, as on macOS
  rea_gset_ext "$u" "$s" clock-menu-position-offset 0
  rea_gset_ext "$u" "$s" app-menu true                # app name at the left
  rea_gset_ext "$u" "$s" app-menu-icon true
  rea_gset_ext "$u" "$s" activities-button true       # kept: it is the real overview control
  rea_gset_ext "$u" "$s" panel-in-overview true
  rea_gset_ext "$u" "$s" quick-settings true
  rea_gset_ext "$u" "$s" accessibility-menu false
  rea_gset_ext "$u" "$s" startup-status 0             # start on the desktop, not the overview
  rea_gset_ext "$u" "$s" double-super-to-appgrid true # Super Super = Launchpad
  rea_gset_ext "$u" "$s" dash-separator false
  rea_gset_ext "$u" "$s" window-demands-attention-focus true
  rea_gset_ext "$u" "$s" ripple-box false             # the GNOME hot-corner ripple is not a macOS gesture
  rea_gset_ext "$u" "$s" animation "${REA_ANIMATION_SPEED:-3}"

  # ---- clock and status readouts -----------------------------------------
  rea_gset org.gnome.desktop.interface clock-format "'12h'"
  rea_gset org.gnome.desktop.interface clock-show-weekday true
  rea_gset org.gnome.desktop.interface clock-show-date true
  rea_gset org.gnome.desktop.interface clock-show-seconds false
  rea_gset org.gnome.desktop.interface show-battery-percentage true
  rea_gset org.gnome.desktop.calendar show-weekdate false

  # ---- translucency -------------------------------------------------------
  if [[ "${REA_BLUR:-1}" == "1" ]]; then
    local b=org.gnome.shell.extensions.blur-my-shell
    rea_gset_ext "$REA_EXT_BLUR" "$b" hacks-level 1
    rea_gset_ext "$REA_EXT_BLUR" "$b" brightness 0.62
    rea_gset_ext "$REA_EXT_BLUR" "$b" sigma "${REA_BLUR_SIGMA:-20}"
    rea_gset_ext "$REA_EXT_BLUR" "$b" color-and-noise true

    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" blur true
    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" static-blur true   # one texture, not a per-frame pass
    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" brightness 0.62
    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" sigma "${REA_BLUR_SIGMA:-20}"
    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" unblur-dynamic-overview true
    rea_gset_ext "$REA_EXT_BLUR" "$b.panel" override-background true

    if [[ "${REA_BLUR_PANEL_ONLY:-0}" == "1" ]]; then
      rea_gset_ext "$REA_EXT_BLUR" "$b.overview" blur false
      rea_dim "overview blur off: the panel-only setting keeps frame time flat"
    else
      rea_gset_ext "$REA_EXT_BLUR" "$b.overview" blur true
      rea_gset_ext "$REA_EXT_BLUR" "$b.overview" style-components 3
    fi

    rea_gset_ext "$REA_EXT_BLUR" "$b.dash-to-dock" blur true
    rea_gset_ext "$REA_EXT_BLUR" "$b.dash-to-dock" static-blur true
    rea_gset_ext "$REA_EXT_BLUR" "$b.dash-to-dock" style-dash-to-dock 0
    rea_gset_ext "$REA_EXT_BLUR" "$b.dash-to-dock" brightness 0.62

    # Per-window blur is the expensive one and it breaks apps that draw their
    # own background. Off deliberately.
    rea_gset_ext "$REA_EXT_BLUR" "$b.applications" blur false
    rea_gset_ext "$REA_EXT_BLUR" "$b.lockscreen" blur true
    rea_ok "Panel translucency on (sigma ${REA_BLUR_SIGMA:-20}, static)"
  fi

  rea_ok "Top bar configured (${REA_PANEL_SIZE:-28}px, clock right)"
}
