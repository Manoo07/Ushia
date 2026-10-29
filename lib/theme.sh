#!/usr/bin/env bash
# theme.sh - GTK/shell theme, icons, cursors, and the CSS overrides that carry
# Rea's design tokens into apps the theme does not cover.
#
# Everything installs under $HOME. No system directory is written to, so a
# broken theme can never stop the machine from booting.

REA_THEME_LIGHT=""
REA_THEME_DARK=""
REA_ICONS_LIGHT=""
REA_ICONS_DARK=""

# _theme_find <dir> <glob> - first matching basename, or empty.
_theme_find() {
  local d="$1" g="$2" p
  for p in "$d"/$g; do [[ -d "$p" ]] && { basename "$p"; return 0; }; done
  return 1
}

rea_theme_detect_installed() {
  local d
  for d in "$HOME/.themes" "$HOME/.local/share/themes" /usr/share/themes; do
    [[ -d "$d" ]] || continue
    [[ -n "$REA_THEME_LIGHT" ]] || REA_THEME_LIGHT="$(_theme_find "$d" 'WhiteSur-Light*' || true)"
    [[ -n "$REA_THEME_DARK"  ]] || REA_THEME_DARK="$(_theme_find "$d" 'WhiteSur-Dark*' || true)"
  done
  for d in "$HOME/.icons" "$HOME/.local/share/icons" /usr/share/icons; do
    [[ -d "$d" ]] || continue
    [[ -n "$REA_ICONS_DARK"  ]] || REA_ICONS_DARK="$(_theme_find "$d" 'WhiteSur-dark' || true)"
    [[ -n "$REA_ICONS_LIGHT" ]] || REA_ICONS_LIGHT="$(_theme_find "$d" 'WhiteSur' || true)"
  done
  [[ -n "$REA_THEME_LIGHT$REA_THEME_DARK" ]]
}

rea_theme_deps() {
  # sassc + glib-compile-resources are what the upstream theme builder needs.
  rea_pkg_ensure "theme building" sassc libglib2.0-dev-bin libxml2-utils git unzip curl || true
}

rea_theme_install_gtk() {
  local src rc=0
  rea_theme_detect_installed
  if [[ -n "$REA_THEME_LIGHT" && -n "$REA_THEME_DARK" && "${REA_FORCE:-0}" != "1" ]]; then
    rea_skip "GTK theme already installed ($REA_THEME_LIGHT / $REA_THEME_DARK)"
    return 0
  fi

  src="$(rea_fetch_git whitesur-gtk "$REA_WHITESUR_REPO" "$REA_WHITESUR_REF" install.sh)" || return 1
  [[ "$REA_DRY_RUN" == "1" ]] && { rea_dim "would build WhiteSur into ~/.themes"; return 0; }

  rea_info "Building the theme (this is the slow step, 1-3 minutes)"
  # -l  also theme libadwaita/GTK4 apps
  # -c  build both appearances so light/dark switching is instant
  # -N glassy  translucent Nautilus sidebar
  ( cd "$src" && run_show ./install.sh -c Light -c Dark -l -N glassy ) || rc=1

  if ((rc)); then
    rea_warn "Upstream installer flags were rejected; retrying with defaults"
    rc=0
    ( cd "$src" && run_show ./install.sh ) || rc=1
  fi

  rea_theme_detect_installed || rc=1
  if ((rc)) || [[ -z "$REA_THEME_LIGHT" ]]; then
    rea_err "Theme build did not produce ~/.themes/WhiteSur-*"
    return 1
  fi
  rea_record theme "$REA_THEME_LIGHT"
  rea_record theme "$REA_THEME_DARK"
  rea_record dir "$HOME/.themes/$REA_THEME_LIGHT"
  rea_record dir "$HOME/.themes/$REA_THEME_DARK"
  rea_ok "Installed $REA_THEME_LIGHT and $REA_THEME_DARK"
}

rea_theme_install_icons() {
  local src rc=0
  rea_theme_detect_installed
  if [[ -n "$REA_ICONS_LIGHT" && "${REA_FORCE:-0}" != "1" ]]; then
    rea_skip "Icon theme already installed ($REA_ICONS_LIGHT)"
    return 0
  fi
  src="$(rea_fetch_git whitesur-icons "$REA_WHITESUR_ICONS_REPO" "$REA_WHITESUR_ICONS_REF" install.sh)" || return 1
  [[ "$REA_DRY_RUN" == "1" ]] && { rea_dim "would install WhiteSur icons into ~/.icons"; return 0; }

  # -a all folder colour variants, -b also link the default theme's fallbacks
  ( cd "$src" && run_show ./install.sh -a ) || rc=1
  ((rc)) && { rea_warn "Icon installer flags rejected; retrying plain"; rc=0; ( cd "$src" && run_show ./install.sh ) || rc=1; }

  REA_ICONS_LIGHT=""; REA_ICONS_DARK=""
  rea_theme_detect_installed
  if ((rc)) || [[ -z "$REA_ICONS_LIGHT" ]]; then
    rea_err "Icon install did not produce an icon theme"
    return 1
  fi
  rea_record icon "$REA_ICONS_LIGHT"
  rea_record dir "$HOME/.local/share/icons/$REA_ICONS_LIGHT"
  rea_ok "Installed icon theme $REA_ICONS_LIGHT"
}

