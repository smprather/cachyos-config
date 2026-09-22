# CachyOS Customization Log

This is an append-only record of the system customizations made during this setup.

## 2026-08-30

Backfilled from opencode session records on 2026-09-02. These predate the
entries below.

### Monitor powerdown (5 min) — Hyprland

- Added `mouse_move_enables_dpms = true` and `key_press_enables_dpms = true`
  to `~/.config/hypr/config/misc.lua` (CachyOS lua wrapper).
- Installed `hypridle` + `hyprlock`; created `~/.config/hypr/hypridle.conf`
  with a 300 s listener dispatching DPMS off/on (lua-wrapper form:
  `hl.dsp.dpms`).
- Enabled `systemctl --user enable --now hypridle.service`.
- Detail: [power-idle-suspend.md](power-idle-suspend.md)

### Idle suspend with CPU + agent gating

- Built `~/.config/hypr/scripts/suspend_if_low_cpu.sh`, wired into
  hypridle's 1800 s listener: suspends only when system CPU (1 s `/proc/stat`
  delta) is under threshold AND no AI agent process tree
  (`opencode|claude|codex|pi` + descendants via `pstree`, 1 s
  `/proc/<pid>/stat` utime+stime+cutime+cstime delta) exceeds the per-PID
  threshold. Rate-limited agents (low CPU) deliberately allow suspend.
- Threshold settled at 4% (system) / 4% (per agent PID tree).
- Later the same day, hypridle was disabled and replaced by a standalone
  daemon: `~/.local/bin/custom-idle.sh` +
  `~/.config/systemd/user/custom-idle.service` (graphical-session.target),
  polling loginctl idle hints with a `hyprctl cursorpos` fallback, same CPU
  and agent gates. Fully DE-agnostic, no hypridle/HyDE involvement.
- Detail: [power-idle-suspend.md](power-idle-suspend.md)

### HyDE installed over CachyOS Hyprland (later de-hybrided)

- Cloned HyDE, installed with patches: `hyprland.lua` loader extended to
  `~/.local/share/hypr/hyde.lua`; fixed `pipewire-jack` vs `jack2` conflict;
  symlinked portable-python SSL cert to `/etc/ssl/certs/ca-certificates.crt`.
- Set `ALTAB_NOTIFY=0` via `hl.env()` in `~/.config/hypr/config/environment.lua`
  to silence HyDE's alt-tab preview bubble.
- Experimented with `follow_mouse` 0/1 and an altab cursor-warp patch
  (upstream bug — warp bounced back; workaround is choosing follow_mouse or
  sticky alt-tab, not both).
- An "all-in HyDE" flip dropped the Cachy `config/` dir; restored
  `kb_options="ctrl:nocaps"`, `follow_mouse=1`, `repeat_rate=30`,
  `repeat_delay=200`, `accel_profile="flat"`, DPMS wake options into
  `~/.config/hypr/hyprland.lua`.
- Backups: `~/.config/hypr.bak.20260830_1809`, `config.cachy.bak`,
  `hyprland.lua.cachy.bak`. Lesson file:
  [hyprland-cachyos-lua-hyde.md](hyprland-cachyos-lua-hyde.md)

### Hyprland (uwsm-managed) login entry fixed

- The uwsm session entry at the greetd screen crashed back to login (looked
  like a password rejection). Root cause: uwsm's
  `/usr/lib/uwsm/prepare-env.sh` sources `~/.profile` → the loadout bashrc's
  `unset -f` wiped uwsm's own helper functions.
- Fix: non-interactive guard (`case $- in *i*) ...`) at the top of
  `~/.config/bash/bashrc`. Both login entries work.
- Detail: [suspend-clock-uwsm-fixes.md](suspend-clock-uwsm-fixes.md)

### Dual-boot hardware clock set to local time

- `sudo timedatectl set-local-rtc 1` — matches Windows's local-time RTC
  assumption; fixes the 5–6 hour clock skew after booting between OSes.
- Detail: [suspend-clock-uwsm-fixes.md](suspend-clock-uwsm-fixes.md)

### Suspend instant-wake fixed (sleep hook)

- Suspend was waking itself after ~8 s via PCIe PME signals. Fixed with
  `/etc/systemd/system-sleep/nowakeup.sh`: disarms all PCI/USB wake at
  pre-sleep, re-enables only the USB keyboard (`3-4.2`) and its controller
  (`0000:09:00.3`). Power button wake unaffected (ACPI path).
- BIOS: ErP enabled. Note ErP hides the other wake options in firmware
  setup on this Gigabyte B550.
- Detail: [power-idle-suspend.md](power-idle-suspend.md)

### systemd OSC-3008 hook preserved through bashrc clean-slate

- Every command printed `-bash: __systemd_osc_context_ps0: command not found`:
  `/etc/profile.d/80-systemd-osc-context.sh` sets `PS0` referencing a
  function the clean-slate wipe then deleted. Fix: the wipe block harvests
  function names referenced by inherited `PS0` and keeps them.
- Detail: [shell-startup-quirks.md](shell-startup-quirks.md)

### pkill self-match hazard documented

- `pkill -f <pattern>` matching the invoking `bash -c` wrapper's own command
  line killed the shell twice (tool timeouts). Rules codified in
  `~/.config/opencode/skills/pkill-safety/SKILL.md`: kill by exact name
  (`pkill -9 -x <comm>`) or by PID list from `/proc/<pid>/exe`.
- Detail: [shell-startup-quirks.md](shell-startup-quirks.md)

## 2026-08-31

Backfilled from session records on 2026-09-02. These changes predate the
entries below.

### Plasma desktop completed

- Installed `plasma-meta` (90 packages) with `sudo pacman -Syu --needed --noconfirm plasma-meta`.
- Plasma had been installed piecemeal; roughly 40 packages from the `plasma`
  group were missing, including `plasma-desktop`, `systemsettings`, `plasma-pa`,
  `plasma-nm`, `powerdevil`, `kscreen`, and `polkit-kde-agent`.
- Rollback: snapper snapshot `root: 60`.
- Detail: [desktop-environments.md](desktop-environments.md)

### Autologin into Plasma

- Added an `initial_session` block to `/etc/greetd/config.toml` that logs
  directly into Plasma at boot. Logging out still returns to the noctalia
  greeter, where GNOME and Hyprland remain selectable.
