# Implementation plan

Ordered by value per unit of risk. Each phase is independently useful and
independently reversible, so you can stop after any of them.

## Phase 0 — Know the machine (no changes)

```bash
rea audit            # OS, GNOME version, session, GPU, displays, conflicts
rea doctor           # readiness, with reasons
rea bench before     # baseline numbers to compare against later
rea snapshot         # restore point
```

Stop here if `doctor` reports blockers. Everything after this assumes GNOME
Shell 42+ on Ubuntu or a close relative.

## Phase 1 — Appearance (reversible, no new processes)

Theme, icons, cursors, typography, GTK CSS overrides, wallpaper.

This is where most of the perceived change lives, and it costs nothing at
runtime: themes are parsed once at application start. If you only ever do one
phase, do this one.

Verify: `rea verify` — the Appearance and Typography sections should be green.
Revert: `rea rollback`.

## Phase 2 — Shell layout (extensions; costs frame time)

Dock, panel metrics, translucency, rounded corners, tiling.

This phase installs GNOME Shell extensions, which means:

- on **Wayland** you must log out and back in before anything appears;
- an extension can crash the shell's UI (Wayland) or the session (Xorg) if it is
  incompatible — which is why Phase 0's snapshot is not optional;
- each extension costs memory and some per-frame work. Phase 5 measures it.

Verify: `rea verify` — Dock and Top bar sections.
Revert: `rea profile set lite` (keeps the look, drops the extensions), or
`rea rollback`.

## Phase 3 — Behaviour (native settings only)

Window controls on the left, keyboard map, touchpad, Nautilus, file chooser.

Cheap and robust, but the most likely to surprise you, because muscle memory is
involved. Two deliberate choices:

- `Super+Space` becomes search (Spotlight). GNOME ships that chord for
  input-source switching, so Rea **moves** it to `Super+Alt+Space` rather than
  deleting it.
- `Ctrl+Left/Right` stay with the terminal. Authentic macOS space-switching is
  opt-in (`REA_SPACES_CTRL_ARROWS=1`) because those keys are word-motion keys in
  every shell and editor.

Verify: `rea shortcuts`, then try them.
Revert: `rea rollback`.

## Phase 4 — Integration

Flatpak theme access, Quick Look (`gnome-sushi`), terminal in the file-manager
context menu, sidebar bookmarks.

Each is a small thing that otherwise reads as "not quite a real desktop": a
Flatpak app in stock Adwaita, no Space-bar preview, no "open terminal here".

## Phase 5 — Measure, then decide

```bash
rea bench after
rea bench --compare
```

If shell memory or idle CPU moved more than you are willing to pay, step down a
profile — `rea profile set balanced` or `lite` — and measure again. The point of
the profiles is that this is a one-command decision, not a reinstall.

## Phase 6 — Document and hand over

`rea verify --json > state.json` captures the finished configuration for a bug
report or a second machine. `docs/final-report.md` is the template for what was
implemented, what was approximated, and what is not possible.

## What is deliberately not in the plan

- Replacing GDM's theme (needs root, writes outside `$HOME`, and breaks on
  every GDM update). Rea leaves the login screen alone.
- Replacing the shell, compositor or display manager.
- A global menu bar, a Launchpad clone, or Stage Manager. See
  [limitations.md](limitations.md).