rea_theme_install_cursors() {
  local src rc=0 dest
  dest="$HOME/.local/share/icons"
  if [[ -d "$dest/McMojave-cursors" && "${REA_FORCE:-0}" != "1" ]]; then
    rea_skip "Cursor theme already installed"
    return 0
  fi
  src="$(rea_fetch_git mcmojave-cursors "$REA_CURSORS_REPO" "$REA_CURSORS_REF" install.sh)" || return 1
  [[ "$REA_DRY_RUN" == "1" ]] && { rea_dim "would install McMojave cursors"; return 0; }
  ( cd "$src" && run_show ./install.sh ) || rc=1
  if ((rc)); then rea_warn "Cursor install failed; keeping the current cursors"; return 1; fi
  rea_record icon "McMojave-cursors"
  rea_ok "Installed McMojave cursors"
}

# rea_theme_apply <light|dark>
rea_theme_apply() {
  local mode="$1" gtk icons scheme
  rea_theme_detect_installed || { rea_warn "No WhiteSur theme found to apply"; return 1; }

  if [[ "$mode" == "dark" ]]; then
    gtk="${REA_THEME_DARK:-$REA_THEME_LIGHT}"
    icons="${REA_ICONS_DARK:-$REA_ICONS_LIGHT}"
    scheme="prefer-dark"
  else
    gtk="${REA_THEME_LIGHT:-$REA_THEME_DARK}"
    icons="${REA_ICONS_LIGHT:-$REA_ICONS_DARK}"
    scheme="prefer-light"
  fi

  rea_gset org.gnome.desktop.interface color-scheme "$scheme"
  rea_gset org.gnome.desktop.interface gtk-theme "$gtk"
  [[ -n "$icons" ]] && rea_gset org.gnome.desktop.interface icon-theme "$icons"
  [[ -d "$HOME/.local/share/icons/McMojave-cursors" || -d "$HOME/.icons/McMojave-cursors" ]] \
    && rea_gset org.gnome.desktop.interface cursor-theme "McMojave-cursors"
  rea_gset org.gnome.desktop.interface cursor-size 24

  # The shell theme needs the User Themes extension; if it is not on yet the
  # value still sticks and takes effect at login.
  rea_gset_ext "$REA_EXT_USER_THEME" org.gnome.shell.extensions.user-theme name "$gtk"

  # GTK2 holdouts (a shrinking set, but Wireshark and friends still exist).
  if [[ "$REA_DRY_RUN" != "1" ]]; then
    atomic_write "$HOME/.gtkrc-2.0" <<GTKRC
# rea:managed - delete this file or run 'rea rollback' to revert
gtk-theme-name="$gtk"
gtk-icon-theme-name="${icons:-Adwaita}"
gtk-font-name="${REA_FONT_UI:-Inter 11}"
gtk-cursor-theme-name="McMojave-cursors"
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgba"
GTKRC
  fi
  rea_ok "Applied $mode appearance ($gtk)"
}

# rea_theme_css - Rea's own design tokens: corner radii, spacing and control
# metrics the upstream theme leaves at GNOME defaults.
rea_theme_css() {
  local v
  for v in 3.0 4.0; do
    if [[ "$REA_DRY_RUN" == "1" ]]; then
      rea_dim "would write ~/.config/gtk-$v/gtk.css"
      continue
    fi
    mkdir -p "$HOME/.config/gtk-$v"
    {
      printf '/* rea:managed - Rea design tokens. Run `rea rollback` to revert. */\n'
      cat "$REA_CONFIG_DIR/gtk/tokens.css"
      cat "$REA_CONFIG_DIR/gtk/overrides.css"
      [[ "$v" == "4.0" ]] && cat "$REA_CONFIG_DIR/gtk/gtk4.css"
    } >"$HOME/.config/gtk-$v/gtk.css"
  done
  rea_ok "Wrote GTK3 and GTK4 style overrides"
}

# rea_theme_flatpak - Flatpak apps have their own filesystem view, so they need
# explicit access to the theme or they fall back to Adwaita.
rea_theme_flatpak() {
  have flatpak || { rea_skip "No Flatpak installed"; return 0; }
  rea_theme_detect_installed || return 0
  local gtk="${REA_THEME_LIGHT:-WhiteSur-Light}"
  run flatpak override --user --filesystem="$HOME/.themes:ro" || true
  run flatpak override --user --filesystem="$HOME/.icons:ro" || true
  run flatpak override --user --filesystem="$HOME/.local/share/icons:ro" || true
  run flatpak override --user --filesystem="$HOME/.local/share/fonts:ro" || true
  run flatpak override --user --env=GTK_THEME="$gtk" || true
  rea_record flatpak-override "user"
  rea_ok "Gave Flatpak apps access to the theme and fonts"
}

rea_theme_flatpak_reset() {
  have flatpak || return 0
  run flatpak override --user --reset || true
  rea_ok "Reset Flatpak overrides"
}