- Rollback: `sudo cp /etc/greetd/config.toml.bak-20260831-224205 /etc/greetd/config.toml`

### kwallet disabled, gnome-keyring made the single secret store

- `~/.config/kwalletrc` sets `Enabled=false`; `~/.config/autostart/pam_kwallet_init.desktop`
  hides the kwallet autostart.
- `/etc/xdg-desktop-portal/kde-portals.conf` overrides the KDE secret portal to
  use `gnome-keyring` instead of `kwallet`.
- Rollback: `rm ~/.config/kwalletrc ~/.config/autostart/pam_kwallet_init.desktop`
  and `sudo rm /etc/xdg-desktop-portal/kde-portals.conf`

### Blank login keyring

- Created `~/.local/share/keyrings/login.keyring` with no password, because
  autologin cannot derive a keyring unlock key. Keyring contents are therefore
  unencrypted on disk. Accepted deliberately; the disk itself is unencrypted.
- Rollback: `rm -r ~/.local/share/keyrings`

### gnome-keyring PAM unlock

- Added `pam_gnome_keyring.so` lines to `/etc/pam.d/greetd`, all `optional`.
- Rollback: `sudo cp /etc/pam.d/greetd.bak-20260831-223906 /etc/pam.d/greetd`

### Passwordless polkit for wheel

- Added `/etc/polkit-1/rules.d/49-nopasswd-wheel.rules`, returning
  `polkit.Result.YES` for active local members of `wheel`. Matches the existing
  `NOPASSWD: ALL` sudo rule.
- Rollback: `sudo rm /etc/polkit-1/rules.d/49-nopasswd-wheel.rules`

### Lock screen disabled

- Plasma: `~/.config/kscreenlockerrc` with `Autolock=false`, `LockOnResume=false`,
  `LockOnDelay=0`, `Timeout=0`.
- GNOME: `gsettings set org.gnome.desktop.screensaver lock-enabled false`,
  `gsettings set org.gnome.desktop.screensaver idle-activation-enabled false`,
  `gsettings set org.gnome.desktop.session idle-delay 0`.
- Rollback: delete `~/.config/kscreenlockerrc`; `gsettings reset` the three keys.

## 2026-09-01

### GNOME interface font

- Set the GNOME interface font to `Cantarell 11`.
- Command: `gsettings set org.gnome.desktop.interface font-name 'Cantarell 11'`
- Rollback: `gsettings set org.gnome.desktop.interface font-name 'Noto Sans 10'`

### Keyboard layout

- Superseded on 2026-09-07 by the global keyd tap/hold mapping in
  [keyboard-remapping.md](keyboard-remapping.md).
- Original change: mapped Caps Lock to Left Ctrl using GNOME's XKB option
  `ctrl:nocaps`.
- Command: `gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"`
- Rollback: `gsettings set org.gnome.desktop.input-sources xkb-options "[]"`

### Chrome Canary fontconfig

- Added `FONTCONFIG_FILE=/etc/fonts/fonts.conf` to the per-user environment.
- File: `~/.config/environment.d/90-fontconfig.conf`
- This fixes Chrome Canary's `Fontconfig error: Cannot load default config file` message.
- The live systemd user environment was refreshed with:
  `systemctl --user set-environment FONTCONFIG_FILE=/etc/fonts/fonts.conf`
- Rollback: remove `~/.config/environment.d/90-fontconfig.conf`, then log out and back in.

### Chrome Canary GPU backend

- Chrome Canary's GPU process repeatedly crashed with `SIGSEGV` inside NVIDIA's `libnvidia-glcore.so.610.57.04` while running native Wayland.
- Verified the NVIDIA RTX 3060, Vulkan, and OpenGL stack independently.
- Tested native Wayland with ANGLE OpenGL and WebGL; Chrome's GPU process stayed alive and NVIDIA reported Chrome using GPU memory.
- Replaced the temporary `--disable-gpu` workaround with `--use-angle=gl` in `~/.config/chrome-canary-flags.conf`.
- Rollback: remove `--use-angle=gl`; if the default backend crashes again, restore `--disable-gpu`.

## Session notes

- Desktop: GNOME
- Session type: Wayland
- GNOME font rendering: RGBA antialiasing, slight hinting, RGB order, automatic rendering
- Chrome Canary still logs a Wayland/Vulkan compatibility warning even with the GL backend; it did not reproduce a crash in the verified test.

## 2026-09-06

### PlasmaZones guarded to Plasma sessions only

- Stopped `plasmazones.service` after it created a full-screen `PlasmaZones`
  window above WezTerm in a GNOME Wayland session, intercepting mouse input for
  text selection, tmux pane selection, window movement, and window close.
- Added `~/.config/systemd/user/plasmazones.service.d/override.conf` with
  `ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE`.
- Left `plasmazones.service` enabled so it remains wanted by
  `plasma-workspace.target` and should still start on Plasma logins.
- Verified that a manual start in the live GNOME session is skipped with the
  unmet condition `ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE`.
- Detail: [desktop-environments.md](desktop-environments.md)

## 2026-09-07

### Global Caps Lock tap/hold remap with keyd

- Made `keyd` the single source of truth for Caps Lock behavior across Plasma,
  GNOME, Hyprland, terminals, and Wayland applications.
- Added `capslock = overload(control, esc)` to `/etc/keyd/default.conf`,
  preserving the existing `rightmeta = macro(C-backslash z)` binding.
- Cleared the previous GNOME XKB option:
  `gsettings set org.gnome.desktop.input-sources xkb-options "[]"`.
- Removed `kb_options = "ctrl:nocaps"` from
  `~/.config/hypr/config/inputs.lua`; repeat, delay, accel, and follow-mouse
  settings were left intact.
- Verified `keyd check` passed before `keyd reload`; then verified GNOME
  `xkb-options` is empty (`@as []`), the Hyprland active input file no longer
  contains `ctrl:nocaps`, and keyd contains the tap/hold Caps binding.
- Rollback backups:
  `/etc/keyd/default.conf.bak-20260907-114443` and
  `~/.config/hypr/config/inputs.lua.bak-20260907-114443`.
- Detail: [keyboard-remapping.md](keyboard-remapping.md)

