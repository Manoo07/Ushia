#!/usr/bin/env bash
# wm.sh - window management, window controls, and the keyboard map.
#
# Mutter does most of this natively, which is the point: native behaviour costs
# nothing and does not break on the next GNOME release. Only rounded corners
# and tiling need an extension.
#
# Keyboard philosophy: Super stands in for Command. Rea never removes a
# shortcut without binding an alternative, and it never takes a binding the
# terminal needs (Ctrl+Left/Right stay with readline unless you opt in).

rea_wm_install() {
  if [[ "${REA_ROUNDED_CORNERS:-1}" == "1" ]]; then
    rea_ext_install "$REA_EXT_CORNERS" "Rounded Window Corners" \
      && rea_ext_enable "$REA_EXT_CORNERS" "Rounded Window Corners"
  else
    rea_skip "Rounded window corners disabled by profile"
  fi
  if [[ "${REA_TILING:-1}" == "1" ]]; then
    rea_ext_install "$REA_EXT_TILING" "Tiling Assistant" \
      && rea_ext_enable "$REA_EXT_TILING" "Tiling Assistant"
  fi
}

rea_wm_configure() {
  # ---- window controls ----------------------------------------------------
  # Traffic lights on the left. WhiteSur draws them red/yellow/green; apps with
  # custom headerbars (Chrome, VS Code, Electron) draw their own and are listed
  # in docs/limitations.md.
  rea_gset org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:appmenu'"
  rea_gset org.gnome.desktop.wm.preferences action-double-click-titlebar "'toggle-maximize'"
  rea_gset org.gnome.desktop.wm.preferences action-middle-click-titlebar "'lower'"
  rea_gset org.gnome.desktop.wm.preferences resize-with-right-button true
  rea_gset org.gnome.desktop.wm.preferences focus-mode "'click'"
  rea_gset org.gnome.desktop.wm.preferences auto-raise false
  rea_gset org.gnome.desktop.wm.preferences visual-bell false

  # ---- mutter -------------------------------------------------------------
  rea_gset org.gnome.mutter center-new-windows true
  rea_gset org.gnome.mutter edge-tiling true
  rea_gset org.gnome.mutter dynamic-workspaces true
  rea_gset org.gnome.mutter workspaces-only-on-primary false   # spaces span displays
  rea_gset org.gnome.mutter focus-change-on-pointer-rest true
  rea_gset org.gnome.mutter attach-modal-dialogs \
    "$([[ "${REA_ATTACH_MODAL_DIALOGS:-1}" == "1" ]] && echo true || echo false)"

  # ---- animation ----------------------------------------------------------
  rea_gset org.gnome.desktop.interface enable-animations \
    "$([[ "${REA_ANIMATIONS:-1}" == "1" ]] && echo true || echo false)"

  # ---- extensions ---------------------------------------------------------
  if rea_ext_installed "$REA_EXT_CORNERS"; then
    local c=org.gnome.shell.extensions.rounded-window-corners-reborn
    rea_gset_ext "$REA_EXT_CORNERS" "$c" skip-libadwaita-app false
    rea_gset_ext "$REA_EXT_CORNERS" "$c" skip-libhandy-app false
    rea_gset_ext "$REA_EXT_CORNERS" "$c" border-width 0
  fi
  if rea_ext_installed "$REA_EXT_TILING"; then
    local t=org.gnome.shell.extensions.tiling-assistant
    rea_gset_ext "$REA_EXT_TILING" "$t" enable-tiling-popup true
    rea_gset_ext "$REA_EXT_TILING" "$t" enable-tile-animations true
    rea_gset_ext "$REA_EXT_TILING" "$t" window-gap 8
    rea_gset_ext "$REA_EXT_TILING" "$t" single-screen-gap 8
    rea_gset_ext "$REA_EXT_TILING" "$t" maximize-with-gap false
  fi
  rea_ok "Window behaviour configured (controls on the left)"
}

