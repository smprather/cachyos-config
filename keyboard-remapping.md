# Keyboard Remapping

This machine uses `keyd` for keyboard remapping that should apply across
Plasma, GNOME, Hyprland, terminals, and Wayland applications.

## Desired state

- Caps Lock tapped alone sends Escape.
- Caps Lock held with another key acts as Control.
- Desktop-specific Caps Lock remaps are disabled so `keyd` is the single source
  of truth.
- The existing Right Meta macro is preserved.

## keyd configuration

The active config is `/etc/keyd/default.conf`:

```ini
[ids]
*

[main]
rightmeta = macro(C-backslash z)
capslock = overload(control, esc)
print = f13
```

`overload(control, esc)` is keyd's standard tap/hold form: the key activates
the `control` modifier layer when used with another key, and emits `esc` when
tapped alone.

`print = f13` is the PrintScreen bridge for the silent screen-capture flow:
physical PrintScreen reaches Plasma as F13, which the
`region-screenshot.desktop` action binds. This routes around Spectacle's
hard-wired `Print` default in the global-shortcut daemon. See
`screen-capture.md` before changing or removing it.

`keyd` is installed, enabled, and active:

```bash
command -v keyd
pacman -Q keyd
systemctl is-enabled keyd
systemctl is-active keyd
```

## Crash self-healing

keyd 2.6.0-5.1 segfaulted during a `sudo keyd reload` on 2026-09-13 while
grabbing a Cooler Master MM720 mouse node, and the stock unit has
`Restart=no`, so the daemon stayed dead for ~18 hours with no visible error:
remaps silently stopped working. `/etc/systemd/system/keyd.service.d/override.conf`
now sets:

```ini
[Service]
Restart=on-failure
RestartSec=2s
```

Verify with `systemctl show keyd -p Restart` (expect `on-failure`). If keyd
dies again on reload, restart it outright (`sudo systemctl restart keyd`)
instead of reloading, and consider reporting the segfault upstream.

## Apply or repair

After editing `/etc/keyd/default.conf`, validate and reload:

```bash
sudo keyd check
sudo systemctl restart keyd
```

Prefer `systemctl restart` over `keyd reload`: the reload path is what
triggered the 2026-09-13 segfault. After either command, confirm the service
is actually alive with `systemctl is-active keyd`; a failed reload does not
necessarily leave the old config running.

Do not add another Caps Lock mapping in Plasma, GNOME, or Hyprland. If a desktop
setting also remaps Caps Lock, remove that desktop setting and keep the keyd
mapping.

## Removed DE-specific mappings

The previous GNOME mapping was:

```bash
gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"
```

It has been cleared with:

```bash
gsettings set org.gnome.desktop.input-sources xkb-options "[]"
```

The previous Hyprland mapping lived in
`~/.config/hypr/config/inputs.lua`:

```lua
kb_options = "ctrl:nocaps",
```

That line has been removed. The repeat-rate, repeat-delay, mouse, and cursor
settings in the same file are unrelated and should be preserved.

No active Plasma-specific Caps Lock remap was found in the searched KDE config
paths when this change was made.

## Verification

Config-level verification:

```bash
sudo keyd check
gsettings get org.gnome.desktop.input-sources xkb-options
rg -n 'ctrl:nocaps|capslock' ~/.config/hypr/config /etc/keyd
```

Expected results:

- `sudo keyd check` reports no errors.
- GNOME `xkb-options` is empty; `gsettings` prints this as `@as []`.
- `/etc/keyd/default.conf` contains `capslock = overload(control, esc)`.
- `/etc/keyd/default.conf` contains `print = f13` (screen-capture bridge).
- `~/.config/hypr/config/inputs.lua` does not contain `ctrl:nocaps`.

Behavior-level verification should be done in a text field or terminal:

- Tap Caps Lock: Escape behavior, such as cancelling a prompt or leaving insert
  mode in Vim.
- Hold Caps Lock and press another key: Control chord behavior, such as
  Caps+L clearing a terminal screen.

## Rollback

The 2026-09-07 change created these backups:

- `/etc/keyd/default.conf.bak-20260907-114443`
- `~/.config/hypr/config/inputs.lua.bak-20260907-114443`

The 2026-09-13 PrintScreen bridge additionally created:

- `/etc/keyd/default.conf.bak-print-f13-20260913`

To restore the prior keyd config:

```bash
sudo cp /etc/keyd/default.conf.bak-20260907-114443 /etc/keyd/default.conf
sudo keyd check
sudo keyd reload
```

Restoring the 09-07 backup also removes the `print = f13` bridge; see
`screen-capture.md` for the full capture-flow rollback.

To restore the prior Hyprland Caps Lock mapping:

```bash
cp ~/.config/hypr/config/inputs.lua.bak-20260907-114443 ~/.config/hypr/config/inputs.lua
```

To restore the old GNOME-only Caps Lock-to-Control mapping:

```bash
gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"
```
