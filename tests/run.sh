#!/usr/bin/env bash
# tests/run.sh - everything that can be checked without a GNOME session.
# Run from anywhere: tests/run.sh
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT" || exit 1

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# assert <desc> <command...>
assert() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# assert_eq <desc> <expected> <actual>
assert_eq() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}

head_ "Syntax"
while IFS= read -r f; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done < <(printf '%s\n' rea bootstrap.sh lib/*.sh config/*.conf config/profiles/*.conf tests/run.sh)

head_ "Shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -x -S warning -e SC1090,SC1091,SC2034 rea lib/*.sh bootstrap.sh tests/run.sh; then
    ok "shellcheck clean at warning level"
  else
    bad "shellcheck findings above"
  fi
else
  printf '  - shellcheck not installed; skipped\n'
fi

head_ "Assets"
for f in config/fonts/99-rea-rendering.conf config/assets/rea-light.svg config/assets/rea-dark.svg; do
  assert "$f parses as XML" python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$f"
done
for f in config/gtk/tokens.css config/gtk/overrides.css config/gtk/gtk4.css; do
  # Braces must balance, or GTK silently drops the rest of the file.
  o="$(tr -cd '{' <"$f" | wc -c)"; c="$(tr -cd '}' <"$f" | wc -c)"
  assert_eq "$f braces balance" "$o" "$c"
done
assert "tokens.css defines the accent" grep -q 'rea_accent' config/gtk/tokens.css
assert "overrides.css uses the accent token" grep -q '@rea_accent' config/gtk/overrides.css

head_ "Profiles"
for p in full balanced lite; do
  f="config/profiles/$p.conf"
  assert "$p exists" test -r "$f"
  for key in REA_PROFILE_NAME REA_PROFILE_DESC REA_DOCK_FLAVOUR REA_DOCK_ICON_SIZE \
             REA_BLUR REA_ANIMATIONS REA_FONT_UI REA_FONT_MONO REA_PANEL_SIZE; do
    assert "$p defines $key" grep -q "^$key=" "$f"
  done
done
assert "lite disables blur" grep -q '^REA_BLUR=0' config/profiles/lite.conf
assert "lite drops magnification" grep -q '^REA_DOCK_MAGNIFY=0' config/profiles/lite.conf

head_ "Manifest"
assert "manifest pins the theme ref" grep -qE '^: "\$\{REA_WHITESUR_REF:=' config/manifest.conf
assert "manifest names no PPA" bash -c '! grep -qi "ppa:" config/manifest.conf'
assert "no apt-add-repository anywhere" bash -c '! grep -rqi "add-apt-repository" rea lib/ bootstrap.sh'
assert "no curl-pipe-to-shell anywhere" bash -c '! grep -rqE "curl[^|]*\| *(ba)?sh" lib/ rea'

head_ "Pure functions"
if ((BASH_VERSINFO[0] >= 4)); then
  REA_ROOT="$ROOT"
  # shellcheck source=/dev/null
  . lib/core.sh
  assert_eq "version_ge 46 42"      "yes" "$(version_ge 46 42 && echo yes || echo no)"
  assert_eq "version_ge 42 46"      "no"  "$(version_ge 42 46 && echo yes || echo no)"
  assert_eq "version_ge 46.2 46.2"  "yes" "$(version_ge 46.2 46.2 && echo yes || echo no)"
  assert_eq "version_ge 3.38 42"    "no"  "$(version_ge 3.38 42 && echo yes || echo no)"
  assert_eq "json_escape quotes"    'a\"b' "$(json_escape 'a"b')"
  assert_eq "json_escape backslash" 'a\\b' "$(json_escape 'a\b')"
  # shellcheck source=/dev/null
  . lib/gset.sh
  assert_eq "rea_strv one"  "['<Super>q']" "$(rea_strv '<Super>q')"
  assert_eq "rea_strv many" "['a', 'b']"   "$(rea_strv a b)"
  assert_eq "rea_strv empty" "[]"          "$(rea_strv)"
else
  printf '  - bash %s is too old for the function tests; skipped\n' "${BASH_VERSION%%(*}"
fi

head_ "CLI surface"
if ((BASH_VERSINFO[0] >= 4)); then
  assert "rea version"            ./rea version
  assert "rea help"               ./rea help
  assert "rea shortcuts"          ./rea shortcuts
  assert "rea audit"              ./rea audit
  assert "rea audit --json parses" bash -c './rea audit --json | python3 -c "import json,sys; json.load(sys.stdin)"'
  assert "rea profile list"       ./rea profile list
  assert "rea profile show"       ./rea profile show
  assert "rea snapshots"          ./rea snapshots
  assert "unknown command fails"  bash -c '! ./rea definitely-not-a-command'
  assert "unknown option fails"   bash -c '! ./rea audit --nonsense'
  assert "dry-run install completes" bash -c './rea install balanced --dry-run -y --force >/dev/null 2>&1'
  # bootstrap.sh links the command into ~/.local/bin, so lib/ must still be
  # found through a symlink. This broke once; it stays tested.
  assert "runs through a symlink" bash -c '
    d="$(mktemp -d)"; ln -s "$PWD/rea" "$d/rea"
    "$d/rea" version >/dev/null && "$d/rea" audit >/dev/null
    rc=$?; rm -rf "$d"; exit $rc'
  assert "runs through a symlink to a symlink" bash -c '
    d="$(mktemp -d)"; ln -s "$PWD/rea" "$d/rea1"; ln -s "$d/rea1" "$d/rea2"
    "$d/rea2" version >/dev/null
    rc=$?; rm -rf "$d"; exit $rc'
  assert "dry-run writes nothing to ~/.config/gtk-3.0" bash -c '
    before="$(ls ~/.config/gtk-3.0 2>/dev/null | sort)"
    ./rea install lite --dry-run -y --force >/dev/null 2>&1
    after="$(ls ~/.config/gtk-3.0 2>/dev/null | sort)"
    [[ "$before" == "$after" ]]'
else
  printf '  - bash %s is too old for the CLI tests; skipped\n' "${BASH_VERSION%%(*}"
fi

head_ "Docs"
for d in architecture implementation-plan design-system audit performance rollback limitations troubleshooting final-report; do
  assert "docs/$d.md exists" test -s "docs/$d.md"
done
assert "README links the docs" grep -q 'docs/architecture.md' README.md
assert "no invented benchmark numbers in performance.md" \
  grep -q 'No numbers are published here' docs/performance.md

head_ "Summary"
printf '  %d passed, %d failed\n\n' "$PASS" "$FAIL"
((FAIL == 0))