### Chrome Canary YouTube stutter in Plasma

- Diagnosed stuttery YouTube playback after switching back to Plasma Wayland.
- Found Chrome Canary running with a GPU process crash count of 3 and many
  renderer processes in `--disable-gpu-compositing` fallback.
- Verified the NVIDIA RTX 3060 OpenGL/EGL stack still works outside Chrome.
- Tested a disposable native-Wayland YouTube probe with forced NVIDIA VA-API;
  that crashed the Chrome GPU process with exit code 139, so VA-API forcing was
  rejected.
- Tested a disposable XWayland YouTube probe with `--use-angle=gl`; the GPU
  process did not crash during the probe.
- Updated `~/.config/chrome-canary-flags.conf` to:
  `--use-angle=gl` and `--ozone-platform=x11`.
- Chrome Canary still needs a full restart before the new flags can affect the
  user's active profile.
- Rollback: `cp ~/.config/chrome-canary-flags.conf.bak-20260907-121005 ~/.config/chrome-canary-flags.conf`
- Detail: [chrome-fixes.md](chrome-fixes.md)

### Switched daily browser from Chrome Canary to Google Chrome Stable

- Installed `google-chrome 152.0.7977.82-1` from `chaotic-aur`.
- Removed `google-chrome-canary 154.0.8035.0-1`.
- Left Canary profile data under `~/.config/google-chrome-canary/` intact.
- Added Stable Chrome flags in `~/.config/chrome-flags.conf`:
  `--use-angle=gl` and `--ozone-platform=x11`.
- Stable Chrome launcher: `google-chrome-stable`.
- Rollback: reinstall Canary with `sudo pacman -Syu --needed google-chrome-canary`
  and remove Stable with `sudo pacman -Rns google-chrome`.
- Detail: [chrome-fixes.md](chrome-fixes.md)

## 2026-09-04

### GNOME Tweaks system-runtime launcher

- Added `bin/gnome-tweaks` and linked it from `~/.local/bin/gnome-tweaks`.
- The launcher clears the shared-prefix Python, GI typelib, and dynamic-library
  overrides before executing the pacman-owned `/usr/bin/gnome-tweaks`.
- This keeps the custom `~/.local` toolchain available while ensuring GNOME
  Tweaks uses CachyOS's matching Python and native GNOME libraries.
- Rollback: remove `~/.local/bin/gnome-tweaks`; the source launcher may then be
  removed from this repository.
- Detail: [gnome-configuration.md](gnome-configuration.md)

### GNOME keyboard repeat

- Enabled key repeat with a 200 ms initial delay and a 33 ms repeat interval
  (approximately 30.3 repeats per second), matching the intended Hyprland
  behavior as closely as GNOME's integer-millisecond schema permits.
- Applied through `org.gnome.desktop.peripherals.keyboard` with `gsettings` and
  verified by reading all three keys back from the live dconf database.
- Rollback: reset the `repeat`, `delay`, and `repeat-interval` keys with
  `gsettings reset`.
- Detail: [gnome-configuration.md](gnome-configuration.md)

### GNOME FancyZones-style drag tiling

- Configured Tiling Shell 17.3 so its layout appears immediately during a
  window drag and follows the pointer without requiring a trip to the top edge
  or an activation modifier.
- Set no activation modifier (`-1`), Ctrl as the per-drag bypass (`0`), disabled
  the separate Snap Assistant, and set the preview animation time to zero.
- Disabled Tiling Shell's replacement screen-edge handler. This restored the
  saved native Mutter `edge-tiling=true` setting so dropping a window on the
  top edge maximizes it while the always-on zone layout remains enabled.
- Tradeoff: GNOME's native left/right screen-edge snapping is restored too.
- Physically verified that an ordinary drag to the top edge maximizes the
  window while the instant zone workflow remains available elsewhere.
- Set the final spacing preference to a 1 px inner gap between tiled windows
  and a 0 px outer margin at the monitor boundary. This supersedes the brief
  0 px inner/8 px outer experiment.
- Recorded the preferred drag behavior: a tiled window should retain its
  current size when dragging begins, without a visible jump to its smaller
  pre-tiling size. This was physically working while the live
  `restore-window-original-size` value remained `true`, so that verified value
  is retained rather than changing the deceptively named setting speculatively.
- The changes are per-user GSettings values and apply live; no desktop restart
  is normally needed.
- Verified the relevant values from the live dconf database and confirmed the
  extension was enabled and active on GNOME Shell 50.4.
- Rollback: reset the Tiling Shell keys documented in the detailed guide;
  resetting `active-screen-edges` re-enables Tiling Shell's edge handler.
- Detail: [gnome-configuration.md](gnome-configuration.md)

### Deferred Tiling Shell boundary-hover spanning

- Recorded the exact-match upstream enhancement request, issue #454, for
  automatically joining adjacent zones when a dragged pointer hovers near
  their shared boundary.
- The preferred first scope is aligned two-zone boundaries and clean four-way
  intersections, retaining Alt-based spanning for ambiguous layouts.
- A 50/50 two-column layout is especially useful: its center boundary would
  select both zones as a quick full-desktop placement gesture.
- Implementation and deployment notes are preserved in
  [gnome-configuration.md](gnome-configuration.md); this is intentionally
  deferred rather than patched into the installed extension today.

### GNOME ungrouped current-workspace taskbar

- Installed `gnome-shell-extension-dash-to-panel` 73-1 from Arch `extra`;
  Snapper created root snapshots 79 (pre) and 80 (post).
- Configured a bottom panel that shows running windows only from the active
  workspace and retains pinned favorite launchers.
- Application grouping is explicitly disabled: every window must have its own
  titled taskbar button. `group-apps-use-launchers=true` keeps pinned icons as
  separate launch-only entries rather than absorbing running windows.
- Added `dash-to-panel@jderose9.github.com` alongside Tiling Shell in GNOME's
  enabled-extension list. The new system extension requires one logout/login
  before the running Wayland Shell can discover and activate it.
- Rollback: disable Dash to Panel, reset its six recorded GSettings keys, and
  optionally remove its pacman package.
- Detail: [gnome-configuration.md](gnome-configuration.md)

### Manual-only suspend with five-minute monitor blanking

- Disabled GNOME automatic suspend on both AC and battery while retaining the
  native five-minute monitor idle timeout.
