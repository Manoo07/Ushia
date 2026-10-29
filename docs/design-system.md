# Design system

One set of values, used by the GTK CSS (`config/gtk/`), the profile files
(`config/profiles/`) and the shell extension settings. Changing a token here
means changing it in one place and re-running `rea reapply`.

## Colour

| Token | Light | Role |
| --- | --- | --- |
| `rea_accent` | `#0a7cff` | selection, focus, suggested actions, sliders |
| `rea_accent_hover` | `#2f8fff` | hover on accented controls |
| `rea_accent_active` | `#0062d6` | pressed |
| `rea_surface` | `#f6f6f6` | window background |
| `rea_surface_raise` | `#ffffff` | cards, popovers, list rows |
| `rea_border` | `black @ 12%` | hairlines |
| `rea_text` | `#1d1d1f` | primary text |
| `rea_text_dim` | `text @ 55%` | secondary text |

Traffic lights: close `#ff5f57`, minimise `#febc2e`, zoom `#28c840`, inactive
`#cfcfcf`.

Dark appearance comes from the theme's own dark variant rather than a second
token set, so GNOME's `color-scheme` switch stays the single source of truth and
apps that follow it (all libadwaita apps) change with it.

## Radius

| Surface | Radius |
| --- | --- |
| Window | 10px |
| Sheet / alert | 12px |
| Popover, boxed list | 10px |
| Menu | 8px |
| Button, entry | 6px |
| Menu item, list row | 5–6px |
| Thumbnail | 4px |
| Pill, switch, slider, scrollbar | 999px |

## Spacing

4px base grid: **4 · 8 · 12 · 16 · 20**. Dock gap 8px. Tiling window gap 8px.
Sidebar row inset 6px. Sidebar width 190px.

## Control metrics

| Control | Size |
| --- | --- |
| Button / entry height | 28px (24px min + padding) |
| Menu item height | 24px |
| List row height | 40px (boxed lists) |
| Header bar | 46–52px |
| Top panel | 28px (26 in `lite`) |
| Dock icon | 48 / 44 / 40px (full / balanced / lite) |
| Scrollbar slider | 7px, 9px on hover |

## Typography

| Role | Font | Size |
| --- | --- | --- |
| Interface | Inter (Inter Display in `full`) | 11pt |
| Document | Inter | 11pt |
| Monospace | JetBrains Mono | 11pt |
| Titlebar | Inter Semi Bold | 11pt |
| Caption | Inter | 9pt |

Rendering: slight hinting, subpixel RGB, `lcddefault` filter, no synthetic
emboldening, no embedded bitmaps.

## Motion

| Token | Duration | Used for |
| --- | --- | --- |
| instant | 80ms | pressed states |
| short | 150ms | hover, dock show/hide, button fills |
| standard | 220ms | popovers, scrollbar reveal |
| long | 320ms | window and workspace transitions |

Easing: `cubic-bezier(.25,.1,.25,1)` standard, `cubic-bezier(0,0,.2,1)`
decelerating for anything entering the screen.

Profiles map onto Just Perfection's animation scale: `full` = 2 (default-ish),
`balanced` = 3 (fast), `lite` = 4 (fastest). Animation is never fully disabled
by default, because the overview and workspace switch become disorienting
without it — but `enable-animations false` remains one `gsettings` call away.

## Rules that keep it coherent

1. **One accent.** Selection, focus ring, slider fill, suggested button and
   checked state all use `rea_accent`. No per-app accents.
2. **Radius follows size.** Bigger surface, bigger radius. Never a 10px radius
   on a 24px control.
3. **Hairlines, not borders.** 1px at 12% black. Separators use the same colour.
4. **Translucency only on chrome.** Panel, dock, popovers, lock screen. Never
   application windows — it costs a blur pass per frame and breaks apps that
   draw their own background.
5. **Motion is feedback, not decoration.** If an animation delays input, it is
   wrong, however good it looks.
