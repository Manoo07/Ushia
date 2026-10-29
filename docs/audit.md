# The system audit

`rea audit` is read-only. It writes nothing, needs no password, and is the first
thing to run — on your own machine before installing, and in any bug report.

```bash
rea audit               # human readable
rea audit --json        # machine readable, for diffing or filing issues
```

## What it collects and why each item matters

| Field | Why Rea needs it |
| --- | --- |
| OS id / version / codename | which apt packages exist; whether this is Ubuntu or a relative |
| Kernel, architecture | ARM machines have different driver and font paths |
| Desktop (`XDG_CURRENT_DESKTOP`) | Rea only targets GNOME; KDE/XFCE would be mis-themed |
| GNOME Shell version | decides which extension releases exist, and which settings keys do |
| Session type (Wayland / Xorg) | whether gestures work, and whether a logout is needed after installing extensions |
| CPU, threads, RAM | whether `full` is realistic |
| GPU model, kernel driver, OpenGL renderer | blur and magnification are GPU work; `llvmpipe` means software rendering, so `lite` |
| Battery present | blur and animation cost battery; informs the profile suggestion |
| Touchpad present | whether to write touchpad settings at all |
| Connected outputs and modes | multi-monitor dock placement and scaling |
| Text scaling, Mutter experimental features | existing fractional-scaling setup Rea must not disturb |
| Current theme, icons, cursor, fonts, colour scheme, button layout | exactly what rollback has to restore |
| Enabled extensions | what is already running, and what will conflict |
| apt / snap / flatpak present | which integration steps apply |
| Free space in `$HOME` | the theme build needs a few hundred MB |
| Conflicts | `ubuntu-dock`, `dash-to-panel`, Plank, Cairo Dock, picom |

## Reading the result

The **Readiness** section at the end is the summary. Blockers are hard stops:

| Blocker | Meaning |
| --- | --- |
| Not an Ubuntu/Debian-family system | apt package names and paths will be wrong |
| Desktop is not GNOME | Rea's components do not exist for your shell |
| GNOME Shell older than 42 | the extensions have no compatible release |
| Less than 500 MB free in `$HOME` | the theme build will fail part-way |
| `curl` missing | nothing can be downloaded |

`--force` overrides them. It is there for people porting Rea to a related
distribution, not for ordinary installs.

## Conflicts are warnings, not blockers

Rea resolves what it can (it disables `ubuntu-dock` and `dash-to-panel`) and
warns about what it cannot (a running Plank or picom process — quit those
yourself). Nothing is removed from your system to resolve a conflict; extensions
are only *disabled*, and `rea uninstall` re-enables them.

## Example

```
System
  OS                     Ubuntu 24.04.1 LTS
  Kernel / arch          6.8.0-45-generic (x86_64)
  Desktop                ubuntu:GNOME
  GNOME Shell            46.0
  Session                wayland

Hardware
  GPU                    Intel Alder Lake-UP3 GT2 [Iris Xe Graphics]
  Kernel GPU drivers     i915
  OpenGL                 4.6 (Compatibility Profile) Mesa 24.0.9
  Battery / touchpad     yes / yes
  Displays               eDP-1@1920x1200, DP-3@2560x1440

Potential conflicts
  Detected               extension:ubuntu-dock@ubuntu.com

Readiness
  ✓ No blockers found. 'rea install' can proceed.
```

A machine like that would take the `balanced` profile: Iris Xe handles panel
blur comfortably, but it is a laptop on battery, so full-screen overview blur is
not worth the watts.
