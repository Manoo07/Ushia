#!/usr/bin/env bash
# fonts.sh - typography. Inter stands in for SF Pro (which Apple does not
# license for redistribution) and JetBrains Mono for SF Mono. Both are open
# licensed and installed per-user.

REA_FONT_DIR="$HOME/.local/share/fonts/rea"

rea_font_family_present() {
  have fc-list || return 1
  fc-list : family 2>/dev/null | tr ',' '\n' | grep -qix "$1"
}

# _fonts_place <srcdir> <name-prefix> - copies desktop font files, skipping the
# web formats and variable duplicates that confuse fontconfig.
_fonts_place() {
  local src="$1" prefix="$2" n=0 f
  mkdir -p "$REA_FONT_DIR"
  while IFS= read -r f; do
    case "$f" in
      */web/*|*/webfonts/*|*/web-*|*.woff|*.woff2) continue ;;
    esac
    cp -f "$f" "$REA_FONT_DIR/" 2>/dev/null && n=$((n + 1))
  done < <(find "$src" -type f \( -iname "${prefix}*.ttf" -o -iname "${prefix}*.otf" \) 2>/dev/null)
  printf '%s' "$n"
}

rea_fonts_install() {
  local src n total=0

  if rea_font_family_present "Inter" && [[ "${REA_FORCE:-0}" != "1" ]]; then
    rea_skip "Inter already installed"
  elif [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would install Inter $REA_INTER_VERSION"
  else
    if src="$(rea_fetch_zip inter "$REA_INTER_URL")"; then
      n="$(_fonts_place "$src" Inter)"
      if ((n > 0)); then
        total=$((total + n)); rea_record font "Inter"
        rea_ok "Installed Inter ($n files)"
      else
        rea_warn "Inter archive contained no desktop font files"
      fi
    else
      rea_warn "Could not download Inter; interface font will stay as it is"
    fi
  fi

  if rea_font_family_present "JetBrains Mono" && [[ "${REA_FORCE:-0}" != "1" ]]; then
    rea_skip "JetBrains Mono already installed"
  elif [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would install JetBrains Mono $REA_JBMONO_VERSION"
  else
    if src="$(rea_fetch_zip jbmono "$REA_JBMONO_URL")"; then
      n="$(_fonts_place "$src" JetBrainsMono)"
      if ((n > 0)); then
        total=$((total + n)); rea_record font "JetBrains Mono"
        rea_ok "Installed JetBrains Mono ($n files)"
      else
        rea_warn "JetBrains Mono archive contained no desktop font files"
      fi
    else
      rea_warn "Could not download JetBrains Mono; terminal font will stay as it is"
    fi
  fi

  if ((total > 0)) && [[ "$REA_DRY_RUN" != "1" ]]; then
    run fc-cache -f "$REA_FONT_DIR" || rea_warn "fc-cache failed; new fonts may need a logout"
    rea_record dir "$REA_FONT_DIR"
  fi
  return 0
}

# rea_fonts_rendering - fontconfig rules: subpixel rendering plus aliases so
# apps asking for Apple font names (Electron, web apps, imported CSS) resolve
# to the installed stand-ins instead of falling back to DejaVu.
rea_fonts_rendering() {
  local dest="$HOME/.config/fontconfig/conf.d/99-rea-rendering.conf"
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would write $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -f "$REA_CONFIG_DIR/fonts/99-rea-rendering.conf" "$dest"
  rea_record file "$dest"
  run fc-cache -f || true
  rea_ok "Configured font rendering and Apple-name aliases"
}

rea_fonts_apply() {
  local ui="${REA_FONT_UI:-Inter 11}" mono="${REA_FONT_MONO:-JetBrains Mono 11}"

  # Fall back if the profile asked for a family this release does not ship.
  if [[ "$ui" == "Inter Display"* ]] && ! rea_font_family_present "Inter Display"; then
    ui="${REA_FONT_UI_FALLBACK:-Inter 11}"
    rea_dim "Inter Display not present; using $ui"
  fi
  if [[ "$ui" == Inter* ]] && ! rea_font_family_present "Inter"; then
    ui="Cantarell 11"; rea_warn "Inter missing; interface font left at $ui"
  fi
  if [[ "$mono" == JetBrains* ]] && ! rea_font_family_present "JetBrains Mono"; then
    mono="Ubuntu Mono 13"; rea_warn "JetBrains Mono missing; monospace font left at $mono"
  fi

  rea_gset org.gnome.desktop.interface font-name "$ui"
  rea_gset org.gnome.desktop.interface document-font-name "$ui"
  rea_gset org.gnome.desktop.interface monospace-font-name "$mono"
  rea_gset org.gnome.desktop.wm.preferences titlebar-font "${ui%% *} Semi Bold ${ui##* }"
  rea_gset org.gnome.desktop.interface font-antialiasing "${REA_FONT_ANTIALIAS:-rgba}"
  rea_gset org.gnome.desktop.interface font-hinting "${REA_FONT_HINTING:-slight}"

  # macOS sets slightly looser interface text; 1.0 keeps parity at 11pt Inter.
  rea_gset org.gnome.desktop.interface text-scaling-factor "${REA_TEXT_SCALE:-1.0}"
  rea_ok "Typography: $ui, mono $mono"
}
