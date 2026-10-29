#!/usr/bin/env bash
# backup.sh - snapshots of everything Rea is allowed to change, plus the
# receipt of what an install added (used by `rea uninstall`).

# Every dconf subtree Rea writes to. Snapshot and restore work path by path so
# a restore never touches settings outside this list.
REA_DCONF_PATHS=(
  /org/gnome/desktop/interface/
  /org/gnome/desktop/wm/preferences/
  /org/gnome/desktop/wm/keybindings/
  /org/gnome/desktop/peripherals/
  /org/gnome/desktop/background/
  /org/gnome/desktop/screensaver/
  /org/gnome/desktop/sound/
  /org/gnome/desktop/search-providers/
  /org/gnome/mutter/
  /org/gnome/shell/
  /org/gnome/nautilus/
  /org/gnome/settings-daemon/plugins/media-keys/
  /org/gtk/settings/file-chooser/
  /org/gtk/gtk4/settings/file-chooser/
)

# Config files Rea may replace. Copied verbatim into the snapshot.
REA_BACKUP_FILES=(
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-3.0/settings.ini"
  "$HOME/.config/gtk-4.0/gtk.css"
  "$HOME/.config/gtk-4.0/settings.ini"
  "$HOME/.config/fontconfig/fonts.conf"
  "$HOME/.config/fontconfig/conf.d/99-rea-rendering.conf"
  "$HOME/.config/gtk-3.0/bookmarks"
  "$HOME/.gtkrc-2.0"
  "$HOME/.config/environment.d/90-rea.conf"
)

REA_RECEIPT="$REA_STATE_DIR/receipt.tsv"

# --------------------------------------------------------------- receipt ----
# rea_record <kind> <value>   kinds: pkg, ext, dir, file, theme, icon, font
rea_record() {
  [[ "$REA_DRY_RUN" == "1" ]] && return 0
  mkdir -p "$REA_STATE_DIR"
  printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%Y-%m-%dT%H:%M:%S)" >>"$REA_RECEIPT"
}

rea_receipt_values() {
  [[ -r "$REA_RECEIPT" ]] || return 0
  awk -F'\t' -v k="$1" '$1==k{print $2}' "$REA_RECEIPT" | awk '!seen[$0]++'
}

