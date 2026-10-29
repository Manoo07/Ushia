<h1>Rea</h1>

**A macOS-style desktop experience for Ubuntu — engineered as a reversible
toolkit, not a theme dump.**

Ubuntu stays Ubuntu: same kernel, same drivers, same apt, same GNOME Shell. Rea
changes only the user-level desktop layer, records everything it touches, and
can put it all back with one command.

```bash
curl -fsSL https://raw.githubusercontent.com/morluto/rea/main/bootstrap.sh | bash
```

Prefer to read before you run? That is the better habit:

```bash
git clone https://github.com/morluto/rea.git && cd rea
./rea audit              # what am I running, and what will conflict?
./rea install --dry-run   # every command it would run, nothing changed
./rea install             # the real thing — it asks before each decision
```

---

## In one minute

```bash
rea doctor        # is this machine ready, and if not, why
rea snapshot      # a restore point
rea install       # pick a profile, answer two questions, wait
# log out and back in
rea verify        # 29 checks against the live system
rea rollback      # changed your mind
```

Nothing is installed outside `$HOME` except apt packages you are shown first.
No third-party repositories. No background process — Rea is a tool you run, not
a service that runs.

## What you get

| | |
| --- | --- |
| **Dock** | Centred, magnifying on hover, running indicators, Trash, mounted volumes, autohide with pressure reveal, drag to rearrange |
| **Top bar** | Panel metrics and typography retuned, clock right with weekday, battery percentage, static blur — and GNOME's own Quick Settings, so every control does something real |
| **Windows** | Traffic lights on the left, double-click to zoom, centred new windows, rounded corners, sheets, gap-aware tiling |
| **Keyboard** | Super behaves as Command: `Super+Q` close, `Super+Space` search, `Super+A` all apps, `Ctrl+Up` overview, `Shift+Super+3/4/5` screenshots |
| **Typography** | Inter + JetBrains Mono, tuned rendering, and Apple font-name aliasing so Electron and web apps match too |
| **Files** | List view with disclosure tree, breadcrumbs, 190px sidebar, Space-bar Quick Look |
| **Theme** | WhiteSur across GTK3, GTK4/libadwaita and the shell, one accent colour, light and dark |
| **Input** | Natural scrolling, tap to click, two-finger secondary click, native Wayland gestures |

Full list, including what is only approximated:
[docs/limitations.md](docs/limitations.md).

## Three profiles

| | `full` | `balanced` (default) | `lite` |
| --- | --- | --- | --- |
| Dock magnification | yes | yes | no |
| Blur | panel + overview | panel only, static | none |
| Rounded corners | yes | yes | no |
| Dock icons | 48px | 44px | 40px |
| Best for | a discrete or recent GPU | **most machines** | older hardware, VMs, battery |

```bash
rea profile set lite     # switch any time, no reinstall
rea appearance dark      # light or dark
```

## Design principles

1. **Reversible before clever.** Nothing is applied until a snapshot exists.
   `rea rollback` restores each dconf subtree and config file from it;
   `rea uninstall` goes further and removes only what the receipt says Rea
   added.
2. **No root for cosmetics.** Themes, icons, fonts and extensions install into
   `$HOME`. `sudo` is used only for apt packages, always announced, always
   skippable with `--no-sudo`.
3. **Native first.** Window controls, keyboard map, touchpad, file manager and
   animation are plain `gsettings` — zero runtime cost, and they survive GNOME
   upgrades. Extensions are used only where nothing native exists.
4. **Degrade, never abort.** A settings key that does not exist on your GNOME
   version is skipped and counted, so one script covers GNOME 42 → 48. A failed
   component warns and the install continues.
5. **Measure, don't claim.** `rea bench` samples shell memory, idle CPU and boot
   time before and after. This repo publishes **no** benchmark numbers, because
   it has not run on the hardware that matters — yours.
6. **No fake controls.** Rea ships no global menu bar, because the GNOME 45+ API
   removed what one would need and a menu bar that is empty for half your apps
   is worse than none.

## Requirements

