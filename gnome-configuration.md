# GNOME configuration

This guide records GNOME settings and compatibility work that are not exposed
well by the standard Settings application. It is intended to be usable during
an agent-assisted rebuild of this machine.

## Keyboard repeat

### Desired state

- Key repeat enabled
- Initial delay: 200 ms
- Repeat interval: 33 ms, approximately 30.3 repeats per second

GNOME stores the repeat period as an interval in milliseconds, not as a rate:

```text
interval_ms = round(1000 / repeats_per_second)
```

The 33 ms interval closely matches the Hyprland configuration's
`repeat_rate = 30`; `repeat_delay = 200` matches exactly.

### Apply

Run these commands in the target user's graphical session:

```bash
gsettings set org.gnome.desktop.peripherals.keyboard repeat true
gsettings set org.gnome.desktop.peripherals.keyboard delay 200
gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 33
```

These are per-user GSettings values backed by dconf. They apply immediately in
the running GNOME Wayland session; `xset` is neither persistent nor the right
interface for native Wayland.

If a shared runtime prefix is active and a system command behaves strangely,
run it with the prefix overrides removed:

```bash
env -u GI_TYPELIB_PATH -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH \
  /usr/bin/gsettings set org.gnome.desktop.peripherals.keyboard delay 200
```

### Verify

```bash
gsettings get org.gnome.desktop.peripherals.keyboard repeat
gsettings get org.gnome.desktop.peripherals.keyboard delay
gsettings get org.gnome.desktop.peripherals.keyboard repeat-interval
```

Expected output:

```text
true
uint32 200
uint32 33
```

### Roll back to schema defaults

```bash
gsettings reset org.gnome.desktop.peripherals.keyboard repeat
gsettings reset org.gnome.desktop.peripherals.keyboard delay
gsettings reset org.gnome.desktop.peripherals.keyboard repeat-interval
```

For interactive exploration, `dconf-editor` exposes these keys at
`/org/gnome/desktop/peripherals/keyboard/`. Prefer `gsettings` for recorded,
repeatable changes.

## Caps Lock

Caps Lock is not managed through GNOME on this machine anymore. The old
`org.gnome.desktop.input-sources xkb-options` value `['ctrl:nocaps']` was
cleared on 2026-09-07 because Caps Lock is now handled globally by keyd:
tap Caps Lock for Escape, hold Caps Lock for Control.

See [keyboard-remapping.md](keyboard-remapping.md) for the active config,
verification, and rollback.

## FancyZones-style drag tiling

### Desired state

Use the Tiling Shell extension as the GNOME equivalent of Microsoft PowerToys
FancyZones:

- Show the selected layout as soon as a window is dragged, without first
  moving the pointer to the top of the screen or holding an activation key.
- Update the highlighted tile immediately as the pointer crosses zones.
- Preserve GNOME's native top-edge drop gesture to maximize a window.
- Hold Ctrl while dragging to bypass the tiling overlay for that drag.
- Keep Alt as the modifier for spanning multiple adjacent tiles.
- Disable Tiling Shell's separate top-edge Snap Assistant.
- Disable Tiling Shell's replacement screen-edge handler so Mutter provides
  the native maximize gesture.
- Use a 1 px inner gap between adjacent tiled windows and no outer margin at
  the monitor boundary.
- Keep the window at its current tiled size when a drag begins rather than
  visibly switching to a smaller pre-tiling size.
- Remove the tile-preview animation delay.