# -------------------------------------------------------------- snapshots ----
rea_snapshot_create() {
  local label="${1:-manual}" id dir p name
  id="$(date +%Y%m%d-%H%M%S)-$label"
  dir="$REA_SNAPSHOT_DIR/$id"

  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would create snapshot $id"
    printf '%s' "$id"
    return 0
  fi

  mkdir -p "$dir/dconf" "$dir/files"

  # Full user dconf dump: the escape hatch if a targeted restore is not enough.
  if have dconf; then
    dconf dump / >"$dir/dconf/FULL.ini" 2>/dev/null || true
    for p in "${REA_DCONF_PATHS[@]}"; do
      name="$(printf '%s' "${p#/}" | tr '/' '.')"
      name="${name%.}"
      dconf dump "$p" >"$dir/dconf/$name.ini" 2>/dev/null || true
    done
  fi

  for p in "${REA_BACKUP_FILES[@]}"; do
    [[ -f "$p" ]] || continue
    name="${p#"$HOME"/}"
    mkdir -p "$dir/files/$(dirname "$name")"
    cp -a "$p" "$dir/files/$name" 2>/dev/null || true
  done

  # Inventory only (theme/icon trees can be hundreds of MB).
  ls -1 "$HOME/.themes" 2>/dev/null >"$dir/themes.list" || : >"$dir/themes.list"
  ls -1 "$HOME/.icons"  2>/dev/null >"$dir/icons.list"  || : >"$dir/icons.list"
  ls -1 "$HOME/.local/share/themes" 2>/dev/null >>"$dir/themes.list" || true
  ls -1 "$HOME/.local/share/icons"  2>/dev/null >>"$dir/icons.list"  || true
  ls -1 "$HOME/.local/share/gnome-shell/extensions" 2>/dev/null >"$dir/extensions.list" || : >"$dir/extensions.list"
  have gnome-extensions && gnome-extensions list --enabled >"$dir/extensions.enabled" 2>/dev/null || : >"$dir/extensions.enabled"
  have dpkg && dpkg -l >"$dir/dpkg.list" 2>/dev/null || true

  {
    printf 'id=%s\n' "$id"
    printf 'label=%s\n' "$label"
    printf 'created=%s\n' "$(date -Is)"
    printf 'rea_version=%s\n' "$REA_VERSION"
    printf 'gnome_shell=%s\n' "${REA_SYS_SHELL_VER:-unknown}"
    printf 'session=%s\n' "${REA_SYS_SESSION_TYPE:-unknown}"
    printf 'os=%s\n' "${REA_SYS_OS_NAME:-unknown}"
  } >"$dir/manifest.conf"

  printf '%s' "$id"
}

rea_snapshot_list() {
  [[ -d "$REA_SNAPSHOT_DIR" ]] || return 0
  find "$REA_SNAPSHOT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
    || ls -1 "$REA_SNAPSHOT_DIR" 2>/dev/null
}

rea_snapshot_latest() { rea_snapshot_list | sort | tail -n1; }

rea_snapshot_restore() {
  local id="$1" dir p name restored=0
  dir="$REA_SNAPSHOT_DIR/$id"
  [[ -d "$dir" ]] || { rea_err "No such snapshot: $id"; return 1; }

  rea_info "Restoring snapshot $id"

  if have dconf; then
    for p in "${REA_DCONF_PATHS[@]}"; do
      name="$(printf '%s' "${p#/}" | tr '/' '.')"; name="${name%.}"
      [[ -f "$dir/dconf/$name.ini" ]] || continue
      run dconf reset -f "$p"
      if [[ "$REA_DRY_RUN" == "1" ]]; then
        rea_dim "would load $dir/dconf/$name.ini into $p"
      elif [[ -s "$dir/dconf/$name.ini" ]]; then
        dconf load "$p" <"$dir/dconf/$name.ini" 2>/dev/null \
          && restored=$((restored + 1)) \
          || rea_warn "Could not restore dconf path $p"
      else
        restored=$((restored + 1))   # path was empty before; reset is correct
      fi
    done
    rea_ok "Restored $restored dconf subtree(s)"
  else
    rea_warn "dconf not available; settings were not restored"
  fi

  if [[ -d "$dir/files" ]]; then
    local files=0
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      files=$((files + 1))
      if [[ "$REA_DRY_RUN" == "1" ]]; then
        rea_dim "would restore ~/$name"
      else
        mkdir -p "$HOME/$(dirname "$name")"
        cp -a "$dir/files/$name" "$HOME/$name"
      fi
    done < <(cd "$dir/files" && find . -type f 2>/dev/null | sed 's|^\./||')
    ((files)) && rea_ok "Restored $files config file(s)" || rea_skip "No config files were in this snapshot"
  fi

  # Files that did not exist at snapshot time but exist now must go, or a
  # leftover gtk.css keeps overriding the restored theme.
  for p in "${REA_BACKUP_FILES[@]}"; do
    name="${p#"$HOME"/}"
    if [[ -f "$p" && ! -f "$dir/files/$name" ]]; then
      case "$p" in
        *rea*) run rm -f "$p" ;;
        *) if grep -q 'rea:managed' "$p" 2>/dev/null; then run rm -f "$p"; fi ;;
      esac
    fi
  done
  return 0
}

rea_snapshot_info() {
  local id="$1" dir="$REA_SNAPSHOT_DIR/$1"
  [[ -d "$dir" ]] || { rea_err "No such snapshot: $id"; return 1; }
  sed 's/^/  /' "$dir/manifest.conf"
  printf '  size=%s\n' "$(du -sh "$dir" 2>/dev/null | cut -f1)"
}
