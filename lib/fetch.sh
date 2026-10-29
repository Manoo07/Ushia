#!/usr/bin/env bash
# fetch.sh - downloads. Each source lands in its own empty directory under the
# cache so one archive can never overwrite another's files.

REA_CACHE_DIR="$REA_STATE_DIR/cache"

rea_cache_dir_for() {
  local key="$1" dir="$REA_CACHE_DIR/$1"
  rm -rf "$dir" 2>/dev/null || true
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# rea_fetch_git <key> <repo> <ref> <must-contain> - echoes the checkout path.
rea_fetch_git() {
  local key="$1" repo="$2" ref="$3" must="$4" dir
  have git || { rea_err "git is required to fetch $key"; return 1; }
  dir="$(rea_cache_dir_for "$key")"

  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would clone $repo @ $ref"
    printf '%s' "$dir"
    return 0
  fi

  rea_dim "fetching $key ($ref)"
  if ! run git clone --quiet --depth 1 --branch "$ref" "$repo" "$dir"; then
    rea_warn "Could not fetch $key at '$ref'; retrying on the default branch"
    rm -rf "$dir"; mkdir -p "$dir"
    run git clone --quiet --depth 1 "$repo" "$dir" || { rea_err "Clone failed: $repo"; return 1; }
  fi

  if [[ -n "$must" && ! -e "$dir/$must" ]]; then
    rea_err "$key checkout looks wrong: no '$must' inside. Refusing to use it."
    return 1
  fi
  printf '%s' "$dir"
}

# rea_fetch_zip <key> <url> - unpacks into its own directory, echoes the path.
rea_fetch_zip() {
  local key="$1" url="$2" dir zip
  have curl  || { rea_err "curl is required to fetch $key"; return 1; }
  have unzip || { rea_err "unzip is required to unpack $key"; return 1; }
  dir="$(rea_cache_dir_for "$key")"
  zip="$dir/archive.zip"

  if [[ "$REA_DRY_RUN" == "1" ]]; then
    rea_dim "would download $url"
    printf '%s' "$dir"
    return 0
  fi

  rea_dim "downloading $key"
  if ! run curl -fsSL --retry 2 --max-time 180 -o "$zip" "$url"; then
    rea_err "Download failed: $url"
    return 1
  fi
  if ! run unzip -qq -o "$zip" -d "$dir"; then
    rea_err "Could not unpack $key"
    return 1
  fi
  rm -f "$zip"
  printf '%s' "$dir"
}

rea_cache_clean() {
  [[ -d "$REA_CACHE_DIR" ]] || return 0
  run rm -rf "$REA_CACHE_DIR"
}
