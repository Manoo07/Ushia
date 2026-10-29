# Contributing

The useful contribution right now is **running Rea on real hardware** and
reporting what happened. See
[docs/final-report.md](docs/final-report.md#verification-status--read-this-before-trusting-any-of-it).

## Reporting a result, good or bad

```bash
rea audit --json > audit.json
rea verify --json > verify.json
rea bench --compare
```

Attach both files, the newest log from `~/.local/share/rea/logs/`, and say which
profile you used. Those contain hardware and settings data — no file contents,
no credentials.

Especially wanted: GNOME 47 and 48, Xorg sessions, AMD and NVIDIA GPUs, HiDPI
and fractional scaling, and any extension settings key that was skipped
(`grep 'GSET?' ~/.local/share/rea/logs/rea-*.log`).

## Before opening a pull request

```bash
tests/run.sh          # must pass; add a case for what you changed
shellcheck -x -S warning -e SC1090,SC1091,SC2034 rea lib/*.sh bootstrap.sh
./rea install balanced --dry-run -y --force    # must complete
```

## House rules

These are what keep Rea safe to run on someone else's machine.

1. **Nothing outside `$HOME`** except apt packages, and those are listed to the
   user before installation.
2. **No third-party repositories, no `add-apt-repository`, no piping a download
   into a shell.** CI fails on all three.
3. **Every change is recorded.** New files, directories, packages or extensions
   go through `rea_record`, or `rea uninstall` cannot remove them.
4. **Every settings write goes through `rea_gset` / `rea_gset_ext`,** never a
   bare `gsettings set`. The guarded writers are what make one script work
   across GNOME 42–48.
5. **Respect `--dry-run`.** If your code can change state, it must check
   `REA_DRY_RUN` or go through `run` / `atomic_write`.
6. **No committed binary assets.** Fonts, icons and artwork are downloaded from
   upstream at install time or generated as SVG/CSS here. CI enforces this.
7. **Never ship a non-functional control.** If GNOME cannot do it, document it
   in [docs/limitations.md](docs/limitations.md) instead of faking it.
8. **No new background process, timer or poll.** Rea is not resident.

## Code style

Match the surrounding code: `set -uo pipefail`, two-space indent, `local` for
every function variable, lower_snake_case functions prefixed `rea_`, and a
comment block at the top of each module saying what it owns and why.

Comments explain *why* a choice was made — which upstream bug, which GNOME
version, which conflict. The code already says what it does.

## Adding a component

1. Say in `docs/architecture.md` what it is for and what it beat.
2. Pin its source in `config/manifest.conf`.
3. Add its settings behind profile variables, so `lite` can switch it off.
4. Add a check to `lib/verify.sh`.
5. Note its cost in `docs/performance.md`, and its gaps in
   `docs/limitations.md`.
6. Make sure `rea uninstall` removes it.
