# Architecture and component selection

## The constraint that shapes everything

Ubuntu's desktop is GNOME Shell: a compositor (Mutter) and a JavaScript shell
running in one process. macOS's is a different compositor, a different window
server and a different toolkit. You cannot port the behaviour; you can only
reach the same result through GNOME's own mechanisms.

So Rea is built in four layers, chosen in this order of preference:

| Layer | Cost | Breaks on upgrade? | Rea uses it for |
| --- | --- | --- | --- |
| 1. Native settings (`gsettings`/dconf) | zero | almost never | window controls, keyboard map, touchpad, Nautilus, fonts, animation |
| 2. Themes and CSS | load-time only | rarely | all visual design |
| 3. Shell extensions | per-frame CPU/GPU | yes, every 6 months | dock, panel metrics, blur, rounded corners, tiling |
| 4. Separate processes (docks, gesture daemons, compositors) | constant | — | **nothing** |

Layer 4 is empty on purpose. A second dock process means a second thing to
start, theme, autohide and debug, and on Wayland it usually cannot position
itself at all. Everything Rea ships runs inside the shell that is already
running.

## Components

### Theme: WhiteSur (GPL-3.0)

Chosen over Mojave-gtk, Sweet, and WhiteSur's many forks because it is the only
macOS-like GTK theme that covers **GTK3, GTK4/libadwaita *and* GNOME Shell** from
one build. That matters more than pixel fidelity: a theme that stops at GTK3
leaves every modern GNOME app (Settings, Files, Text Editor, Calendar) looking
unrelated to the rest of the desktop.

It is built from source into `~/.themes`, not installed from a PPA. Build
dependencies (`sassc`, `libglib2.0-dev-bin`, `libxml2-utils`) come from Ubuntu's
own archive.

### Icons: WhiteSur icon theme (GPL-3.0)

Inherits from Adwaita, so an application with no matching icon falls back to a
sensible one instead of showing a missing-image box. That inheritance is the
reason to use a maintained pack rather than assembling one.

### Cursors: McMojave (GPL-3.0)

Small, complete, and the one piece most theme guides forget — a stock Adwaita
pointer over a macOS-styled desktop is immediately noticeable.

### Typography: Inter + JetBrains Mono (both SIL OFL 1.1)

Apple does not license SF Pro or SF Mono for redistribution, and extracting them
from a macOS install is a licence violation, so Rea does not. Inter is the
closest widely-available neo-grotesque: same humanist proportions, same tall
x-height, designed for UI at small sizes.

Font *choice* is only half the job. Rea also installs a fontconfig rule set that:

- turns on slight hinting with subpixel rendering and the default LCD filter,
  which is what makes Linux text stop looking over-hinted next to macOS;
- disables synthetic emboldening, the usual cause of muddy fake-bold;
- **aliases Apple font names** — `-apple-system`, `BlinkMacSystemFont`,
  `SF Pro`, `SF Mono`, `Helvetica Neue`, `Menlo`, `Monaco` — to the installed
  stand-ins, so Electron apps, web apps and imported CSS resolve to Inter
  instead of falling back to DejaVu Sans.

That last rule is why Slack, VS Code and a browser look like part of the same
desktop.

### Dock: two options, because no extension does all of it

| | Dash2Dock Animated | Dash to Dock |
| --- | --- | --- |
| Hover magnification | **yes** (parabolic zoom) | no |
| Trash + mounted volumes | yes | yes |
| Drag to rearrange | yes | yes |
| Stability / install base | smaller | very large |
| Per-frame GPU cost | higher | lower |

`full` and `balanced` use Dash2Dock Animated because magnification is the single
most recognisable Dock behaviour and nothing else maintained provides it. `lite`
uses Dash to Dock. If the animated dock has no release for your GNOME version,
Rea falls back automatically and says so.

**Ubuntu ships its own Dash to Dock fork** (`ubuntu-dock`). Rea disables it
first. Not doing that is the most common cause of two docks on screen.

### Top bar: GNOME's own, re-metricked

The status area stays GNOME's Quick Settings. It already *is* a control centre
popover with working network, Bluetooth, audio, brightness, battery and power
controls — and every control does something real, which a hand-drawn menu bar
would not. Rea changes:

- panel height, button padding and indicator padding (Just Perfection);
- clock to the right, as on macOS, with weekday and 12-hour time;
- translucency (Blur my Shell), **static blur only** on the panel: one cached
  texture rather than a blur pass every frame.

Rea does **not** ship a global application menu. See
[limitations.md](limitations.md).

### Windows: Mutter, plus two extensions

Traffic lights, double-click-to-zoom, click-to-focus, centred new windows, edge
tiling and modal dialogs attached as sheets are all native settings. Only
rounded corners for non-GTK windows and gap-aware tiling need extensions.

### Gestures: native or nothing

GNOME on **Wayland** already implements three-finger swipes for spaces and the
overview. Rea enables natural scrolling and leaves the gestures to the
compositor. On **Xorg** those gestures do not exist; Rea says so and declines to
install a gesture daemon, which would mean a third-party repository and a
process translating touch events into synthetic key presses.

## Why so much of Rea is bash

Every component above is configured through `gsettings`, dconf, files in `$HOME`
and `apt`. A bash tool can do all of that with no runtime to install, can be
read end-to-end by the person about to run it, and cannot break if a language
runtime is upgraded. The cost is discipline: strict mode, guarded writers, and a
receipt of everything touched.

## Failure model

Rea assumes it will partly fail — a theme repo moves, an extension has no
release for a new GNOME, a key gets renamed upstream. So:

- a missing setting key is **skipped and counted**, never fatal
  (`lib/gset.sh`);
- a failed component logs a warning and the install continues
  (`lib/install.sh`);
- `rea verify` then reports what actually ended up true on the system, rather
  than what the installer intended.

That is why `rea verify` exists as a separate command: the installer's exit code
tells you it ran, and only verification tells you it worked.