- Bound `Super+Shift+Z` to GNOME's native suspend action; a hardware
  `XF86Sleep` key remains supported as well.
- Disabled and stopped `custom-idle.service`; `hypridle.service` remains
  disabled. Neither implementation was deleted because the custom idle policy
  will be diagnosed and restored later.
- Preserved byte-identical copies of the custom daemon, its systemd unit, the
  earlier CPU/agent suspend gate, and the Hypridle configuration under
  [`power-management/custom-idle/`](power-management/custom-idle/README.md).
- Detail and verification: [power-idle-suspend.md](power-idle-suspend.md)

## 2026-09-09

### PlasmaZones drag highlights restored

- Diagnosed the missing drag-time zone highlights as an
  activity-specific autotile assignment overriding the desktop-level snapping
  assignment. Live drag logs reported
  `DragBypassReason::EngineOwnedScreen`.
- Cleared only the screen/desktop/activity override through
  `LayoutRegistry.clearAssignmentForScreenDesktopActivity`, revealing the
  intended desktop-level `Columns (2)` snapping assignment.
- Restored the drag trigger to PlasmaZones' always-active value
  (`modifier=8`, `mouseButton=0`) through the daemon's typed D-Bus settings
  interface. The setting applies live; no Plasma or daemon restart was needed.
- Verified the daemon is active, the effective screen state is snapping
  (`mode=0`) with `Columns (2)`, the trigger persisted to
  `~/.config/plasmazones/config.json`, and the overlay renderer changed from
  hidden to visible and back through its D-Bus API. Physical drag verification
  remains to be confirmed in the live session.
- Backup and rollback source:
  `~/.config/plasmazones.bak-highlight-restore-20260909`. Stop the service,
  copy the backup contents over `~/.config/plasmazones/`, then start the service
  again. Compare first if later PlasmaZones changes must be preserved.
- Detail: [desktop-environments.md](desktop-environments.md)

### KWin focus follows mouse without hover raise

- Set KWin's `Windows/FocusPolicy=FocusFollowsMouse`, retained
  `Windows/AutoRaise=false`, and made `Windows/ClickRaise=true` explicit in
  `~/.config/kwinrc`. Set `Windows/DelayFocusInterval=0` to remove KWin's
  default 300 ms focus debounce. Reloaded the live KWin configuration with
  `qdbus6 org.kde.KWin /KWin reconfigure`; no Plasma restart or logout was
  required.
- Disabled PlasmaZones' three narrower focus-follow-mouse settings
  (`snappingFocusFollowsMouse`, `autotileFocusFollowsMouse`, and
  `scrollingFocusFollowsMouse`) through its typed D-Bus settings API. KWin is
  therefore the single global focus authority for snapped, tiled, floating,
  and ordinary windows.
- Verified live KWin state: `focusPolicy: FocusFollowsMouse`, `autoRaise:
  false`, `clickRaise: true`, and `delayFocusInterval: 0`. Verified each
  PlasmaZones focus setting reads `false`.
- Backup: `~/.config/plasmazones.bak-ffm-20260909/kwinrc.before` and
  `config.json.before`. Rollback to the prior behavior: set KWin
  `Windows/FocusPolicy` back to `ClickToFocus`, restore
  `Windows/DelayFocusInterval` to `300` (or remove the key to use KWin's
  default), set
  `autotileFocusFollowsMouse` to `true`, then run the same KWin reconfigure
  call.
- Detail: [desktop-environments.md](desktop-environments.md)

### PlasmaZones layout-workflow lessons recorded

- Documented the distinction between a zone-layout definition, a fallback
  default, auto-assigning new windows, and the active screen/desktop/activity
  assignment. These are separate operations in PlasmaZones and should not be
  treated as FancyZones' single layout picker.
- Recorded the safe custom-layout workflow: create or duplicate in
  `Placement → Snapping → Layouts`, edit and save it, then select **Snapping**
  and the layout in **Overview** before applying. The edge selector and quick
  slots persist a context assignment; they are not preview-only controls.
- Recorded the output-loss diagnostic: the current non-EDID-emulating KVM
  intentionally disconnects HDMI-A-1 while switched away, which produces an
  empty `getScreenStates` response and KWin's `Placeholder-1` output. This is
  not evidence of lost layouts. PlasmaZones recovers when an output returns,
  but cannot draw or assign zones while KWin has no output; its
  `KeepOnResolutionChange` setting applies only to resolution changes. A
  replacement KVM with EDID emulation is
  planned to preserve display identity across switches.
- Detail: [desktop-environments.md](desktop-environments.md)

### PlasmaZones Shift-drag suppression

- Preserved the always-active drag-zone trigger (`modifier=8`, `mouseButton=0`)
  and added Shift (`modifier=1`, `mouseButton=0`) through the daemon's typed
  D-Bus settings API. With always-active enabled, the non-sentinel trigger is
  inverted: holding Shift during a title-bar drag hides the zone overlay and
  makes the drop a free, non-snap move; releasing Shift resumes normal zone
  highlighting and snapping.
- Verified the daemon's live readback and saved trigger list are exactly
  `[always-active, Shift]`. Backup:
  `~/.config/plasmazones.bak-shift-deactivate-2026-09-09T18-31-15-875Z`.
  Roll back by restoring its `files/` contents over `~/.config/plasmazones/`
  after comparing later changes, then restart `plasmazones.service`.
- Detail: [desktop-environments.md](desktop-environments.md)

### Okular as the standard PDF reader

- Installed `okular` 26.08.0-2.1 as the preferred non-Adobe PDF and general
  document reader. It is KDE-native and supports PDF annotations, forms, and
  common document formats.
- Used the required full upgrade command:
  `sudo pacman -Syu --needed --noconfirm okular`. Pacman upgraded the current
  system packages as part of the transaction and created root Snapper snapshot
  89 before it and snapshot 90 after it.
- The concise living inventory is [standard-tools.md](standard-tools.md).
- Verified with `pacman -Q okular` and `okular --version`.
- Rollback: use Snapper snapshot 89 to revert the complete package transaction.
  Removing only the reader, without reverting the accompanying system upgrade,
  is `sudo pacman -Rns okular` after reviewing the proposed removals.

### glibc debug symbols for Valgrind

