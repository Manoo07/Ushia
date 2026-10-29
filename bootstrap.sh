#!/usr/bin/env bash
# bootstrap.sh - get Rea onto a machine and run the readiness check.
#
# Read this before running it. It does four things, all in $HOME:
#   1. checks for git and curl
#   2. clones Rea to ~/.local/share/rea/src
#   3. links the `rea` command into ~/.local/bin
#   4. runs `rea doctor`
#
# It installs nothing else and changes no settings. `rea install` is a separate,
# explicit step that you run yourself afterwards.
set -euo pipefail

REPO="${REA_REPO:-https://github.com/morluto/rea.git}"
REF="${REA_REF:-main}"
SRC="${REA_SRC:-$HOME/.local/share/rea/src}"
BIN="${REA_BIN:-$HOME/.local/bin}"

say()  { printf '  %s\n' "$1"; }
die()  { printf '  error: %s\n' "$1" >&2; exit 1; }

printf '\n\033[1mRea\033[0m - a macOS-style desktop for Ubuntu\n\n'

for t in git curl; do
  command -v "$t" >/dev/null 2>&1 || die "$t is required. Install it with: sudo apt install $t"
done

if [[ -d "$SRC/.git" ]]; then
  say "Updating $SRC"
  git -C "$SRC" fetch --quiet origin "$REF"
  git -C "$SRC" checkout --quiet "$REF"
  git -C "$SRC" pull --quiet --ff-only origin "$REF" || say "Could not fast-forward; keeping the local copy"
else
  say "Cloning into $SRC"
  mkdir -p "$(dirname "$SRC")"
  git clone --quiet --branch "$REF" --depth 1 "$REPO" "$SRC"
fi

[[ -x "$SRC/rea" ]] || die "The clone looks wrong: no executable 'rea' in $SRC"

mkdir -p "$BIN"
ln -sf "$SRC/rea" "$BIN/rea"
say "Linked $BIN/rea"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    say ""
    say "$BIN is not on your PATH. Add it:"
    say "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && exec bash"
    ;;
esac

printf '\n'
"$SRC/rea" doctor || true

cat <<'NEXT'

  Next, in this order:

    rea audit            what you are running now
    rea snapshot         a restore point, before anything changes
    rea install          the real thing (it asks before each decision)
    rea install --dry-run   if you would rather read every command first

  Undo at any point:  rea rollback

NEXT
