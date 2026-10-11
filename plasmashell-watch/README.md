# plasmashell-watch

A passive watchdog that captures a **gdb backtrace and core** from a wedged
`plasmashell`, before systemd's `TimeoutSec=40sec` SIGKILL can destroy the evidence.

Read `../plasmashell-wedge.md` first: it explains the 2026-10-10 wedge, why the trigger
was permanently unrecoverable, and the standing rules that came out of it.

## Why it exists

`plasmashell` handles SIGTERM through the Qt event loop (`KSignalHandler`). When its main
thread wedges it therefore cannot act on the signal at all, systemd waits out its full
40 s and then SIGKILLs — and a SIGKILLed process leaves no core, no backtrace and no
`/proc` state. Without this watchdog the next wedge is exactly as undiagnosable as the
last one. That is the whole reason the 2026-10-10 trigger is unknown.

## Design, and the two non-obvious constraints

1. **The probe runs as the session owner; the capture runs as root.**
   A user session bus rejects a cross-UID connection: as root the probe fails with
   `Failed to connect to system scope bus via local transport: Broken pipe`, because
   dbus-daemon's EXTERNAL auth requires the peer UID to match the bus owner. So the script
   resolves the session owner and uses `runuser -u <owner> -- busctl …`.
2. **Root is required only for the capture**, because `ptrace_scope` is 1 here, which
   refuses a same-user non-descendant `ptrace`. (Validated 2026-10-10: root attach to a
   non-child process succeeds.)

The liveness probe is a D-Bus `Peer.Ping` to `org.kde.plasmashell`. QtDBus dispatches on
the main event loop, so a healthy instance answers in ~2 ms and a wedged one cannot answer
at all. It is a true liveness test, not a CPU-usage guess.

It is passive. It never signals plasmashell unless the auto-kill flag is created by hand.

## Install

```bash
sudo install -Dm0755 plasmashell-wedge-watch.sh /usr/local/bin/plasmashell-wedge-watch.sh
sudo install -Dm0644 plasmashell-wedge-watch.service /etc/systemd/system/plasmashell-wedge-watch.service
sudo install -Dm0644 plasmashell-wedge-watch.timer   /etc/systemd/system/plasmashell-wedge-watch.timer
sudo systemctl daemon-reload
sudo systemctl enable --now plasmashell-wedge-watch.timer
```

## Verify

```bash
systemctl list-timers plasmashell-wedge-watch.timer   # NEXT within 10s
sudo systemctl start plasmashell-wedge-watch.service  # a healthy panel: silent, exit 0
journalctl -t plasmashell-wedge-watch --since '-5 min'  # expect NO output
ls -lA /var/log/plasmashell-wedge/                     # expect empty
```

A healthy run is silent and leaves nothing behind — verified by running it repeatedly
against a healthy panel (no capture, no accumulated strike file). A run costs ~80 ms,
so at a 10 s interval it is well under 1 % of one core.

**Never accept this watchdog on the strength of a healthy run alone.** The failure path is
the one that matters, and it is testable without touching your real panel:

```bash
# Full failure path against a sacrificial process, as root. Expect .txt, .gdb.txt, .core.zst.
sleep 300 & SP=$!
sudo PWW_PID=$SP PWW_PROBE=false PWW_STRIKES=1 PWW_MIN_UPTIME=0 \
     PWW_STATE_DIR=/tmp/pww-test PWW_AUTO_KILL_FLAG=/nonexistent \
     /usr/local/bin/plasmashell-wedge-watch.sh
ls -lA /tmp/pww-test/
```

Test seams: `PWW_PID`, `PWW_PROBE`, `PWW_STRIKES`, `PWW_STATE_DIR`, `PWW_NO_GDB`,
`PWW_CORE_RETAIN`, `PWW_MIN_UPTIME`, `PWW_AUTO_KILL_FLAG`.

## What a capture contains

`/var/log/plasmashell-wedge/wedge-<timestamp>.txt` — per-thread state, `wchan`, `syscall`,
`/proc/<pid>/status`, and kernel stacks (root-only, needs `CONFIG_STACKTRACE`).
`…gdb.txt` — `info threads` plus `thread apply all bt`.
`…core.zst` — the core, zstd-compressed; only the newest `PWW_CORE_RETAIN` (2) are kept.

To get function names beyond the dynamic symbol table, install the matching debug packages
**at that point**, not now — they must track the running versions or they are worse than
useless (`gdb` already warns that the installed glibc debug data has a CRC mismatch):

```bash
sudo pacman -Syu plasma-workspace-debug qt6-base-debug qt6-wayland-debug
```

## Auto-kill (opt-in, off by default)

```bash
sudo touch /etc/plasmashell-wedge-watch.autokill     # enable
sudo rm /etc/plasmashell-wedge-watch.autokill        # disable
```

With the flag present, a captured wedge is followed by SIGKILL, so the unit's
`Restart=on-failure` respawns the panel and logout stops costing 40 seconds. It is off by
default because a false positive would kill a *working* panel, and the false-positive rate
cannot be established without observing this watchdog over time. Enable it only after the
journal shows the probe has never failed on a healthy panel.

## Rollback

```bash
sudo systemctl disable --now plasmashell-wedge-watch.timer
sudo rm -f /etc/systemd/system/plasmashell-wedge-watch.{service,timer} \
           /usr/local/bin/plasmashell-wedge-watch.sh
sudo systemctl daemon-reload
sudo rm -rf /var/log/plasmashell-wedge
```

Then remove the `/usr/local/bin` entry from `../system-inventory.md`, which lists unowned
shims — an unowned shim has no lifecycle, so nothing else will ever notice it is gone.
