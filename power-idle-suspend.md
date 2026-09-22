# Power and Idle Management

Everything about monitor powerdown, suspend, and wake sources on this CachyOS
box. Distilled 2026-09-02 from opencode session `ses_fab678caf...` (2026-08-30,
Hyprland setup) and `ses_fabc8fb2...` (2026-08-30, suspend/wake fixes), then
updated for the GNOME manual-suspend policy on 2026-09-04.

History in one line: hypridle → custom idle daemon → custom daemon disabled
pending repair → GNOME handles monitor blanking while suspend is manual only.

## Current policy (2026-09-04)

- Automatic suspend is disabled in GNOME on both AC and battery power.
- The monitor still blanks after five minutes (`idle-delay=300`); this is the
  aggressive power-saving timeout and is independent of suspend.
- Manual suspend is available through a physical `XF86Sleep` key or
  `Super+Shift+Z`, both handled by GNOME Settings Daemon.
- `custom-idle.service` is disabled and stopped. Its files were preserved, not
  deleted, because the custom approach will return after its idle detection and
  desktop integration are fixed.
- `hypridle.service` is also disabled. Its preserved configuration still
  contains an automatic-suspend listener and must not be enabled as-is.
- systemd-logind has no configured `IdleAction`, so it does not provide a
  separate automatic-suspend path.

Applied settings:

```bash
gsettings set org.gnome.desktop.session idle-delay 300
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.media-keys suspend "['<Super><Shift>z']"
systemctl --user disable --now custom-idle.service hypridle.service
```

Verify the repository snapshot and live policy with:

```bash
CHECK_LIVE_POWER_POLICY=1 ./tests/check-power-policy.sh
```

The exact pre-repair source is in
[`power-management/custom-idle/`](power-management/custom-idle/README.md).

## Historical custom setup (disabled 2026-09-04)

> Note: the box has since moved through HyDE back toward Plasma/GNOME sessions
> (see [desktop-environments.md](desktop-environments.md)). The custom-idle
> daemon is Hyprland-specific in its DPMS call (`hyprctl dispatch dpms`). If
> running Plasma/GNOME, the DE's own power management handles DPMS; keep the
> suspend gate script and the sleep hook regardless.

1. **DPMS**: monitor powerdown after 5 min idle (300 s), wake on any input
   (`mouse_move_enables_dpms` / `key_press_enables_dpms` in Hyprland's
   `misc` settings).
2. **Suspend**: after 30 min idle (1800 s) AND system CPU < 4% (1 s sample)
   AND no AI agent process tree above 4% CPU (1 s sample). Rate-limited
   agents (low CPU) deliberately DO allow suspend.
3. **Wake sources**: power button + USB keyboard only. Everything else
   (mouse, NIC, PCIe PME) disarmed by `/etc/systemd/system-sleep/nowakeup.sh`.

## The custom idle daemon

`hypridle` was disabled and replaced by a standalone script so the suspend
policy is fully scripted, DE-agnostic, and agent-aware:

- Script: `~/.local/bin/custom-idle.sh`
- Unit: `~/.config/systemd/user/custom-idle.service` (`After=graphical-session.target`,
  `WantedBy=graphical-session.target`, `Restart=always`)
- Logs: `journalctl --user -t custom-idle -f`
- Knobs at top of script: `SYS_THRESH=4` (%), `AGENT_THRESH=4.0` (%),
  `DPMS_TIMEOUT=300` (s), `SUSPEND_TIMEOUT=1800` (s), `POLL=5` (s)

How it decides:

- Idle detection: `loginctl` session `IdleHint`/`IdleSinceHintMonotonic`, with a
  `hyprctl cursorpos` fallback poll. Max of the two wins.
- DPMS off/on: `hyprctl dispatch 'hl.dsp.dpms({action="off"})'` (CachyOS lua
  wrapper syntax), falling back to plain `hyprctl dispatch dpms off`.
- Suspend gate, both must pass:
  - System CPU: two reads of `/proc/stat` 1 s apart; usage must be < threshold.
  - Agent busy check: for patterns `opencode|claude|codex|pi`, collect each
    PID + all descendants via `pstree -p`, read
    `utime+stime+cutime+cstime` (fields 14–17 of `/proc/<pid>/stat`) twice 1 s
    apart, convert via `CLK_TCK`. Any PID+children over threshold = busy =
    skip suspend.
- Rate-limited agents sit at 0–1% CPU → suspend proceeds. This is intentional.

Why per-PID 1 s sampling: `ps -o %cpu` is a decaying lifetime average, not an
instantaneous sample — it misses bursts and misreports long-running processes.
The 1 s `/proc` delta is cheap (one shared sleep, ~40 PIDs) and accurate.

The earlier, simpler version of the gate lived at
`~/.config/hypr/scripts/suspend_if_low_cpu.sh` (called from hypridle's
1800 s listener). custom-idle.sh supersedes it but carries the same logic.