The tested installation is Tiling Shell 17.3, extension UUID
`tilingshell@ferrarodomenico.com`, on GNOME Shell 50. Install a version
compatible with the current GNOME Shell from the
[official extension page](https://extensions.gnome.org/extension/7065/tiling-shell/),
then enable it:

```bash
gnome-extensions enable tilingshell@ferrarodomenico.com
```

Do not enable another window-grab or tiling extension at the same time unless
their interaction has been tested.

### Apply

Run these commands in the target user's graphical session after installing
Tiling Shell:

```bash
tiling_schema_dir="$HOME/.local/share/gnome-shell/extensions/tilingshell@ferrarodomenico.com/schemas"
tiling_schema="org.gnome.shell.extensions.tilingshell"

gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  tiling-system-activation-key "['-1']"
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  tiling-system-deactivation-key "['0']"
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  enable-snap-assist false
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  tile-preview-animation-time 0
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  active-screen-edges false
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" inner-gaps 1
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" outer-gaps 0
gsettings --schemadir "$tiling_schema_dir" set "$tiling_schema" \
  restore-window-original-size true
```

In Tiling Shell's internal key encoding, `-1` means no modifier and `0` means
Ctrl. The unset defaults are Ctrl for activation and no deactivation key, so
leaving these keys at `@as []` does not produce the desired behavior.

These settings apply live. A GNOME restart or logout is not normally required.

`active-screen-edges=false` is deliberate. When Tiling Shell's replacement
edge handler is enabled, the extension overrides `org.gnome.mutter
edge-tiling` to `false`. Disabling that handler restores the saved native value
(`true` on this installation). Mutter then maximizes a window dropped on the
top screen edge while Tiling Shell's separate always-on layout remains enabled.
Native left/right edge snapping also returns; this is the tradeoff for retaining
the top-edge maximize gesture without patching the extension.

Do not enable Tiling Shell's `top-edge-maximize` setting for this configuration.
In version 17.3, its replacement edge path only runs when the always-on layout
is inactive, which would require holding the Ctrl bypass key while dragging.

The preferred drag behavior was physically verified while
`restore-window-original-size=true` was live: grabbing a tiled window kept its
current size instead of visibly jumping to a smaller pre-tiling size. Despite
the setting's name, do not change it to `false` during a rebuild unless the
undesired size jump is actually reproduced. The key controls Tiling Shell's
stored original-size restoration path, and that path is not necessarily used
for every tiled or snapped window.

### Verify

```bash
tiling_schema_dir="$HOME/.local/share/gnome-shell/extensions/tilingshell@ferrarodomenico.com/schemas"
tiling_schema="org.gnome.shell.extensions.tilingshell"

gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  tiling-system-activation-key
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  tiling-system-deactivation-key
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  enable-snap-assist
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  tile-preview-animation-time
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  active-screen-edges
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" inner-gaps
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" outer-gaps
gsettings --schemadir "$tiling_schema_dir" get "$tiling_schema" \
  restore-window-original-size
gsettings get org.gnome.mutter edge-tiling
gnome-extensions info tilingshell@ferrarodomenico.com
```

Expected setting values are:

```text
['-1']
['0']
false
uint32 0
false
uint32 1
uint32 0
true
true
```

The extension should report `Enabled: Yes` and `State: ACTIVE`. Drag a normal,
unmaximized window: the zones should appear immediately, track the pointer,
and tile the window on release. Dropping it on the top screen edge maximizes
it. Holding Ctrl suppresses the zones. This combined behavior was verified
end-to-end in the GNOME Wayland session on 2026-09-04.

If the values are correct but the extension does not respond, toggle only the
extension before considering a full logout:

```bash
gnome-extensions disable tilingshell@ferrarodomenico.com
gnome-extensions enable tilingshell@ferrarodomenico.com
```

GNOME Wayland does not support the Xorg-era `Alt+F2`, `r` Shell restart. Log
out and back in only if toggling the extension fails to reload it.

### Roll back

```bash
tiling_schema_dir="$HOME/.local/share/gnome-shell/extensions/tilingshell@ferrarodomenico.com/schemas"
tiling_schema="org.gnome.shell.extensions.tilingshell"

gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  tiling-system-activation-key
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  tiling-system-deactivation-key
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  enable-snap-assist
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  tile-preview-animation-time
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  active-screen-edges
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" inner-gaps
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" outer-gaps
gsettings --schemadir "$tiling_schema_dir" reset "$tiling_schema" \
  restore-window-original-size
```

Resetting `active-screen-edges` returns it to Tiling Shell's `true` default;
the running extension will again disable Mutter's native edge tiling and use
its own edge handler.

### Deferred enhancement: boundary-hover spanning

Track [Tiling Shell issue #454, Automatic Multi-Tile Selection on Border
Hover](https://github.com/domferr/tilingshell/issues/454). It was still open,
unassigned, and without a milestone or linked pull request when checked on
2026-09-04.

Desired FancyZones behavior:

- While dragging, hovering near a clean boundary between two adjacent zones
  dynamically highlights and selects their union without another modifier.
- Hovering near a clean four-zone intersection selects all four zones.
- With the frequently used 50/50 two-column layout, hovering near the center
  boundary spans both zones and becomes a quick full-desktop placement gesture.
- Keep Alt-based manual spanning as the fallback for irregular or ambiguous
  layouts.

Recommended first implementation scope: aligned two-zone boundaries and clean
four-way intersections, with a small pixel threshold and hover hysteresis to
avoid flicker. Tiling Shell already implements rectangle union, multi-tile
preview highlighting, and final placement, so the missing core is boundary
intent detection. A rough estimate was 4/10 difficulty for that useful subset
and 7/10 for a polished implementation covering partial boundaries, scaling,
gaps, multiple monitors, preferences, and upstream-quality tests.

Do not patch only the compiled extension under `~/.local`; extension upgrades
would overwrite it. Resume this work from the upstream source, retain a small
fork or patch plus build/install instructions in this repository, and aim to
submit the result against issue #454.

## Windows-style ungrouped taskbar

### Desired state

Use Dash to Panel for a Windows-style bottom taskbar with:

- One independent, titled taskbar button for every open window. Application
  grouping is explicitly unwanted.
- Running-window buttons limited to the active workspace.
- Pinned favorite applications retained as separate launch-only icons; a
  running window must not be absorbed into its pinned icon.
- Window previews on hover and the extension's normal activate/minimize click
  behavior.
- Tiling Shell left enabled alongside it.

Dash to Panel version 73 from the Arch `extra` repository was selected because
its metadata declares GNOME Shell 46 through 50 compatibility. Install it with:

```bash
sudo pacman -S --needed gnome-shell-extension-dash-to-panel
```

This is preferable to an AUR build or manually downloaded zip because the
extension remains owned and updated by pacman.

### Apply

The schema is installed globally, so these values can be written immediately
after package installation:

```bash
taskbar_schema="org.gnome.shell.extensions.dash-to-panel"

gsettings set "$taskbar_schema" show-running-apps true
gsettings set "$taskbar_schema" show-favorites true
gsettings set "$taskbar_schema" isolate-workspaces true
gsettings set "$taskbar_schema" group-apps false
gsettings set "$taskbar_schema" group-apps-use-launchers true
gsettings set "$taskbar_schema" panel-position 'BOTTOM'
```

The two grouping values are both intentional. `group-apps=false` creates one
button per window; `group-apps-use-launchers=true` keeps pinned favorites as
launchers separate from those running-window buttons.

If Dash to Panel was installed after the current GNOME Wayland session began,
`gnome-extensions` will not discover it until the next login. Log out and back
in, then enable it if it did not load automatically:

```bash
gnome-extensions enable dash-to-panel@jderose9.github.com
```

During the 2026-09-04 installation, the extension UUID was safely appended to
the existing `org.gnome.shell enabled-extensions` list after verifying that the
list contained only Tiling Shell. Do not replace this array blindly on another
installation; preserve every existing UUID.

### Verify

After logging back into GNOME:

```bash
pacman -Q gnome-shell-extension-dash-to-panel
gnome-extensions info dash-to-panel@jderose9.github.com

taskbar_schema="org.gnome.shell.extensions.dash-to-panel"
gsettings get "$taskbar_schema" show-running-apps
gsettings get "$taskbar_schema" show-favorites
gsettings get "$taskbar_schema" isolate-workspaces
gsettings get "$taskbar_schema" group-apps
gsettings get "$taskbar_schema" group-apps-use-launchers
gsettings get "$taskbar_schema" panel-position
```

Expected package version and settings for the tested installation:

```text
gnome-shell-extension-dash-to-panel 73-1
true
true
true
false
true
'BOTTOM'
```

The extension should report `Enabled: Yes` and `State: ACTIVE`. Open two
windows from the same application and confirm that each receives its own
titled taskbar button. Move one to another workspace and confirm that its
button disappears from the active workspace while pinned launchers remain.

### Roll back

```bash
gnome-extensions disable dash-to-panel@jderose9.github.com

taskbar_schema="org.gnome.shell.extensions.dash-to-panel"
gsettings reset "$taskbar_schema" show-running-apps
gsettings reset "$taskbar_schema" show-favorites
gsettings reset "$taskbar_schema" isolate-workspaces
gsettings reset "$taskbar_schema" group-apps
gsettings reset "$taskbar_schema" group-apps-use-launchers
gsettings reset "$taskbar_schema" panel-position
```

Optionally remove the package with
`sudo pacman -R gnome-shell-extension-dash-to-panel`, then log out and back in.
The installation created Snapper root snapshots 79 (pre) and 80 (post).

## GNOME Tweaks

### Installation policy

Install GNOME Tweaks as the CachyOS/Arch package. Shelly is only a frontend to
the standard package backends in this case; the installed files are owned by
the `gnome-tweaks` pacman package.

Do not use `pipx` or `uv tool install` for GNOME Tweaks. Although its launcher
is Python, it is a Meson-built desktop application coupled to the system's GTK,
libadwaita, Pango, GObject Introspection typelibs, GSettings schemas, icons,
desktop entry, and D-Bus service. A Python virtual environment would isolate
only one part of that runtime.

Use `uv tool install` for ordinary Python packages that publish command-line
entry points. Each tool then receives its own environment under uv's tool
directory. For uv-managed Python interpreters, prefer the versioned executable
installed by `uv python install`; do not install generic `python` or `python3`
shims into a globally preferred directory unless replacing the operating
system interpreter is intentional.

References:

- <https://docs.astral.sh/uv/concepts/tools/>
- <https://docs.astral.sh/uv/guides/install-python/>

### Failure diagnosis from 2026-09-03

The pacman package itself was intact, but the shared `~/.local` runtime
shadowed two of its system dependencies.

1. `/usr/bin/gnome-tweaks` used `#!/usr/bin/env python3`.
2. `PATH` selected `~/.local/bin/python3` instead of `/usr/bin/python3`.
3. That interpreter could not import the pacman-owned `gi` module and failed
   with `ModuleNotFoundError: No module named 'gi'`.
4. Running the launcher with `/usr/bin/python3` reached a second failure:
   `Pango.attr_fallback_new` was missing.
5. `Pango.__path__` showed that the system interpreter was still loading
   `~/.local/lib/girepository-1.0/Pango-1.0.typelib`, selected by the globally
   exported `GI_TYPELIB_PATH`. That older typelib shadowed the matching CachyOS
   typelib at `/usr/lib/girepository-1.0/Pango-1.0.typelib`.
6. Clearing the shared-prefix variables and using the system `PATH` made GNOME
   Tweaks run normally.

The broad architectural lesson is to scope private native-library and GI
search paths to the applications that require them. Exporting them globally
can make an otherwise system-owned application load an incompatible mixture of
private and distro libraries.

### Installed workaround

[`bin/gnome-tweaks`](bin/gnome-tweaks) clears the shared Python, GI, and
dynamic-library overrides, pins `PATH` to the system directories, and executes
the pacman-owned launcher by absolute path.

From the repository root, install the user-level command shim with:

```bash
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd -P)/bin/gnome-tweaks" "$HOME/.local/bin/gnome-tweaks"
```

The link intentionally fails rather than overwriting an existing file. Inspect
and resolve an existing target before retrying. Open a new shell, or run
`rehash` in zsh or `hash -r` in bash, after adding the link.

### Verify the workaround

```bash
command -v gnome-tweaks
readlink -f "$(command -v gnome-tweaks)"
timeout 5s gnome-tweaks
```

The first command should select `~/.local/bin/gnome-tweaks`, the resolved link
should point to this repository's launcher, and `timeout` should exit with 124
after the application remains healthy for five seconds. GTK or libadwaita
warnings may still be printed; there should be no Python traceback,
`ModuleNotFoundError`, or missing Pango attribute error.

The packaged desktop entry is D-Bus activatable and its service executes
`/usr/bin/gnome-tweaks` directly. At diagnosis time the systemd user-service
environment had the clean system `PATH` and no `GI_TYPELIB_PATH`, so desktop
activation did not require an override. The user launcher specifically
protects interactive shell launches from the shared prefix.

### Roll back the workaround

```bash
unlink "$HOME/.local/bin/gnome-tweaks"
```

The source launcher can then be removed from this repository. If the generic
Python shim and global private typelib export are later eliminated, retest the
system launcher; the workaround may no longer be necessary.
