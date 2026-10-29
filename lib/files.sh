#!/usr/bin/env bash
# files.sh - Nautilus, configured to work the way Finder does.
#
# Linux filesystem semantics are left completely alone: hidden files are still
# hidden-by-dot and still toggle with Ctrl+H, symlinks are still symlinks,
# permissions are untouched, and "Delete permanently" stays available because
# removing it would be a worse file manager, not a more Mac-like one.

rea_files_install() {
  # gnome-sushi is the genuine Quick Look equivalent: select a file, press
  # Space, get a preview. It is in Ubuntu's own archive.
  rea_pkg_ensure "file previews (Quick Look with Space)" gnome-sushi || true
  # Terminal in the context menu - the Finder "New Terminal at Folder" habit.
  rea_pkg_ensure "terminal in the file manager context menu" nautilus-extension-gnome-terminal || true
}

rea_files_configure() {
  local p=org.gnome.nautilus.preferences

  # ---- views --------------------------------------------------------------
  rea_gset "$p" default-folder-viewer "'list-view'"        # Finder opens in list view
  rea_gset "$p" search-view "'list-view'"
  rea_gset "$p" show-image-thumbnails "'local-only'"       # no thumbnailing over the network
  rea_gset "$p" thumbnail-limit "uint64 50"                # MB; keeps large media snappy
  rea_gset "$p" show-directory-item-counts "'local-only'"
  rea_gset "$p" show-delete-permanently true
  rea_gset "$p" show-create-link true
  rea_gset "$p" recursive-search "'local-only'"
  rea_gset "$p" click-policy "'double'"
  rea_gset "$p" open-folder-on-dnd-hover true
  rea_gset "$p" date-time-format "'detailed'"
  rea_gset "$p" migrated-gtk-settings true

  # ---- list view: the disclosure-triangle tree is the Finder behaviour ----
  rea_gset org.gnome.nautilus.list-view use-tree-view true
  rea_gset org.gnome.nautilus.list-view default-zoom-level "'small'"
  rea_gset org.gnome.nautilus.list-view default-visible-columns \
    "$(rea_strv name size type date_modified)"
  rea_gset org.gnome.nautilus.list-view default-column-order \
    "$(rea_strv name size type date_modified date_accessed owner group permissions)"

  rea_gset org.gnome.nautilus.icon-view default-zoom-level "'small'"
  rea_gset org.gnome.nautilus.icon-view captions "$(rea_strv size none none)"

  # ---- window ------------------------------------------------------------
  rea_gset org.gnome.nautilus.window-state start-with-sidebar true
  rea_gset org.gnome.nautilus.window-state sidebar-width 190
  rea_gset org.gnome.nautilus.window-state maximized false
  rea_gset org.gnome.nautilus.window-state initial-size "(1000, 650)"

  # ---- file chooser dialogs match the file manager -----------------------
  local fc
  for fc in org.gtk.Settings.FileChooser org.gtk.gtk4.Settings.FileChooser; do
    rea_gset "$fc" sort-directories-first true
    rea_gset "$fc" show-hidden false
    rea_gset "$fc" location-mode "'path-bar'"       # breadcrumbs, not a URI box
  done
  rea_gset org.gnome.nautilus.preferences sort-directories-first true

  rea_ok "File manager configured (list view, tree, breadcrumbs, 190px sidebar)"
}

# rea_files_bookmarks - adds the Finder sidebar set, additively. Existing
# bookmarks keep their order and nothing is ever removed.
rea_files_bookmarks() {
  local bm="$HOME/.config/gtk-3.0/bookmarks" dir added=0 uri key
  local -a wanted=()

  if have xdg-user-dir; then
    for key in DOWNLOAD DOCUMENTS PICTURES MUSIC VIDEOS DESKTOP; do
      dir="$(xdg-user-dir "$key" 2>/dev/null)"
      [[ -n "$dir" && -d "$dir" && "$dir" != "$HOME" ]] && wanted+=("$dir")
    done
  else
    for dir in Downloads Documents Pictures Music Videos Desktop; do
      [[ -d "$HOME/$dir" ]] && wanted+=("$HOME/$dir")
    done
  fi
  ((${#wanted[@]})) || { rea_skip "No standard folders to add to the sidebar"; return 0; }

  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would add ${#wanted[@]} sidebar bookmark(s)"
    return 0
  fi

  mkdir -p "$(dirname "$bm")"
  touch "$bm"
  for dir in "${wanted[@]}"; do
    uri="file://$dir"
    grep -qF "$uri" "$bm" 2>/dev/null && continue
    printf '%s\n' "$uri" >>"$bm"
    added=$((added + 1))
  done
  if ((added)); then
    rea_record file "$bm"
    rea_ok "Added $added folder(s) to the sidebar"
  else
    rea_skip "Sidebar already lists the standard folders"
  fi
}
