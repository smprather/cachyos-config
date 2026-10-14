# The plasmashell wedge (2026-10-10)

On 2026-10-10 the Plasma panel (taskbar) stopped responding, and logging out took
about a minute. Both symptoms are one event: **`plasmashell` wedged in userspace.**
This file records the mechanism, what was ruled out, why the trigger could not be
recovered, and the instrument now in place to catch the next one.

Read this before concluding "the desktop froze". The compositor was healthy.

## What happened, to the second

| Time | Event |
| --- | --- |
| 19:04:40 | logout invoked (`dbus-:1.2-org.kde.LogoutPrompt@0` created) |
| 19:04:47 | prompt #1 closed after 6.5 s |
| 19:04:55 | **second** LogoutPrompt — logout pressed again after the first appeared to do nothing |
| 19:05:05 | prompt #2 closed (10.3 s); `org.kde.Shutdown` started |
| 19:05:07 | `plasma-workspace-wayland.target` stopped, SIGTERM to the session |
| **19:05:07 → 19:05:47** | **40 s of total silence** — no unit, no kernel, no app logged anything |
| 19:05:47 | `plasma-plasmashell.service: State 'stop-sigterm' timed out. Killing.` |
| 19:05:47 | `Killing process 1290 (plasmashell) with signal SIGKILL` |
| 19:05:48 | `plasma-plasmashell.service: Failed with result 'timeout'`; session 2 logged out |
| 19:05:49 | noctalia greeter up |
| 19:06:03 | new session; new `plasmashell` (pid 454073) |

First logout to usable desktop: **19:04:47 → 19:06:03 = 76 s**, of which the visible
hang is **61 s**.

## The mechanism

`/usr/lib/systemd/user/plasma-plasmashell.service` ships `TimeoutSec=40sec` — verified,
with no drop-in overrides anywhere. systemd sent SIGTERM at 19:05:07, waited its full
40 s, then SIGKILLed.

It waited the full 40 s because **plasmashell never processed the signal.** The binary
calls `KSignalHandler::self()->watchSignal(...)` (`KSignalHandler::watchSignal` and
`signalReceived` symbols are in `/usr/bin/plasmashell`; the implementation is in
`libKF6CoreAddons`). That path turns the signal into a Qt event delivered through the
event loop, so **a blocked main thread cannot act on SIGTERM however long you wait.**

Two consequences worth keeping:

1. Because a healthy plasmashell exits in milliseconds, the need for SIGKILL proves it
   was **already wedged before logout began** — the frozen panel and the slow logout are
   the same incident, not two.
2. Panel applets (`org.kde.plasma.icontasks`, the taskbar, among them) run **in-process
   inside plasmashell**. One blocked main thread freezes every applet at once.

kwin was healthy throughout: it kept logging window events straight through the freeze
and shut down cleanly. This was not a compositor, GPU, or system-wide stall.

Dead instance's final accounting, for reference: pid 1290, up 1 d 10 h 41 m, **512.1 M
memory peak, 6 M swap peak, 18 min 34 s CPU**, and only 41 journal lines in its entire
34-hour life — it was silent from 14:11 onward.

## Ruled out (each verified, not assumed)

- **Memory** — 512 M peak, 6 M swap. `earlyoom` logged 33–40 % RAM available and
  98–100 % swap free all day. No OOM kill.
- **Crash** — no coredump, no KCrash/DrKonqi record, no restart loop. It was killed.
- **Disk** — 39 G free on `/`; journal was 47.5 M; no kernel hung-task, soft-lockup or
  blocked-task warnings.
- **Dead disk / uninterruptible I/O** — SIGKILL worked instantly, so it was not stuck in
  D state.
- **Third-party panel widgets** — every applet in `plasma-appletsrc` is stock KDE.
- **Packages replaced under the running session** — `find /usr/bin /usr/lib
  /usr/share/plasma -newermt '2026-10-09 08:23'` returns **0 files**.
- **An unlogged Oct 7 install** — `/usr/bin/plasmashell` mtime 2026-10-07 15:04 looked
  like one, but it is the package **Build Date**: pacman preserves archive mtimes. Not
  evidence of anything.
- **PlasmaZones window churn** (weakened, not fully cleared) — the focus flapping and
  float/minimise either side of 19:04 looks dramatic, but 12:00 that day produced 41 of
  the same `stashing for reseed` lines with no freeze. It is routine on this box.

## Why the trigger was not recoverable

SIGKILL destroys the evidence: no core, no backtrace, no `/proc` state, and plasmashell
itself logged nothing at the moment of the wedge. **A successful post-mortem of a
SIGKILLed process is impossible by construction.** That, not a shortage of effort, is
why the trigger is unknown.

Two live candidates exist, neither proven:

