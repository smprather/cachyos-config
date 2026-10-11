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