rea_wm_keybindings() {
  local w=org.gnome.desktop.wm.keybindings
  local s=org.gnome.shell.keybindings
  local m=org.gnome.settings-daemon.plugins.media-keys

  # ---- Command-key equivalents -------------------------------------------
  rea_gset "$w" close                      "$(rea_strv '<Super>q' '<Super>w')"
  rea_gset "$w" minimize                   "$(rea_strv '<Super>h' '<Super>m')"
  rea_gset "$w" toggle-fullscreen          "$(rea_strv '<Control><Super>f')"
  rea_gset "$w" toggle-maximized           "$(rea_strv '<Super>Up')"
  rea_gset "$w" show-desktop               "$(rea_strv '<Super>d')"

  # App switching: Super+Tab like Command+Tab, with Alt+Tab left intact so
  # muscle memory and remote-desktop sessions keep working.
  rea_gset "$w" switch-applications        "$(rea_strv '<Super>Tab' '<Alt>Tab')"
  rea_gset "$w" switch-applications-backward "$(rea_strv '<Shift><Super>Tab' '<Shift><Alt>Tab')"
  rea_gset "$w" switch-group               "$(rea_strv '<Super>grave')"
  rea_gset "$w" switch-group-backward      "$(rea_strv '<Shift><Super>grave')"

  # ---- Spotlight ----------------------------------------------------------
  if [[ "${REA_CMD_SPACE_SEARCH:-1}" == "1" ]]; then
    # Super+Space opens the overview with the search field focused, which is
    # the honest native equivalent of Spotlight. GNOME ships Super+Space as
    # switch-input-source, so that moves rather than disappears.
    rea_gset "$s" toggle-overview          "$(rea_strv '<Super>space' '<Control>Up')"
    rea_gset "$w" switch-input-source      "$(rea_strv '<Super><Alt>space')"
    rea_gset "$w" switch-input-source-backward "$(rea_strv '<Shift><Super><Alt>space')"
    rea_info "Super+Space searches; input-source switching moved to Super+Alt+Space"
  else
    rea_gset "$s" toggle-overview          "$(rea_strv '<Control>Up')"
  fi
  rea_gset "$s" toggle-application-view    "$(rea_strv '<Super>a')"   # Launchpad

  # ---- Spaces -------------------------------------------------------------
  if [[ "${REA_SPACES_CTRL_ARROWS:-0}" == "1" ]]; then
    # Authentic, but Ctrl+Left/Right are word-motion keys in terminals and
    # editors. Opt-in only.
    rea_gset "$w" switch-to-workspace-left  "$(rea_strv '<Control>Left')"
    rea_gset "$w" switch-to-workspace-right "$(rea_strv '<Control>Right')"
    rea_warn "Ctrl+Left/Right now switch spaces and no longer reach the terminal"
  else
    rea_gset "$w" switch-to-workspace-left  "$(rea_strv '<Control><Alt>Left' '<Control><Super>Left')"
    rea_gset "$w" switch-to-workspace-right "$(rea_strv '<Control><Alt>Right' '<Control><Super>Right')"
  fi
  rea_gset "$w" move-to-workspace-left  "$(rea_strv '<Shift><Control><Alt>Left')"
  rea_gset "$w" move-to-workspace-right "$(rea_strv '<Shift><Control><Alt>Right')"

  # ---- Screenshots (Command+Shift+3/4/5) ---------------------------------
  rea_gset "$s" screenshot                 "$(rea_strv '<Shift><Super>3')"
  rea_gset "$s" show-screenshot-ui         "$(rea_strv '<Shift><Super>4' '<Shift><Super>5')"
  rea_gset "$s" screenshot-window          "$(rea_strv '<Shift><Control><Super>4')"

  # ---- Lock and Finder ----------------------------------------------------
  rea_gset "$m" screensaver                "$(rea_strv '<Control><Super>q')"
  rea_gset "$m" home                       "$(rea_strv '<Super>e')"

  rea_ok "Keyboard map applied (Super behaves as Command)"
}

# rea_wm_shortcut_table - printed at the end of an install and by `rea help`.
rea_wm_shortcut_table() {
  cat <<'TABLE'
  Super+Q / Super+W      Close window
  Super+H / Super+M      Minimise
  Super+Tab              Switch applications      (Alt+Tab still works)
  Super+`                Cycle windows of the app
  Super+Space            Search                   (Spotlight)
  Super+A                All applications         (Launchpad)
  Ctrl+Up                Overview                 (Mission Control)
  Ctrl+Alt+Left/Right    Previous / next space
  Ctrl+Super+F           Full screen
  Super+D                Show desktop
  Super+E                Home folder
  Shift+Super+3          Screenshot whole screen
  Shift+Super+4 or 5     Screenshot / record UI
  Ctrl+Super+Q           Lock screen
  Super+Alt+Space        Switch input source
TABLE
}