- **Wayland clipboard path.** The panel runs the stock `org.kde.plasma.clipboard` applet,
  so plasmashell itself is the clipboard manager (klipper) and does the data reads and
  offers in-process. The replacement instance immediately logged
  `QWaylandDataOffer: timeout reading from pipe` for `text/plain;charset=utf-8` **and**
  `text/plain`, plus two `QWaylandDataSource: peer closed pipe`, within 4 s of starting —
  a misbehaving clipboard peer demonstrably exists here.
- **Audio/PipeWire path.** The volume applet was erroring every ~45 s
  (`PipeWire remote error: -2 target not found`, `unknown resource 5 op:4/op:7`) against a
  suspended HDMI sink, and the dead instance had repeatedly logged
  `No object for name "alsa_output.pci-0000_07_00.1.hdmi-stereo" returning nullptr` for the
  same device.

## The instrument: `plasmashell-watch/`

`plasmashell-watch/` in this repo holds a passive watchdog that detects an unresponsive
plasmashell and captures a gdb backtrace plus a core **before** the 40 s timeout can
SIGKILL it. See `plasmashell-watch/README.md` for install, verification and rollback.

Its liveness probe is a D-Bus `Peer.Ping` to `org.kde.plasmashell`, which a healthy
instance answers in ~2 ms and a wedged one cannot answer at all, because QtDBus
dispatches on the main event loop. Root is required to attach: `ptrace_scope` is 1 here,
so a same-user non-descendant ptrace is refused (validated — root attach works).

**Do not remove this on the grounds that it "never fires".** A watchdog that has not fired
is a watchdog that has not been needed yet; the entire point is that without it, the next
wedge is again unrecoverable.

## Standing rules learned here

- **Do not edit `/usr/lib/systemd/journald.conf.d/00-journal-size.conf`.** It belongs to
  `cachyos-settings` and caps the journal at `SystemMaxUse=50M`, which retained barely one
  boot — and had already rotated away the first 7 h of the current one. Override it in
  `/etc/systemd/journald.conf.d/` instead.
- **`pacman.conf`'s commented `#LogFile` is not a problem.** `pacman-conf LogFile` returns
  `/var/log/pacman.log`; the comment is just the shipped default and logging is on. Do not
  "fix" it.
- **`shelly upgrade all` writes no pacman log.** Transactions on 2026-10-09 00:17–00:28
  (snapper 167–174) upgraded `qt6-base` 6.11.2 → **6.12.0**, `qt6-wayland` 6.12.0,
  `plasma-workspace`/`kwin`/`plasma-integration` 6.7.5-3.1 — and left `/var/log/pacman.log`
  untouched since 2026-10-06 15:53. Reconstruct what changed from `snapper -c root list`
  and `pacman -Qi <pkg> | grep 'Install Date'`, never from `pacman.log` alone.
- **Core-dump capture already works.** `systemd-coredump.socket` is active and listening;
  `core_pattern` pipes to it. Zero coredumps means nothing has genuinely crashed — not
  that capture is broken. Do not "enable" it again.
- **`~/.local/bin/tmux` is gone** (loadout relocated it). Anything holding that literal
  path fails. Verified healthy: `tmux-persist-autosave.service` (resolves via PATH).
  Broken and repaired 2026-10-10: `candelise/org_chart.toml`'s `tmux_bin`. Still stale,
  and deliberately left alone: the dated prototype
  `candelise/superpowers/sdd/2026-09-12-agent-channel/prototype_channel_probe.py`.

## The second failure mode (2026-10-14): a spin the probe cannot see

Same user-visible triad as 2026-10-10 — distorted/"infinite window" rendering, a locked
taskbar, a logout that never completes — but a **different mechanism**, and the instrument
above did not fire for it (0 strikes, no capture).

What was actually true at 09:09 on 2026-10-14, from `/proc` and a root gdb attach:

- `plasmashell` pid 1527, `State: R`, main thread alone at ~100 % of one core,
  **16 min 44 s of CPU in 41 min** of wall clock.
- The main thread was in Qt Quick's GL fallback path, entered from the Wayland flush:

  ```text
  #12  QRhiGles2InitParams::newFallbackSurface(QSurfaceFormat const&)   [libQt6Quick.so.6]
  #11  QOpenGLContext::destroy()
  #9   QtWaylandClient::QWaylandGLContext::~QWaylandGLContext()
  #0-8 libnvidia-eglcore.so.615.78.08 / libEGL_nvidia.so.0
  #17  QGuiApplicationPrivate::processExposeEvent
  #20  QtWaylandClient::QWaylandWindow::updateExposure()
  #31  QCoreApplication::exec()
  ```

  So Qt could not get a usable GL surface and re-ran the whole init on every Expose event —
  the event loop still dispatched (which is why D-Bus answered in ~2 ms and the liveness
  probe saw nothing), but the frame never completed. Every panel applet runs in-process, so
  they all froze together, and the logout handshake could never finish.