- Enabled Arch's separate `[core-debug]` repository immediately before `[core]`
  in `/etc/pacman.conf`, using the existing `/etc/pacman.d/mirrorlist`.
  Preserved the prior file at `/etc/pacman.conf.bak-glibc-debug-20260909`.
- Installed `glibc-debug` 2.44+r24+g16be1518495f-1 with
  `sudo pacman -Syu --needed --noconfirm glibc-debug`. The debug-symbol package
  exactly matches installed `glibc` and supplies
  `/usr/lib/debug/usr/lib/libc.so.6.debug` for Valgrind and debuggers. It adds
  diagnostic data only; normal program execution keeps using the same
  optimized libc.
- The full package transaction created root Snapper snapshots 91 (pre) and 92
  (post). It also updated PlasmaZones from 3.4.12-1 to 3.4.15-1. Leave the
  current daemon running during active work; a logout/login is required before
  KWin loads the package's updated effect plugin.
- Verified `glibc` and `glibc-debug` have the identical version, the libc
  debug file is present, and `valgrind --version` reports 3.27.1.
- Rollback: use Snapper snapshot 91 to revert the whole transaction. To remove
  only the symbols, run `sudo pacman -Rns glibc-debug`, then restore
  `/etc/pacman.conf` from the recorded backup to disable `[core-debug]`. Keep
  the repository enabled while the package remains installed so matching symbols
  are available on later libc upgrades.

## 2026-09-10

### Go toolchain added to the standard tools

- Installed `go` 2:1.27.1-2 from `cachyos-v3` using the required full-upgrade
  command: `sudo pacman -Syu --needed --noconfirm go`.
- Pacman also applied the current 12 package upgrades. Snapper created root
  snapshot 93 before the transaction and snapshot 94 after it.
- Added Go to [standard-tools.md](standard-tools.md), the concise preferred
  tool inventory. It provides the `go` command, compiler, formatter, and
  module tooling.
- Verify with `pacman -Q go` and `go version`.
- Rollback: use Snapper snapshot 93 to revert the complete package
  transaction. To remove Go only, run `sudo pacman -Rns go` after reviewing
  Pacman's proposed removals.

### yq added to the standard tools

- Installed `yq` 4.1.2-1 from Arch `extra` with its required
  `python-tomlkit` and `python-xmltodict` dependencies, using
  `sudo pacman -Syu --needed --noconfirm yq`.
- Pacman created root Snapper snapshot 95 before the transaction and snapshot
  96 after it. Added `yq` to [standard-tools.md](standard-tools.md).
- Verify with `pacman -Q yq` and `yq --version`.
- Rollback: use Snapper snapshot 95 to revert the complete package
  transaction. To remove yq only, run `sudo pacman -Rns yq` after reviewing
  Pacman's proposed removals.

### Pacman yq removed in favor of Engineering Loadout

- Removed the Arch `yq` 4.1.2-1 package and its now-unused
  `python-tomlkit` and `python-xmltodict` dependencies with
  `sudo pacman -Rns --noconfirm yq`.
- The package's `yq` command conflicted semantically with the intended
  Engineering Loadout tool at `~/.local/bin/yq`, which is first in `PATH` and
  reports Mike Farah yq v4.53.3. Engineering Loadout is the intended source;
  do not add a Pacman `yq` entry to [standard-tools.md](standard-tools.md).
