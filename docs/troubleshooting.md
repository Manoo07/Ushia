# Troubleshooting

Start here:

```bash
rea verify          # what is actually true on the system right now
```

Every run is logged to `~/.local/share/rea/logs/`. The newest log has every
command, every setting change (old value → new value) and every skipped key.

---

## Nothing changed after installing

**On Wayland, this is expected.** A running Wayland session cannot load new
shell extensions. Log out and back in.

To check which session you are in: `echo $XDG_SESSION_TYPE`.

## The top bar and dock look stock, but apps are themed

The shell theme needs the **User Themes** extension:

```bash
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
gsettings get org.gnome.shell.extensions.user-theme name   # should say WhiteSur-*
```

If the extension is missing: `sudo apt install gnome-shell-extensions`, then log
out and back in.

## Two docks on screen

Ubuntu's own dock is still enabled:

```bash
gnome-extensions disable ubuntu-dock@ubuntu.com
```

`rea install` does this automatically; if it came back, something re-enabled it
(usually a GNOME upgrade). `rea verify` checks for exactly this.

## No dock at all

```bash
gnome-extensions list --enabled | grep -i dash
```

If nothing matches, the extension has no release for your GNOME version. Check:

```bash
gnome-shell --version
rea install --dry-run        # shows which extension Rea would fetch
```

Fall back to the classic dock, which supports a wider range of GNOME releases:

```bash
rea profile set lite
```

## Fonts look wrong, too thin, or did not change

```bash
fc-list | grep -ci inter                      # 0 means Inter is not installed
fc-match Inter                                # what fontconfig actually resolves
gsettings get org.gnome.desktop.interface font-name
```

Fix:

```bash
fc-cache -f -v
```

Then log out and back in — running applications cache font configuration at
start. A GTK app started before the fontconfig change will keep the old
rendering until restarted.

## Text is blurry or has colour fringes

Subpixel rendering assumes an RGB-striped LCD. On a non-standard panel (some
OLEDs, pentile displays, rotated screens) use greyscale antialiasing instead:

```bash
gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'
```

And in `~/.config/fontconfig/conf.d/99-rea-rendering.conf`, change `rgb` to
`none`.

## Some applications are still grey/Adwaita

Expected, by toolkit — see [limitations.md](limitations.md). The common cases:

- **Flatpak**: `flatpak override --user --filesystem=$HOME/.themes:ro` and
  `flatpak override --user --env=GTK_THEME=WhiteSur-Light` (`rea install` does
  this).
- **Snap**: snaps use their own theme snaps; some will stay Adwaita.
- **Qt apps**: `sudo apt install qt5ct qt6ct`, set `QT_QPA_PLATFORMTHEME=qt5ct`,
  then pick a matching style in `qt5ct`.
- **Electron / Chrome / VS Code**: they draw their own window controls and
  header bars. Inter still applies via font aliasing.

## Window buttons are on the right

```bash
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:appmenu'
```

If they stay on the right in one specific app, that app draws its own controls.

## Super+Space does not search

Something else holds the chord. Check for a conflict:

```bash
gsettings get org.gnome.desktop.wm.keybindings switch-input-source   # should be Super+Alt+Space
gsettings get org.gnome.shell.keybindings toggle-overview            # should include Super+Space
```

## A shortcut broke something I need

Everything is one command away from stock:

```bash
gsettings reset-recursively org.gnome.desktop.wm.keybindings
gsettings reset-recursively org.gnome.shell.keybindings
```

Or restore just the keyboard subtree from a snapshot — see
[rollback.md](rollback.md).

## Ctrl+Left / Ctrl+Right stopped working in my terminal

You enabled `REA_SPACES_CTRL_ARROWS=1`. Undo:

```bash
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Control><Alt>Left']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Control><Alt>Right']"
```

## The desktop feels slower

```bash
rea bench after && rea bench --compare
rea profile set lite
```

See [performance.md](performance.md) for what costs what.

## Gestures do not work

Three-finger workspace gestures exist on Wayland only. Log in to "Ubuntu on
Wayland" from the gear menu at the login screen. Rea will not install a gesture
daemon on Xorg — it needs a third-party repository.

## The theme build failed

```bash
sudo apt install sassc libglib2.0-dev-bin libxml2-utils
df -h ~                     # the build needs a few hundred MB
rea install --force
```

If upstream has changed its installer flags, Rea retries with no flags
automatically — look for "Upstream installer flags were rejected" in the log.

## `rea verify` reports many skipped keys

That is the compatibility mechanism working: a settings key that does not exist
on your GNOME version is skipped rather than fatal. Check which ones:

```bash
grep 'GSET?' ~/.local/share/rea/logs/rea-*.log | tail -30
```

Skipped *extension* keys usually mean the extension renamed a setting in a newer
release. The visible effect is that one dock or panel detail keeps its default.

## The shell crashed and I cannot log in

See [rollback.md](rollback.md) section 4 — log in to an Xorg session, or disable
all extensions from a TTY.

## Filing a bug

```bash
rea audit --json > audit.json
rea verify --json > verify.json
```

Attach both plus the newest file from `~/.local/share/rea/logs/`. They contain
hardware and settings information, no document contents and no credentials.
