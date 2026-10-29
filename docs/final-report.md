# Final report

## What was built

Rea is a reversible toolkit, not a theme pack. It is ~2,900 lines of bash across 17 modules
and a CLI plus a design system, three performance profiles, pinned upstream
sources, and nine documents. One command audits a machine, one installs, one
verifies the result against the acceptance criteria, one measures the cost, one
undoes everything.

### Delivered against the brief

| Requested deliverable | Where it is |
| --- | --- |
| 1. Initial system audit | `rea audit` / `rea audit --json`, documented in [audit.md](audit.md) |
| 2. Desktop architecture and component selection | [architecture.md](architecture.md) |
| 3. Prioritised implementation plan | [implementation-plan.md](implementation-plan.md) |
| 4. Executable installation and configuration scripts | `rea`, `bootstrap.sh`, `lib/*.sh` |
| 5. Configuration files and theme assets | `config/` — GTK CSS tokens, fontconfig, profiles, wallpapers |
| 6. Repeatable verification | `rea verify` — 29 checks, `--json` for CI |
| 7. Performance measurement before and after | `rea bench` / `rea bench --compare`, method in [performance.md](performance.md) |
| 8. Troubleshooting instructions | [troubleshooting.md](troubleshooting.md) — 18 named failures |
| 9. Rollback script / recovery procedure | `rea rollback`, `rea uninstall`, [rollback.md](rollback.md) — 5 escalating levels |
| 10. Final report | this document |

### Features implemented

**Visual** — WhiteSur across GTK3, GTK4/libadwaita and GNOME Shell; WhiteSur
icons with Adwaita fallback; McMojave cursors; Rea's own CSS token layer for
radii, scrollbars, focus rings, menus, sidebars and control metrics; original
gradient wallpapers for light and dark; one accent colour across every toolkit;
light/dark switching in one command.

**Typography** — Inter and JetBrains Mono installed per-user; slight hinting
with subpixel rendering and no synthetic emboldening; **Apple font-name aliasing**
(`-apple-system`, `SF Pro`, `SF Mono`, `Menlo`, `Helvetica Neue`, …) so Electron
and web apps resolve to the installed stand-ins; interface, document, monospace
and titlebar fonts set coherently.

**Dock** — Dash2Dock Animated with real hover magnification, Trash, mounted
volumes, running indicators, drag-to-rearrange, autohide with pressure reveal,
primary-monitor placement that survives replugging; automatic fallback to Dash
to Dock; Ubuntu's conflicting `ubuntu-dock` disabled first.

**Top bar** — GNOME Quick Settings kept, so every control does something real;
panel height, padding and indicator metrics retuned; clock moved right with
weekday and 12-hour time; battery percentage; static panel blur.

**Windows** — traffic lights on the left; double-click to zoom; click to focus;
centred new windows; edge tiling; modal dialogs as attached sheets; rounded
corners for non-GTK windows; gap-aware tiling.

**Keyboard** — Super as Command: close, minimise, app-switch, cycle windows,
full screen, show desktop, home folder, lock, screenshots on
`Shift+Super+3/4/5`, search on `Super+Space`, Launchpad on `Super+A`, Mission
Control on `Ctrl+Up`. Nothing is removed without an alternative being bound.

**Files** — list view with disclosure tree, breadcrumb path bar, 190px sidebar
with the standard folders added additively, thumbnails local-only, `gnome-sushi`
for Space-bar Quick Look, terminal in the context menu. Linux semantics intact:
hidden files, symlinks, permissions, "Delete permanently" all untouched.

**Input** — natural scrolling, tap to click, tap-and-drag, two-finger secondary
click, disable-while-typing, faster tracking; native Wayland three-finger
gestures; external mouse scroll direction deliberately left alone.

**Engineering** — snapshot before any change; receipt of every package,
extension, directory and file touched, so uninstall removes only what Rea added;
version-guarded settings writers that skip unsupported keys and count them;
`--dry-run` for every command; full logging; `$HOME`-only writes apart from
apt packages shown first; no third-party repositories; no resident process.

## Verification status — read this before trusting any of it

| Checked | How | Result |
| --- | --- | --- |
| Shell syntax, all 18 files | `bash -n`, shellcheck in CI | clean |
| CLI surface | every command run | works |
| Audit, doctor | run on a non-GNOME machine | correctly refuses, with reasons |
| Snapshot / rollback round trip | run | works; degrades correctly without dconf |
| Installer, end to end | `--dry-run` on a machine with no prerequisites | completes all 12 steps, degrades loudly, no crash |
| Verify | run | 29 checks execute; valid JSON |
| Uninstall | run | declines safely by default |
| XML/SVG assets | parsed | valid |
| **Install on real Ubuntu GNOME hardware** | — | **not done** |

Rea was authored on macOS. The logic is syntax-checked and exercised in dry-run,
and three real bugs found that way were fixed (a leaked log line corrupting a
captured snapshot id, a bash `local` expansion order error, and a contradictory
package-manager message). But no step has written a setting to a live GNOME
session.

**Practical consequence:** treat the first install as a first install. Run
`rea audit`, then `rea snapshot`, then `rea install --dry-run`, and read it
before running `rea install`. The highest-risk items are extension settings
keys, which upstream renames between releases — those degrade to "skipped" and
are reported, rather than failing.

## Known limitations

Summarised here, in full in [limitations.md](limitations.md).

**Not possible:** global application menu (the GNOME 45+ API removed what it
needed; Rea ships no fake menu bar), Cmd+C/V text editing, Stage Manager,
Launchpad's exact grid, Apple services, and the login screen (left alone on
purpose).

**Approximated:** system font (Inter, not SF Pro), traffic lights in apps with
custom header bars, dock easing and the genie minimise, translucency (static not
live), Quick Look's file-type coverage, Spotlight's inline answers, sheets,
column view in Files, and tiling layouts.

**Toolkit coverage:** full for GTK3, GTK4/libadwaita, the shell and Flatpak;
partial for Qt and Snap; fonts only for Electron; none for Java/Swing.

## Remaining differences from macOS

The honest list, in order of how much they will bother you:

1. No global menu bar — each application keeps its own header-bar menu.
2. Electron and Chrome draw their own window controls, so a handful of windows
   have non-macOS chrome.
3. Window and overview animation easing is Mutter's, not Apple's. Close in feel,
   not identical.
4. The overview is not Mission Control: same purpose, different layout.
5. Translucency is static, so it does not react to content moving behind it.
6. Inter is not SF Pro. Noticeable mainly in large headings.
7. On Xorg there are no multi-finger gestures at all.

## What I would do next

1. **Run it on hardware.** Ubuntu 24.04 and 25.04, Wayland and Xorg, Intel and
   AMD, HiDPI and 1080p — and publish real `rea bench` numbers in place of the
   template in [performance.md](performance.md).
2. **Pin extension versions** the way themes are pinned. Right now
   extensions.gnome.org serves whatever matches the running shell; a manifest of
   known-good version tags per GNOME release would make installs reproducible.
3. **Self-test the settings keys.** Generate the expected key list per GNOME
   version in CI, so a renamed upstream key is a failing test rather than a
   skipped line in a log.
4. **A Qt module**, so KDE-toolkit apps stop being the obvious odd ones out.
5. **A first-run panel**: accent colour, dock size, appearance and wallpaper in
   one place, for people who will never open a terminal again after installing.