- Ubuntu 22.04+ (or a Debian-family relative), GNOME Shell **42 or newer**
- Wayland or Xorg — Wayland gets multi-finger gestures, Xorg does not
- ~500 MB free in `$HOME`, `curl`, and `sudo` for a short list of apt packages

`rea doctor` checks all of it and tells you which item failed.

## Commands

```
rea audit [--json]            OS, GPU, session, current appearance, conflicts
rea doctor                    readiness check with reasons
rea install [full|balanced|lite]
rea reapply                   re-apply the profile without downloading
rea verify [--json]           every acceptance check against the live system
rea bench [label|--compare]   measure the cost
rea profile [list|show|set N]
rea appearance <light|dark>
rea shortcuts                 the keyboard map
rea snapshot [label] · rea snapshots · rea rollback [id]
rea uninstall                 restore the pre-install state
```

Global flags: `--dry-run`, `--yes`, `--json`, `--force`, `--no-sudo`,
`--no-color`.

## Documentation

| | |
| --- | --- |
| [architecture.md](docs/architecture.md) | every component, and why it beat the alternatives |
| [implementation-plan.md](docs/implementation-plan.md) | six phases, each independently reversible |
| [design-system.md](docs/design-system.md) | colour, radius, spacing, type, motion tokens |
| [audit.md](docs/audit.md) | what the audit collects and how to read it |
| [performance.md](docs/performance.md) | measurement method, what costs what, what to turn off first |
| [rollback.md](docs/rollback.md) | five escalating recovery levels, including a broken shell |
| [troubleshooting.md](docs/troubleshooting.md) | 18 named failures and their fixes |
| [limitations.md](docs/limitations.md) | done / approximated / not possible, kept strictly apart |
| [final-report.md](docs/final-report.md) | what was built, what was verified, what remains |

## Status and verification

Everything in this repo is syntax-checked, shellcheck-clean at warning level,
and exercised by `tests/run.sh` (101 checks, run in CI). The installer runs end
to end in `--dry-run` on a machine with none of the prerequisites, degrading
loudly rather than crashing.

**It has not been run on real Ubuntu GNOME hardware.** Rea was authored on
macOS. Three real bugs were found and fixed in dry-run testing, but no step has
yet written a setting to a live GNOME session — so treat the first install as a
first install: `rea audit`, `rea snapshot`, `rea install --dry-run`, read it,
then `rea install`. Details in
[final-report.md](docs/final-report.md#verification-status--read-this-before-trusting-any-of-it).

## Layout

```
rea                 CLI entrypoint: argument parsing, command dispatch
bootstrap.sh        clone + link + doctor, for a one-line install
lib/
  core.sh           logging, prompts, dry-run-aware run(), state paths
  detect.sh         read-only system audit
  backup.sh         snapshots, restore, install receipt
  gset.sh           version-guarded gsettings/dconf writers
  pkg.sh            apt, limited to the receipt
  fetch.sh          downloads, each into its own empty directory
  ext.sh            GNOME Shell extensions
  theme.sh          GTK/shell theme, icons, cursors, CSS, Flatpak access
  fonts.sh          fonts, rendering, Apple-name aliasing
  dock.sh           both dock flavours and conflict resolution
  panel.sh          top bar metrics and translucency
  wm.sh             window behaviour and the keyboard map
  files.sh          Nautilus and the file chooser
  input.sh          touchpad, mouse, gestures
  perf.sh           benchmarking
  verify.sh         acceptance checks
  install.sh        orchestration, re-apply, uninstall
config/
  manifest.conf     every external source, pinned
  profiles/         full, balanced, lite
  gtk/              design tokens and CSS overrides
  fonts/            fontconfig rendering and aliases
  assets/           original gradient wallpapers
docs/               the nine documents above
tests/run.sh        syntax, shellcheck, assets, profiles, functions, CLI, docs
```

## Licence

MIT for Rea's own code — see [LICENSE](LICENSE). Themes, icons and fonts are
downloaded from upstream at install time and keep their own licences (GPL-3.0
for WhiteSur and McMojave, SIL OFL 1.1 for Inter and JetBrains Mono). **No Apple
assets are included, copied or redistributed**, and Rea will not extract fonts
or artwork from a macOS installation.
