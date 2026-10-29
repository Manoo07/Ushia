#!/usr/bin/env bash
# gset.sh - safe gsettings/dconf writers.
#
# Every write is guarded: a key that does not exist on this GNOME version is
# skipped with a note instead of aborting the install. That is what lets one
# script cover GNOME 42 through 48.

REA_SCHEMA_CACHE=""
REA_GSET_APPLIED=0
REA_GSET_SKIPPED=0

_gset_schemas() {
  [[ -n "$REA_SCHEMA_CACHE" ]] && { printf '%s' "$REA_SCHEMA_CACHE"; return 0; }
  have gsettings || return 1
  REA_SCHEMA_CACHE="$(gsettings list-schemas 2>/dev/null | paste -sd ',' -)"
  printf '%s' "$REA_SCHEMA_CACHE"
}

rea_schema_exists() {
  local all; all="$(_gset_schemas)" || return 1
  case ",$all," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

rea_key_exists() {
  have gsettings || return 1
  gsettings list-keys "$1" 2>/dev/null | grep -qx "$2"
}

# rea_gset <schema> <key> <value>
rea_gset() {
  local schema="$1" key="$2" val="$3" old=""
  if ! rea_schema_exists "$schema"; then
    REA_GSET_SKIPPED=$((REA_GSET_SKIPPED + 1))
    _rea_write_log "GSET? missing schema $schema"
    return 0
  fi
  if ! rea_key_exists "$schema" "$key"; then
    REA_GSET_SKIPPED=$((REA_GSET_SKIPPED + 1))
    _rea_write_log "GSET? missing key $schema $key"
    return 0
  fi
  old="$(gsettings get "$schema" "$key" 2>/dev/null)"
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ gsettings set %s %s %s%s\n' "$C_DIM" "$schema" "$key" "$val" "$C_RESET" >&2
    return 0
  fi
  if gsettings set "$schema" "$key" "$val" 2>>"${REA_LOG_FILE:-/dev/null}"; then
    REA_GSET_APPLIED=$((REA_GSET_APPLIED + 1))
    _rea_write_log "GSET  $schema $key: $old -> $val"
  else
    rea_warn "Could not set $schema $key"
  fi
}

# rea_gset_in <schemadir> <schema> <key> <value>
# For extension schemas that are not installed system-wide.
rea_gset_in() {
  local dir="$1" schema="$2" key="$3" val="$4"
  if [[ ! -d "$dir" ]]; then
    REA_GSET_SKIPPED=$((REA_GSET_SKIPPED + 1))
    _rea_write_log "GSET? missing schemadir $dir"
    return 0
  fi
  if ! gsettings --schemadir "$dir" list-keys "$schema" 2>/dev/null | grep -qx "$key"; then
    REA_GSET_SKIPPED=$((REA_GSET_SKIPPED + 1))
    _rea_write_log "GSET? missing key $schema $key (in $dir)"
    return 0
  fi
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ gsettings --schemadir %s set %s %s %s%s\n' "$C_DIM" "$dir" "$schema" "$key" "$val" "$C_RESET" >&2 >&2
    return 0
  fi
  if gsettings --schemadir "$dir" set "$schema" "$key" "$val" 2>>"${REA_LOG_FILE:-/dev/null}"; then
    REA_GSET_APPLIED=$((REA_GSET_APPLIED + 1))
    _rea_write_log "GSET  $schema $key -> $val"
  else
    rea_warn "Could not set $schema $key"
  fi
}

# rea_ext_schemadir <uuid> - schema directory of an installed extension.
rea_ext_schemadir() {
  local uuid="$1" d
  for d in "$HOME/.local/share/gnome-shell/extensions/$uuid/schemas" \
           "/usr/share/gnome-shell/extensions/$uuid/schemas"; do
    [[ -d "$d" ]] && { printf '%s' "$d"; return 0; }
  done
  return 1
}

# rea_gset_ext <uuid> <schema> <key> <value> - prefers the system schema, falls
# back to the extension's own schema directory.
rea_gset_ext() {
  local uuid="$1" schema="$2" key="$3" val="$4" dir
  if rea_schema_exists "$schema"; then rea_gset "$schema" "$key" "$val"; return 0; fi
  if dir="$(rea_ext_schemadir "$uuid")"; then rea_gset_in "$dir" "$schema" "$key" "$val"; return 0; fi
  REA_GSET_SKIPPED=$((REA_GSET_SKIPPED + 1))
  _rea_write_log "GSET? no schema for $uuid/$schema"
  return 0
}

# rea_dconf_write <path> <gvariant>
rea_dconf_write() {
  have dconf || { rea_warn "dconf not installed; skipping $1"; return 0; }
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    printf '  %s$ dconf write %s %s%s\n' "$C_DIM" "$1" "$2" "$C_RESET" >&2
    return 0
  fi
  dconf write "$1" "$2" 2>>"${REA_LOG_FILE:-/dev/null}" \
    && REA_GSET_APPLIED=$((REA_GSET_APPLIED + 1)) \
    || rea_warn "Could not write $1"
}

rea_gset_summary() {
  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "dry run: no settings were written ($REA_GSET_SKIPPED key(s) would be skipped as unsupported here)"
  else
    rea_dim "settings applied: $REA_GSET_APPLIED, skipped as unsupported: $REA_GSET_SKIPPED"
  fi
}

# rea_strv <item...> - builds a GVariant string array: ['a','b']
rea_strv() {
  local out="[" first=1 i
  for i in "$@"; do
    [[ $first -eq 1 ]] || out+=", "
    out+="'${i//\'/\\\'}'"
    first=0
  done
  printf '%s]' "$out"
}
