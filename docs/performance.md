# Performance

## No numbers are published here

Rea was written on a machine that does not run GNOME. **Every figure below is a
template with blanks**, not a measurement, because publishing invented
benchmarks would be worse than publishing none. `rea bench` produces the real
numbers on your hardware in about a minute, and your hardware is the only
hardware that matters for this decision.

## Method

```bash
rea bench before     # before installing. Leave the desktop idle.
rea install
# log out and back in
rea bench after
rea bench --compare
```

Samples are JSON in `~/.local/share/rea/bench/`.

| Metric | How it is measured | Why this one |
| --- | --- | --- |
| `shell_rss_mb` | `VmRSS` of `gnome-shell` from `/proc` | extensions live in the shell process; this is where they show up |
| `shell_cpu_idle_pct` | `utime+stime` delta over a 20s idle window ÷ clock ticks | catches the classic failure: an extension polling on a timer |
| `system_mem_used_mb` | `MemTotal − MemAvailable` | whether the desktop as a whole got heavier |
| `boot_ms` | `systemd-analyze` total | whether anything was added to startup |
| `enabled_extensions` | `gnome-extensions list --enabled` | the best single predictor of shell overhead |

Set a longer window if the machine is noisy:
`REA_BENCH_SAMPLE_SECONDS=60 rea bench after`.

## What `rea bench` deliberately does not measure

**Frame timing.** Dropped frames are what people actually feel, and measuring
them properly needs a GPU profiler, not a shell script. Measure it yourself:

```bash
# Intel / AMD: per-engine GPU busy while you drag a window and open the overview
sudo intel_gpu_top          # intel-gpu-tools
sudo amdgpu_top             # amdgpu-top

# Mutter's own frame log (GNOME 44+); look for "frame missed" lines
journalctl --user -b -u gnome-shell | grep -i "frame"

# Compositor timing on Xorg only
MUTTER_DEBUG_ENABLE_ATOMIC_KMS=0 journalctl --user -f
```

Also unmeasured: battery drain (needs an hour of controlled idle on each
configuration — the method is in the table below), and application launch time,
which Rea does not change.

## Results template

Copy into `docs/final-report.md` once you have run it.

| Metric | Before | After (`balanced`) | Change | Accept? |
| --- | --- | --- | --- | --- |
| gnome-shell memory (MB) | | | | |
| gnome-shell CPU, idle (%) | | | | |
| System memory in use (MB) | | | | |
| Boot time (ms) | | | | |
| Enabled extensions | | | | |
| Battery drain, idle 1h (%) | | | | |

Suggested thresholds, from what GNOME extensions typically cost:

| Metric | Fine | Investigate | Step down a profile |
| --- | --- | --- | --- |
| shell memory increase | < 80 MB | 80–150 MB | > 150 MB |
| shell CPU at idle | < 1% | 1–3% | > 3% |
| boot time increase | < 300 ms | 300–1000 ms | > 1000 ms |

## Where the cost comes from, and what to turn off first

In rough order of cost:

1. **Full-screen overview blur** — a blur pass over the whole screen every
   frame while the overview animates. `balanced` already disables it
   (`REA_BLUR_PANEL_ONLY=1`).
2. **Dock magnification** — recomputes icon geometry on every pointer move
   along the dock. Set `REA_DOCK_MAGNIFY=0`, or use the `classic` dock.
3. **Per-window blur** — off in every profile. Never turn it on; it also breaks
   apps that draw their own background.
4. **Rounded window corners** — a mask per window, cheap but not free.
5. **Live dock icons** (clock face, calendar) — Rea disables them explicitly:
   each one is a redraw every second, forever.
6. **Panel blur** — Rea uses `static-blur`, one cached texture, which is close
   to free. Dynamic panel blur is not.

Fastest path to a cheaper desktop without losing the look:

```bash
rea profile set lite    # theme, icons, fonts; no blur, no magnification
rea bench after && rea bench --compare
```

## Design choices made for performance

- No second dock process, no gesture daemon, no extra compositor.
- No polling: nothing in Rea runs on a timer after installation. Rea is not
  resident at all — it is a tool you run, not a service.
- Static blur over dynamic, everywhere it is offered.
- Native settings preferred over extensions, so most of the result costs
  nothing at runtime.
- `lite` exists so that "it is too slow" has a one-command answer instead of
  an uninstall.
