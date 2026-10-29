# Limitations

Three categories, kept strictly apart: **done**, **approximated**, and **not
possible**. Anything in the second or third list is there because of how GNOME,
Wayland or application toolkits work — not because it was skipped.

## Not possible (and Rea does not pretend otherwise)

### Global application menu

macOS puts every application's menus in the top bar. Rea does not, and will not
ship a fake one.

The old GNOME global-menu extensions (Fildem, gnome-global-menu) relied on
Unity's `appmenu` D-Bus protocol plus shell internals that GNOME 45 removed when
it moved extensions to ES modules. Nothing maintained replaces them, and even at
their best they worked only for GTK apps that exported a menu model — never for
Electron, Qt, Java or anything with a custom header bar. A menu bar that is
empty for half your applications is worse than no menu bar.

**What you get instead:** the application name and icon at the left of the panel
(Just Perfection's app menu), with each app's own menu in its header bar.

### Cmd+C / Cmd+V everywhere

Copy and paste are handled per-toolkit, not by the window manager, so there is
no single setting to move them to Super. Rea maps window and shell actions to
Super and leaves text editing on Ctrl. Changing it would require per-application
remapping that breaks the moment an app updates.

### Stage Manager, Mission Control's exact layout, Launchpad's exact grid

GNOME's overview and app grid are the real analogues and they are bound to the
familiar keys (`Ctrl+Up`, `Super+A`). They do not animate or arrange windows the
way macOS does, and no extension reproduces it faithfully.

### Continuity, AirDrop, Handoff, iCloud, Apple services

Out of scope. These are services, not appearance.

### The login screen

GDM theming needs root, writes outside `$HOME`, and breaks on GDM updates. Rea
leaves it alone deliberately. Your desktop is macOS-like; your login screen is
Ubuntu's.

## Approximated (close, not identical)

| Feature | What Rea does | Where it differs |
| --- | --- | --- |
| **System font** | Inter | Not SF Pro. Very close in proportion and x-height; different at display sizes and in the italics |
| **Traffic lights** | WhiteSur draws red/yellow/green on the left | Apps with custom header bars (Chrome, VS Code, Electron, Steam) draw their own controls and ignore the theme |
| **Dock magnification** | Dash2Dock Animated's parabolic zoom | Easing and the "genie" minimise are not macOS's |
| **Translucency** | Static blur on panel and dock | macOS blurs live content behind every surface; dynamic blur everywhere is too expensive to be the default |
| **Quick Look** | `gnome-sushi` (select, press Space) | Fewer file types, no Markup, no multi-file preview |
| **Spotlight** | GNOME overview search on `Super+Space` | Searches apps, files and settings, but no calculator-grade inline answers or web results |
| **Spaces gestures** | Native three-finger swipes | Wayland only; Xorg has none |
| **Sheets** | Modal dialogs attached to the parent window | Appear attached, but do not slide down from the title bar |
| **Finder** | Nautilus with list/tree view, breadcrumbs, 190px sidebar | No column view, no tags, no Finder-style Get Info window |
| **Window snapping** | Tiling Assistant with 8px gaps | Not macOS 15's window tiling animation or layout set |

## Implemented natively (no approximation)

Window controls on the left, click-to-focus, double-click-to-zoom, centred new
windows, edge tiling, dynamic spaces, natural scrolling, tap-to-click,
two-finger secondary click, 12-hour clock with weekday on the right, battery
percentage, a working control-centre popover (GNOME Quick Settings), screenshot
and screen-recording chords on `Shift+Super+3/4/5`, Super-based close/minimise/
app-switch/full-screen/lock, consistent GTK3 + GTK4 + libadwaita theming, Apple
font-name aliasing for Electron and web apps, Flatpak theme access.

## Toolkit coverage

| Toolkit | Coverage | Notes |
| --- | --- | --- |
| GTK3 | full | theme + Rea's CSS |
| GTK4 / libadwaita | full | theme + accent override |
| GNOME Shell | full | shell theme |
| Flatpak | full | needs the overrides Rea sets |
| Qt / KDE apps | partial | install `qt5ct`/`qt6ct` and pick a matching style; Rea does not configure Qt |
| Electron | fonts and font aliasing only | each app draws its own chrome |
| Snap | partial | snaps have their own theme snaps; some will stay Adwaita |
| Java / Swing | none | ignores system theming |
| Terminal apps | fonts only | colours are per-terminal configuration |

## Honest summary

Rea gets you a desktop that reads unmistakably as macOS-like, with real
functionality behind every control it adds, at a measured cost you can check and
undo in one command. It does not get you macOS. The gaps above are
architectural, and anyone claiming otherwise on Linux is either shipping
non-functional decoration or has not looked closely.