### systemd-inhibit (unused but documented)

The most robust way for an agent to block suspend is cooperation:
`systemd-inhibit --what=sleep --why="agent busy" <cmd>`. Check current
inhibitors with `systemd-inhibit --list`. Not wired into the script; CPU
sampling was chosen instead since agents don't take the lock themselves.

## Suspend instant-wake fix (2026-08-30)

Symptom: `systemctl suspend` woke itself after 8–12 s, every time.

Diagnosis path (worth remembering as method):

1. Suspend, then check wake time delta in `journalctl -b -u systemd-suspend`.
2. `cat /proc/acpi/wakeup` before/after — found `gpe04` count rising.
3. Masking gpe04 alone didn't help; disabling USB keyboard wake didn't help.
4. Real culprit: **PCIe PME wake signals** — some PCI device (NIC/NVMe/
   chipset line) fired a power-management event into every S3 sleep.
5. Fixed OS-side with a sleep hook that disarms all PCI/USB wake at pre-sleep.

`/etc/systemd/system-sleep/nowakeup.sh` (final version — keyboard re-enabled):

```bash
#!/bin/bash
# Pre-sleep: disarm PCI + USB wake sources so nothing but power button wakes
# the box; re-enable USB keyboard wake so typing brings it back.
if [ "$1" = "pre" ]; then
    for d in /sys/bus/usb/devices/*/power/wakeup; do echo disabled > "$d" 2>/dev/null; done
    for p in /sys/bus/pci/devices/*/power/wakeup;  do echo disabled > "$p" 2>/dev/null; done
    # keyboard only
    echo enabled > /sys/bus/usb/devices/3-4.2/power/wakeup 2>/dev/null
    # keyboard's upstream controller
    echo enabled > /sys/bus/pci/devices/0000:09:00.3/power/wakeup 2>/dev/null
fi
exit 0
```

Facts:

- The keyboard is USB `3-4.2` (GDMicroelectronics B87); its controller is PCI
  `0000:09:00.3` (Matisse USB, bus 3). The mouse shares that tree — wake is
  all-or-nothing per controller.
- The power button is an ACPI object; it bypasses PCI/USB wake entirely and
  always works.
- **Why `/etc/systemd/system-sleep/` and not `/usr/lib/systemd/system-sleep/`**:
  the latter is a package directory a systemd update can drop files into;
  `/etc` always wins and never gets wiped. First version of the hook was
  written to `/usr/lib` and moved.
- BIOS (Gigabyte B550 AORUS ELITE AX V2): **EnP enabled**; note that with ErP
  on, most wake-related BIOS options are hidden/grays out — that's why "Power
  On By PCI-E" etc. couldn't be found. OS-side disarm is the complete answer
  on this board.

## DPMS notes

- `hyprctl dispatch dpms off` is a true power-down (LED amber/backlight off),
  not just a blank screen. `brightnessctl` blanking is a different thing.
- DPMS off does NOT disrupt running agents, terminals, builds, or GUI app
  launches — the compositor keeps rendering offscreen, GPU buffers stay
  allocated. Only screen capture (`grim`/`slurp`) while DPMS-off returns a
  black frame.
- Suspend DOES pause agents — that's what the CPU gates are for.

## Hyprland config specifics (for when Hyprland is used)

- CachyOS's Hyprland edition uses a **lua wrapper**: `~/.config/hypr/hyprland.lua`
  loads modules from `~/.config/hypr/config/*.lua`. There is no stock
  `hyprland.conf`. Configs auto-reload on save.
- Monitor idle settings went in `config/misc.lua`:
  ```lua
  misc = {
      mouse_move_enables_dpms = true,
      key_press_enables_dpms = true,
  }
  ```
- The lua wrapper's dispatcher syntax differs from upstream docs:
  `hyprctl eval 'hl.dispatch(hl.dsp.dpms({action="off"}))'` rather than
  `hyprctl dispatch dpms off` (the latter still works as fallback).
- A HyDE experiment on 2026-08-30 (installed, then rolled back to the Cachy
  lua setup, ending hybrid) is recorded in
  [customizations.md](customizations.md). HyDE overwrote `~/.config/hypr`
  (backup at `~/.config/hypr.bak.20260830_1809`), fought the lua wrapper and
  greetd/noctalia (HyDE assumes clean Arch + SDDM), needed
  `ALTAB_NOTIFY=0` + `follow_mouse` fixes, and lost Cachy input tweaks
  (`repeat_rate=30`, `repeat_delay=200`, `accel_profile="flat"`) when the
  Cachy `config/` dir was dropped. The older `kb_options="ctrl:nocaps"` mapping
  is superseded by the global keyd mapping in
  [keyboard-remapping.md](keyboard-remapping.md).
  Lesson: pre-packaged Hyprland configs expect clean Arch; layering them on
  the CachyOS lua wrapper is an integration project, not an install.