- Restarting the unit cleared it (new pid, main thread back in `ppoll`, CPU falling).
  Captures: `plasmashell-watch/captures/2026-10-14-egl-spin/` — durable copies of the
  summary, the per-thread dump and both gdb backtraces (the 20 MB core is deliberately not
  kept: the backtrace carries the same information). Originals under
  `/tmp/plasmashell-hang-20261014-090913/` until /tmp is next cleared.

### What was changed because of it

- **The watchdog gained a CPU-spin source** (`plasmashell-watch/plasmashell-wedge-watch.sh`):
  utime+stime per tick, strike when the process burns more than
  `PWW_SPIN_THRESHOLD` (default 0.5) of one core for `PWW_SPIN_STRIKES` (default 3)
  consecutive samples. Both failure paths were tested with the script's own seams, and the
  capture records `reason:` so a future reader knows which source fired.
- **Auto-kill is now on** (`/etc/plasmashell-wedge-watch.autokill`), so a repeat costs a
  panel blink and a core file instead of a session. Capture happens before the kill.
- **`~/.local/bin/fixpanel`** — the manual answer without a 40 s wait: SIGKILL the unit
  (SIGTERM is handled through the event loop, so a stuck shell ignores it), let
  `Restart=on-failure` respawn it, then poll the D-Bus probe until it answers.

### Dead ends, recorded so they are not retried

- **`QSG_RHI_BACKEND=software` does not exist in this Qt build.** With the drop-in in
  place, plasmashell logged `Unknown key "software" for QSG_RHI_BACKEND, falling back to
  default backend.` and kept the whole NVIDIA EGL stack mapped, so the containment it was
  meant to provide was never in effect. Reverted the same hour.
- **The i2c `EACCES` lines are PowerDevil, and they are a race, not a fault.**
  `org_kde_powerdevil` (ddcutil DDC/CI probe) opens `/dev/i2c-N` milliseconds after the
  NVIDIA driver creates those adapters; udev's `uaccess` ACL has not landed yet, so the
  first open fails. Verified benign: the nodes carry `TAGS=:uaccess:seat:` and
  `user:mylesp:rw-` once settled, and nothing is broken by the failure. Do not "fix" it with
  a udev rule — a rule already exists (`/usr/lib/udev/rules.d/60-ddcutil-i2c.rules`).

### Still open

- **The KVM, measured and then cleared (2026-10-14).** The KVM in use has EDID emulation and
  it works: across a real switch, the HDMI connector stayed `connected` at 1 Hz for 97 s
  with an unchanged EDID hash and zero `Placeholder-1` events (the KVM's USB emulated
  devices re-attaching is normal, not a fault). Earlier `Placeholder-1` events — including a
  1-second pair at 2026-10-13 14:02:44→45 — are therefore not switch artifacts, and this
  failure mode is not a KVM artifact either. What still fits the stack frames is the driver
  generation below.
- **Driver generation: watched, deliberately not pinned.** All the pre-2026-10-14 suspicion
  came from the stack frames (`libnvidia-eglcore.so.615.78.08`) and the resume storms. But the
  prebuilt module packages pin exact versions — `linux-cachyos-nvidia-open` requires
  `linux-cachyos=<exact>` *and* `nvidia-utils=<exact>`, and `linux-cachyos-lts-nvidia-open`
  does the same for the LTS pair — so holding the driver means holding both kernels, and the
  NVRM resume assertions appear on 615.71.09 too (1 961 lines in the boot that ran mostly on
  it). With the shell contained off the EGL path, that trade is not worth making today.
  `nvidia-open-dkms` is the pin-free alternative if a hold is ever wanted: hold the driver,
  keep the kernels moving, let DKMS rebuild. Either way the *next* driver change is noticed
  rather than discovered: `bin/nvidia-driver-watch.sh` runs weekly as a user timer and logs
  to `journalctl --user -t nvidia-driver-watch`, with the test order (fresh login → does the
  running shell map libnvidia-eglcore → suspend/resume and grep for
  `kgmmuInvalidateTlb_GM107` → leave it a day and let the watchdog watch).
- **The shell is contained off the NVIDIA EGL path**
  (`~/.config/systemd/user/plasma-plasmashell.service.d/10-mesa-software-gl.conf`: Mesa's EGL
  vendor pinned + software rasteriser). Verified: `libnvidia-eglcore` is absent from
  plasmashell's maps and idle CPU measured 0.02 of one core over 10 s. The `newFallbackSurface`
  retry loop cannot run in the shell regardless of which trigger fires; delete the drop-in to
  go back to a GPU-rendered panel.

### The rule that matters when the panel freezes

The machine stays alive — D-Bus, journal, systemd and your terminals all keep working. Do
**not** hold the power button; that is what dirtied `/boot` and forced a BTRFS tree-log
replay on 2026-10-14. Run `fixpanel` instead, or wait for the watchdog's auto-kill.

If the freeze is *not* panel-only — desktop unusable, or nothing responds at all — the full
ladder is in `frozen-system-recovery.md`: VT3 rescue shell, what REISUB cannot do here, the
power-button hold and why it is safe, and booting a limine snapshot.