- Pacman created root Snapper snapshot 97 before removal and snapshot 98
  after it. Verify with `pacman -Q yq` (expected: not found) and
  `yq --version` (expected: Engineering Loadout's active command).
- Rollback: use Snapper snapshot 97 to revert the whole removal transaction.
  To restore only the Arch package, run `sudo pacman -Syu --needed yq`.

## 2026-09-11

### Resources GUI monitor added to the standard tools

- Installed `resources` 1.10.2-1.1 from `cachyos-extra-v3` with
  `sudo pacman -Syu --needed --noconfirm resources`. Resources is the GNOME
  Circle graphical monitor for system resources and processes; it is usable
  from the preferred Plasma session.
- Added Resources to [standard-tools.md](standard-tools.md). The full upgrade
  also applied the available 46 package updates, including both installed
  kernels and the matching NVIDIA driver stack.
- Pacman created root Snapper snapshot 99 before the transaction and snapshot
  100 after it. A reboot is required to begin running the new kernel and
  NVIDIA driver versions. Do not restart `greetd`; reboot normally when ready.
- Verify with `pacman -Q resources` and `resources --version`.
- Rollback: use Snapper snapshot 99 to revert the complete package
  transaction. To remove only Resources, run `sudo pacman -Rns resources`
  after reviewing Pacman's proposed removals.

## 2026-09-13

### Silent PrintScreen region capture

- Added `~/.local/bin/region-screenshot` and the corresponding
  `~/.local/share/applications/region-screenshot.desktop`, sourced from
  [bin/region-screenshot](bin/region-screenshot) and
  [desktop/region-screenshot.desktop](desktop/region-screenshot.desktop).
- PrintScreen now launches Spectacle's background rectangular-region selector,
  saves a timestamped PNG under `~/Pictures/Screenshots/`, and copies the
  saved image to the Wayland clipboard with `wl-copy`. No main Spectacle
  window or completion notification is shown.
- The Plasma action `region-screenshot.desktop/_launch` owns PrintScreen.
  Cleared only Spectacle's conflicting `org.kde.spectacle.desktop/_launch`
  shortcut; keyd remains unchanged and continues to manage Caps Lock only.
- Verified the wrapper's file-and-clipboard behavior with
  `tests/test-region-screenshot.sh` against controlled Spectacle and
  clipboard fixtures. Manual verification still requires pressing PrintScreen,
  completing a region selection, and pasting the image.
- Detail, repair commands, verification, and rollback:
  [screen-capture.md](screen-capture.md).

### Screen capture v2: edit-on-demand and Print/F13 bridge

- Root cause of the Spectacle GUI forcing its way up after each grab: the
  live global-shortcut daemon (embedded in `kwin_wayland` on Plasma 6.7)
  caches shortcut owners at login and rejects all remote D-Bus mutation
  calls (`setShortcut`, `setShortcutKeys`, `setForeignShortcut*`,
  `setInactive`, `unregister`). Spectacle's `Print` default therefore kept
  firing alongside the region action, and the earlier `none,none` file
  override had no live effect.
- Fix: keyd now maps physical `print = f13` in `/etc/keyd/default.conf`
  (backup `default.conf.bak-print-f13-20260913`), the desktop entry declares
  `X-KDE-Shortcuts=F13`, and `~/.config/kglobalshortcutsrc` pins
  `region-screenshot.desktop/_launch=F13` and Spectacle `_launch=none,none`
  (backup `kglobalshortcutsrc.bak-f13-20260913`). Changes take effect at the
  next relogin; until then PrintScreen may fire nothing.
- The wrapper now shows a `notify-send --wait` notification (10 s) with an
  **Edit Grab** action after each capture. Clicking it launches
  `spectacle --edit-existing <file>` for annotation; ignoring it keeps the
  flow fully silent. Under `set -e` the launch must be an `if` block, since
  a bare `[ ... ] && ...` with a false test aborts the script.
- Extended `tests/test-region-screenshot.sh` to cover both the silent path
  and the edit-action path, including that the editor opens the exact saved
  capture. Test passes; live end-to-end run verified file, clipboard, and
  timeout behavior.
- Detail, commands, verification, and rollback:
  [screen-capture.md](screen-capture.md); keyd notes in
  [keyboard-remapping.md](keyboard-remapping.md).

## 2026-09-14

### keyd crash recovery and auto-restart

- Symptom: Caps Lock tap=Escape / hold=Control silently stopped working.
  `keyd.service` had segfaulted (SEGV) at 2026-09-13 16:12 CDT — seconds
  after the `sudo keyd reload` from the F13 bridge change — while handling a
  Cooler Master MM720 mouse node, and the stock unit sets `Restart=no`, so
  the daemon stayed dead for ~18 hours.
- Fix: `sudo systemctl restart keyd` restored remapping; added
  `/etc/systemd/system/keyd.service.d/override.conf` with
  `Restart=on-failure` and `RestartSec=2s`, then `daemon-reload` and
  restart. Verified `systemctl show keyd -p Restart` reports `on-failure`.
- Standing change: prefer `sudo systemctl restart keyd` over
  `sudo keyd reload` when applying config edits; the reload path is what
  segfaulted. Always confirm `systemctl is-active keyd` afterward.
- Rollback: `sudo rm -r /etc/systemd/system/keyd.service.d` followed by
  `sudo systemctl daemon-reload` and `sudo systemctl restart keyd`.
- Details: [keyboard-remapping.md](keyboard-remapping.md).

### Installed Pinta image editor

- `sudo pacman -Syu --needed pinta` installed `pinta 3.1.2-2` (GTK4,
  dotnet-runtime-10.0) as the lightweight image editor for screenshot
  annotation. The full upgrade also refreshed core packages
  (amd-ucode, bpf, ca-certificates-mozilla, etc.); reboot recommended.
- Added to [standard-tools.md](standard-tools.md).
- Snapper rollback: pre/post snapshots 101/102.
- Rollback: `sudo pacman -Rns pinta` (Snapper rollback to snapshot 101 for
  full-system revert).

### Pinta 2fps diagnosis: 135MP plat, scripted magick flow instead

- Pinta brush lag traced to `~/Downloads/SURVEY1.png`: 10200x13200 1-bit
  (135MP). Pinta expands to ~538MB/layer; RSS hit 7.5GB idle, 3.2GB with
  just the file open. System GTK/NVIDIA fine (loupe fast). No Pinta-side
  fix; heavyweight editors unusable at this size.
- Flow settled: downsampled working copy `SURVEY1_10pct.png` (1020x1320,
  clean) for iteration, ImageMagick draws, loupe views (manual reload).
  Scale 4.7208 px/ft at 10% from 79.29' north line corners NW (264,198) /
  NE (621,297). Drawing angles follow the drawn lines, not plat bearings
  (graphic is not bearing-true).
- Current edit `SURVEY1_with_shed_10pct.png`: 14x10ft shed, long side
  parallel to north fence, 3ft inside north/east building lines, black
  1px border + hard-edged label. Full-res apply = coords x10, pending.
- `SURVEY1.png` losslessly rewritten (`-strip`, RMSE 0, backup
  `SURVEY1.png.bak-orig`); Okular still refuses it (Qt image allocation
  cap vs 538MB decode; `QT_IMAGE_ALLOCATION_LIMIT_MB=2048` workaround).
  vipsdisp not shipped in Arch libvips (CLI only).

### Plasma (Wayland) restored as default DE

- Found `initial_session` in `/etc/greetd/config.toml` pointing at
  `/usr/bin/gnome-session` (undocumented drift from the 2026-08-31 Plasma
  autologin); boot log showed that GNOME autologin session closing after ~1 s
  before falling back to the greeter.
- Restored `initial_session` to
  `/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland`
  for `mylesp`. Both binaries verified executable. TOML re-parsed after edit.
- Set noctalia fallback default in `/var/lib/noctalia-greeter/greeter.toml`
  from `Hyprland (uwsm-managed)` to `Plasma (Wayland)`. `sync.toml` `last`
  was already `Plasma (Wayland)` from the manual login, so picker and
  fallback now agree.
- Backups: `/etc/greetd/config.toml.bak-20260914-plasma-default` and
  `/var/lib/noctalia-greeter/greeter.toml.bak-20260914-plasma-default`.
- greetd not restarted (kills graphical session); takes effect at next reboot.
  `greetd` enabled, `sddm`/`gdm` remain disabled.
- Rollback: restore either backup file over its original; no package change,
  no snapper snapshot needed.

## 2026-09-16

### Native KWin drag tiling disabled; PlasmaZones sole drag handler

- Symptom: holding Shift while dragging a window showed KWin's native
  custom-tiling overlay (roughly 40/20/40 columns) instead of a free move,
  competing with PlasmaZones' Shift-to-deactivate behavior.
- Root cause: KWin 6.7.5 hardcodes Shift-drag to `QuickTileFlag::Custom`
  tiling with no config switch (verified in upstream `src/window.cpp`); the
  layouts driving it were saved in `~/.config/kwinrc` `[Tiling]` groups.
- Fix: replaced both `[Tiling]` layout arrays with explicitly empty arrays
  (no default regeneration) and set
  `[Windows] ElectricBorderTiling=false` and `ElectricBorderMaximize=false`.
  Applied live via `qdbus6 org.kde.KWin /KWin reconfigure`; verified both
  edge keys read `false` in KWin supportInformation. The empty `[Tiling]`
  change takes effect at next Plasma login (tile layouts are not reloaded
  on reconfigure). PlasmaZones triggers unchanged (`always-active` + Shift).
- Backup: `~/.config/kwinrc.bak-pz-only-20260916`. Rollback: restore it and
  relogin. KWin's tile editor can regenerate `[Tiling]` layouts; re-apply
  the empty arrays if native snapping returns.
- Detail: [desktop-environments.md](desktop-environments.md)

## 2026-09-17

### Installed packaged KLayout

- Installed `klayout 0.30.12-1.1` with
  `sudo pacman -Syu --needed --noconfirm klayout`. Snapper created root
  snapshots 111 (pre) and 112 (post).
- Verified `QT_QPA_PLATFORM=offscreen /usr/bin/klayout -v` reports
  `KLayout 0.30.12`; `pacman -Qkk klayout` reports zero altered files.
  Existing `~/.local/bin/klayout` takes precedence in PATH and reports
  `0.30.10`; it was left unchanged. Use `/usr/bin/klayout` for this install.
- The full upgrade also updated Chrome to `153.0.8010.47-1` and
  `linux-cachyos` to `7.2.5-1` with its NVIDIA module package. Running Chrome
  was not restarted; reboot recommended for the new kernel.
- `core-debug` mirror synchronization returned HTTP 404 warnings, but pacman
  continued and completed the transaction. No repository edits were made.
- Rollback: use root snapshot 111 for the full transaction. To remove only
  KLayout, run `sudo pacman -Rns klayout` after reviewing the removal list.

### Installed Qalculate! scientific calculator

- Installed the Plasma-friendly Qt frontend `qalculate-qt 5.12.0-1.1` using
  `sudo pacman -Syu --needed --noconfirm qalculate-qt`. No other packages
  changed; root Snapper snapshots are 113 (pre) and 114 (post).
- Verified `pacman -Q qalculate-qt`,
  `QT_QPA_PLATFORM=offscreen /usr/bin/qalculate-qt --version` (`5.12.0`),
  and `pacman -Qkk qalculate-qt` (zero altered files).
- Existing `core-debug` HTTP 404 warnings did not prevent installation;
  no retry or repository edit was needed. Launch with `qalculate-qt`.
- Rollback: `sudo pacman -Rns qalculate-qt` after reviewing removals,
  or restore root snapshot 113 for the transaction rollback.


## 2026-09-21

### Restored the passwordless login keyring; removed the PAM re-key vector

- Symptom: after rebooting, the first app to touch the secret service (Chrome)
  raised a gcr dialog: "The login keyring did not get unlocked when you logged
  into your computer."  The 2026-08-31 blank keyring had silently become an
  AES-encrypted one.
- Root cause: `~/.local/share/keyrings/login.keyring` was rewritten on
  2026-09-13 15:32 into gnome-keyring's AES/binary format with a real master
  password.  Autologin supplies no password, so it can never be unlocked and
  the prompt appears every boot.  Reproduced in a sandbox: feeding any password
  to `gnome-keyring-daemon --unlock` (exactly what `pam_gnome_keyring.so` does)
  sets that password as the keyring master, and the next save silently rewrites
  the file from plaintext to AES/binary (`gkm_secret_collection_save` routes on
  a non-empty master).  The `/etc/pam.d/greetd` keyring lines added on
  2026-08-31 were that vector.
- Fix, part 1: replaced the encrypted keyring with a fresh blank-password one
  (plaintext `[keyring]` format), then restarted `gnome-keyring-daemon`.
  Verified: the daemon creates Chrome's application key silently, `secret-tool`
  store/lookup round-trips with `gcr-prompter` absent, and the file stays
  plaintext.  A real Chrome launch (47 processes) produced zero prompts.
- Fix, part 2: removed the three `pam_gnome_keyring.so` lines from
  `/etc/pam.d/greetd` so no password can ever be adopted as the keyring master
  again.  The daemon still starts on demand via the enabled
  `gnome-keyring-daemon.socket` and D-Bus activation of
  `org.freedesktop.secrets`; verified by stopping the service and round-tripping
  a secret through socket activation only.
- PAM validated with a purpose-built C tester (`pamcheck`, wrong-password
  authenticate): `greetd` returned `PAM_AUTH_ERR` (7) = every module line
  parsed and ran.  The `faillock` tally the test created was reset.
- Data accepted as lost, knowingly: the discarded keyring held Chrome's
  `os_crypt` application key, which encrypted 465 locally stored logins and
  the cookie jar.  Credentials are managed in Bitwarden, so Chrome's local
  store is explicitly expendable.  Chrome re-syncs from the signed-in account;
  cookies are simply rebuilt by browsing.  Nothing else used the keyring (no
  git credential helper, no SSH keys -- `SSH_AUTH_SOCK` points at the loadout
  agent, and `gcr-ssh-agent` is disabled).
- The old encrypted keyring is kept as
  `~/.local/share/keyrings/login.keyring.bak-20260921-165642`
  (sha256 `47a2c24288b02f04b17979e275adc755f3143cc499addda89cd9a0584271c9e6`).
  It is still recoverable offline with its password using the format reader at
  `~/.hermes/cache/scratch/probe_keyring.py` (validated against upstream
  gnome-keyring test fixtures).  The name does not match the daemon's
  `*.keyring` watch pattern, so it is inert.
- Verification: `tests/check-keyring-state.sh` (new) checks the plaintext
  format, permissions, absence of live PAM keyring directives, a secret
  round-trip, and that no prompter appears.  All checks pass.
- Rollback: restore the PAM file from
  `/etc/pam.d/greetd.bak-20260921-keyring-guard` and, if desired, the old
  keyring from the `.bak-20260921-165642` file.  Restoring the PAM lines alone
  reintroduces the re-key hazard on the next password login.
- Detail: [passwordless-login.md](passwordless-login.md)

### Update-resilience audit of the PAM re-key vector

- Question raised: could system updates reanimate `pam_gnome_keyring` in a PAM
  stack? Audited the cached packages, the pacman database, and the update
  scriptlets.
- `/etc/pam.d/greetd` is a tracked backup file of `greetd`, so pacman 7.1
  would 3-way merge it. The pristine file in every cached version contains
  **no** keyring lines, so a merge cannot restore them.
- `noctalia-greeter`'s post-upgrade scriptlet rewrites `/etc/pam.d/greetd` but
  only inserts `session required pam_systemd.so`, idempotently. No cached
  version adds keyring lines, so updates do not reintroduce the vector.
- `pambase`, `shadow`, and the password-carrying stacks (`system-auth`,
  `system-local-login`, `login`, `su`, `sudo`, `passwd`, `chpasswd`) ship no
  keyring lines. `sddm*`/`gdm*` do, and are disabled; enabling either would
  re-arm the hazard.
- Hardened `tests/check-keyring-state.sh`: now covers every stack that can
  carry a password, detects a stray `*.keyring` file the daemon would load,
  reports unmerged `*.pacnew` PAM artifacts, flags an enabled `sddm`/`gdm`, and
  gained `--static` / `--quiet` modes plus `KEYRING_FILE` / `PAM_DIR` /
  `SYSTEMCTL` overrides for hermetic testing.
- Added `tests/test-check-keyring-state.sh`: proves the checker fails on a
  re-keyed keyring, a re-added PAM line, a stray keyring file, and bad
  permissions, and does not false-positive on comments. All five negative tests
  pass; the earlier version of the checker had never been shown to fail.
- Prepared `/etc/pacman.d/hooks/95-keyring-pam-guard.hook` (staged at
  `~/.hermes/cache/scratch/95-keyring-pam-guard.hook`; **awaiting install
  consent**) to run the check after any `greetd`, `noctalia-greeter`,
  `gnome-keyring`, `pambase`, `sddm`, or `gdm` transaction. Read-only, silent on
  success, full report on stderr on failure, no `AbortOnFail` so a completed
  transaction is never marked failed.
- Rollback: `sudo rm /etc/pacman.d/hooks/95-keyring-pam-guard.hook`; the test
  scripts are additive and can be deleted.
- Detail: [passwordless-login.md](passwordless-login.md)

## 2026-09-22

### Shared tmux server killed by an agent probe (diagnosis + guard rule)

- Incident: the default tmux server (`/tmp/tmux-1000/default`, 6 windows,
  started by WezTerm at 15:29:54 on 2026-09-21) died at 23:51:20. The client
  showed "server exited unexpectedly"; a fresh server with a
  continuum-restored layout came up at 00:53. Last resurrect save: 23:30:15
  (`last` symlink); the 00:30 save never ran.
- Root cause: a Hermes maintenance session (btop install test) ran
  `tmux kill-server` on the default socket as an "isolated" probe. Three
  running agent sessions ended `cli_close` within three seconds with
  `process_loop EIO` / "Terminal I/O broken". Every pane process was lost;
  recovery was layout-only via tmux-continuum.
- Ruled out: OOM (systemd-oomd inactive, no kernel kills), suspend (last
  cycle 00:04:43, clean), systemd teardown (no unit events). No tmux user
  unit exists; the persistent-tmux design
  (`docs/superpowers/specs/2026-09-04-persistent-tmux-design.md`) remains
  unimplemented, so the server still lives in WezTerm's cgroup.
- Change: added a "never kill the shared tmux server" rule to the global
  agent instruction files — `~/.hermes/SOUL.md`, `~/.claude/CLAUDE.md`,
  `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md` — and recorded the
  shared-socket hazard in `candelise/operating-practice.md`.
- Enforcement (mechanical, added after the instruction rule): deny rules that
  fire before the yolo/`mode=off` bypass, in each CLI's own config —
  - Hermes: `approvals.deny` = `tmux kill-server*`, `tmux *kill-server*`,
    `pkill *tmux*`, `killall *tmux*` (fnmatch globs, case-insensitive, run over
    deobfuscated command variants; verified with `hermes approvals test`).
  - Claude Code: `permissions.deny` in `~/.claude/settings.json` with the same
    four `Bash(...)` rules.
  - OpenCode: `permission.bash` in `~/.config/opencode/opencode.jsonc` with the
    same four `deny` entries.
  - Codex CLI: no user-editable command denylist in codex-cli 0.154.0
    (`codex --help` exposes only `--ask-for-approval` / sandbox policies);
    covered by the instruction rule in `~/.codex/AGENTS.md` only.
- Verified: `tests/check-tmux-guard.sh` — 20/20 pass (4 instruction files,
  4 Hermes globs, 4 Claude rules, 4 OpenCode rules, 6 denied + 4 allowed
  runtime verdicts). `tests/tmux-deny-check.sh` battery: 14/14 deny cases
  blocked, 8/8 innocent commands unaffected. Both read-only.
- Known limitation: the floor matches command text including heredoc bodies, so
  a shell script whose lines contain the literal string `tmux kill-server`
  triggers the block even when it only tests the rule. Verifiers therefore
  read test commands from a file instead of a heredoc.
- Deliberate over-block, reviewed and kept (2026-09-22): `tmux *kill-server*`
  also blocks `tmux -L <scratch> kill-server`. Kept because scratch servers
  exit when their last session ends (verified live), so `kill-session` — still
  allowed — is a complete substitute; nothing on this machine tears down a
  scratch socket with `kill-server` (repo-wide search + shell history); and a
  socket-scoped rule set cannot be made safe: `-f` does NOT change the socket
  (`env -u TMUX tmux -f /dev/null ls` lists the shared server) and `--`/`-c`/
  `-u` may also precede the subcommand, so a bare-only or `-L default`-only
  rule set leaves a live hole. Cost if it ever bites: one loud block with an
  allowed alternative; cost of under-block: the 2026-09-21 incident.
- Rollback: `hermes config unset approvals.deny`; remove the `permissions`
  block from `~/.claude/settings.json`; restore `"permission": "allow"` in
  `~/.config/opencode/opencode.jsonc`. Backups:
  `~/.hermes/cache/scratch/tmux-guard-backups-20260922-015907/`.
- Verification: `tests/check-tmux-guard.sh` (see Enforcement above).
- Rollback: delete the `## tmux: never kill the shared server` section from
  each file.
