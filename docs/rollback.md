# Recovery

Rea's first action in any install is a snapshot. This page is what the snapshot
is for, in increasing order of severity.

## 1. Normal undo

```bash
rea snapshots            # list restore points
rea rollback             # restore the most recent
rea rollback 20261029-143000-pre-install   # or a specific one
```

Then log out and back in (Wayland), or press `Alt+F2`, type `r`, press Enter
(Xorg).

## 2. Full removal

```bash
rea uninstall
```

Restores the pre-install snapshot, re-enables extensions Rea disabled (including
`ubuntu-dock`), removes extensions Rea installed, resets Flatpak overrides, and
*asks* before deleting downloaded themes/fonts or removing apt packages. Nothing
Rea did not install is ever removed.

## 3. The desktop looks wrong but still works

```bash
rea verify               # which criterion actually failed
rea profile set lite     # drop every extension, keep the look
```

## 4. The shell is broken after logging in

This is what the snapshot and the extension model protect you from: Rea's
extensions are per-user, so a clean fallback always exists.

**Option A — log in to a plain session.** At the login screen, click your name,
then the gear icon at the bottom right, and pick **Ubuntu on Xorg** (or
**GNOME Classic**). Then:

```bash
rea rollback
```

**Option B — disable everything from a TTY.** Press `Ctrl+Alt+F3`, log in, then:

```bash
gnome-extensions list --enabled | xargs -r -n1 gnome-extensions disable
gsettings reset org.gnome.desktop.interface gtk-theme
gsettings reset org.gnome.shell.extensions.user-theme name
```

Press `Ctrl+Alt+F2` (or `F1`) to return to the graphical session and log in
again. Then `rea rollback` for the rest.

**Option C — settings only, no Rea.** The snapshot is plain text; you do not
need Rea to use it:

```bash
cd ~/.local/share/rea/snapshots/<id>/dconf
dconf load /org/gnome/desktop/interface/ < org.gnome.desktop.interface.ini
dconf load /org/gnome/shell/ < org.gnome.shell.ini
# or, the whole user configuration as it was:
dconf load / < FULL.ini
```

## 5. Nothing above worked

A GNOME user configuration can always be reset wholesale. This reverts *all*
your GNOME settings, not only Rea's:

```bash
dconf reset -f /org/gnome/
rm -f ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css ~/.gtkrc-2.0
rm -f ~/.config/fontconfig/conf.d/99-rea-rendering.conf
rm -rf ~/.local/share/gnome-shell/extensions
```

Log out and back in. You now have a stock Ubuntu desktop. Your files,
applications, packages and system configuration were never touched — Rea does
not write outside `$HOME` except for apt packages, and it never modifies system
files, systemd units, GDM or the kernel.

## What a snapshot contains

`~/.local/share/rea/snapshots/<timestamp>-<label>/`

| Path | Contents |
| --- | --- |
| `manifest.conf` | id, label, date, Rea version, GNOME version, session type |
| `dconf/FULL.ini` | the entire user dconf database |
| `dconf/org.gnome.*.ini` | one file per subtree Rea is allowed to write |
| `files/` | verbatim copies of `gtk.css`, `settings.ini`, `fonts.conf`, `.gtkrc-2.0`, `bookmarks` |
| `themes.list`, `icons.list` | what was installed before |
| `extensions.list`, `extensions.enabled` | which extensions existed and which were on |
| `dpkg.list` | the full package list, for reference |

Restore works subtree by subtree: Rea resets only the paths it owns and loads
each one back. Settings outside that list are never touched, even by a restore.

## Snapshots are not backups

They cover desktop configuration, not your data. They are also local — if the
disk fails, they fail with it. Keep real backups.
