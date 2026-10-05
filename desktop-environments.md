# Desktop Environments

This machine runs four desktop environments side by side behind a single login
manager. This file records how that state came about, what was wrong with it,
and what was changed on 2026-08-31.

## Starting state

The installation began as the CachyOS Hyprland edition. Other desktops were
layered on top afterwards, which is why the package set did not match a stock
CachyOS or stock Arch KDE installation.

Observed session environment:

```text
XDG_CURRENT_DESKTOP=KDE
XDG_SESSION_TYPE=wayland
DESKTOP_SESSION=
WAYLAND_DISPLAY=wayland-0
DISPLAY=:0
```

Versions: `plasmashell 6.7.4`, `kwin 6.7.4`.

## Problem: Plasma installed piecemeal

Plasma started and `kwin` ran, so the session appeared to work, but no Plasma
metapackage had ever been installed. `pacman -Qq` confirmed that
`plasma`, `plasma-meta`, `kde-applications-meta`, and `plasma-desktop` were all
absent, while individual pieces such as `kwin`, `plasma-workspace`, and `breeze`
were present.

Comparing against the `plasma` group showed roughly 40 missing packages. The
functionally significant ones:

| Package | What was missing without it |
|---|---|
| `plasma-desktop` | desktop shell configuration, most KCMs, keyboard and mouse settings |
| `systemsettings` | the System Settings application entirely |
| `plasma-pa` | audio applet and volume tray |
| `plasma-nm` | network applet |
| `powerdevil` | power management, brightness, sleep |
| `kscreen` | monitor layout and resolution configuration |
| `polkit-kde-agent` | authentication dialogs; privileged GUI actions failed silently |
| `kde-gtk-config`, `breeze-gtk` | GTK application theming |
| `bluedevil` | Bluetooth |
| `kinfocenter`, `spectacle`, `drkonqi`, `discover`, `print-manager` | system info, screenshots, crash handling, software centre, printing |

KDE applications (`konsole`, `kate`, `gwenview`, `okular`) were also absent.

## Fix

`plasma-meta` was installed, which pulled in 90 packages:

```bash
sudo pacman -Syu --needed --noconfirm plasma-meta
```

A full `-Syu` was used rather than a bare `-S` because Arch and CachyOS do not
support partial upgrades. Ten updates were pending at the time, including
`noctalia-greeter` 1.2.1 to 1.3.0, which is the greeter this machine uses.

The transaction created snapper snapshot `root: 60`, which is the rollback point
for the package change.

Note: a concurrent `sudo pacman -S --needed gnome` started by the user held
`/var/lib/pacman/db.lck` during the first attempt. The install failed cleanly
with `unable to lock database` and changed nothing. Waiting for the other
transaction to finish was the correct response; never remove `db.lck` while a
package manager is actually running.

After the install, all previously missing core components verified present:
`plasma-desktop`, `systemsettings`, `plasma-pa`, `plasma-nm`, `powerdevil`,
`kscreen`, `polkit-kde-agent`, `kde-gtk-config`, `breeze-gtk`, `bluedevil`,
`spectacle`.

## Login manager

The display manager is **greetd** with the noctalia greeter, not SDDM or GDM.

```text
greetd    enabled
sddm      disabled
gdm       disabled
```

Both `sddm` and `gdm` are installed but deliberately disabled. Do not enable
them. greetd already launches every session correctly.

Available sessions in `/usr/share/wayland-sessions/`:

```text
gnome.desktop
hyprland.desktop
hyprland-uwsm.desktop
plasma.desktop
```

`/usr/share/xsessions/` is empty; there are no X11 sessions.

**Do not restart `greetd` to test a change.** Restarting it kills the running
graphical session. Reboot instead.

## Portal backends

Five xdg-desktop-portal backends are installed:

```text
xdg-desktop-portal
xdg-desktop-portal-cosmic
xdg-desktop-portal-gnome
xdg-desktop-portal-gtk
xdg-desktop-portal-hyprland
xdg-desktop-portal-kde
```

This is **not** a conflict. Each desktop ships its own
`/usr/share/xdg-desktop-portal/*-portals.conf`, selected by
`XDG_CURRENT_DESKTOP`. A KDE session resolves to `kde`, a GNOME session to
`gnome`, a Hyprland session to `hyprland`. No manual arbitration is needed.

`xdg-desktop-portal-cosmic` is a leftover; it is harmless unless a COSMIC
session is also wanted.

## PlasmaZones only in Plasma

`plasmazones.service` is a KDE/Plasma window placement daemon. It is installed
as a user service with:

```ini
[Install]
WantedBy=plasma-workspace.target
```

That means it should start on a normal Plasma login while the service remains
enabled.

Do not run it in GNOME. On 2026-09-06, `plasmazonesd` started during a GNOME
Wayland session and created a full-screen `PlasmaZones` XWayland window above
WezTerm:

```text
"PlasmaZones" 3440x1440+0+0
"tmux" / org.wezfurlong.wezterm below it
```

That overlay intercepted mouse input, so WezTerm could still receive keyboard
input but mouse actions stopped working: text selection, tmux pane selection,
window movement, and the window close button were all blocked.

The live workaround was:

```bash
systemctl --user stop plasmazones.service
```

The durable per-user guard is:

```ini
# ~/.config/systemd/user/plasmazones.service.d/override.conf
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE
```

This keeps the service enabled for Plasma but makes systemd skip it in GNOME.
Verified in the GNOME session with:

```bash
systemctl --user start plasmazones.service
systemctl --user status plasmazones.service
```

The status showed:

```text
PlasmaZones Window Placement Daemon skipped, unmet condition check ConditionEnvironment=XDG_CURRENT_DESKTOP=KDE
```

If the service does not start after a Plasma login, first check what the user
systemd manager imported from the session:

```bash
systemctl --user show-environment | rg XDG_CURRENT_DESKTOP
systemctl --user status plasmazones.service
```

### Drag highlights and placement mode

Verified 2026-09-09 with PlasmaZones 3.4.12. On the Dell ultrawide, virtual
desktop 1 should use snapping mode (`mode=0`) with the `Columns (2)` layout.
Its drag activation triggers should contain `modifier=8`, PlasmaZones'
always-active sentinel, so an ordinary title-bar drag displays the zones
without a keyboard modifier; and `modifier=1` (Shift). With the always-active
sentinel present, Shift is inverted into **hold to deactivate**: holding Shift
during a drag hides the overlay and makes that drop a free, non-snap move.

The highlights disappeared when a higher-priority activity-specific assignment
switched the screen to autotile mode (`mode=1`). The live drag log identified
the resulting bypass as `DragBypassReason::EngineOwnedScreen`. The persisted
trigger had also reverted to the default Alt trigger (`modifier=3`). Restore the
intended state through the daemon-owned D-Bus APIs:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.LayoutRegistry.clearAssignmentForScreenDesktopActivity \
  'Dell Inc.:DELL S3425DW:825314902' 1 \
  '5cfe7a10-0452-4301-aa9a-a879f550e64a'

gdbus call --session --dest org.plasmazones \
  --object-path /PlasmaZones \
  --method org.plasmazones.Settings.setSetting \
  dragActivationTriggers \
  "<[<{'modifier': <8>, 'mouseButton': <0>}>, <{'modifier': <1>, 'mouseButton': <0>}>]>"
```

The nested variant syntax in the second command is significant. A plain JSON
string, or an `aa{sv}` value such as `<[{'modifier': <8>, ...}]>`, can return
success while PlasmaZones 3.4.12 converts it to an empty trigger list. The
working value is an `av` whose item is a variant containing the map, hence the
extra inner angle brackets.

Verify the effective state and the overlay renderer with:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Settings.getSetting dragActivationTriggers
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.LayoutRegistry.getScreenStates
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Rules.getAllRules
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Overlay.showOverlay
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Overlay.isOverlayVisible
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Overlay.hideOverlay
```

The pre-change configuration is preserved at
`~/.config/plasmazones.bak-highlight-restore-20260909`. To roll back the whole
change, stop `plasmazones.service`, copy that directory's contents over
`~/.config/plasmazones/`, and start the service again. Do not restore this
backup selectively after later PlasmaZones work without first comparing the
files, because it also contains the prior layout, rules, gaps, and session
state.

### Layout library versus active assignment

PlasmaZones is not a single-layout system like FancyZones. A layout definition
is separate from its active assignment, and an assignment is a rule for a
particular screen, virtual desktop, and optionally activity. The placement
mode is part of that same assignment. Consequently, always inspect both the
mode and selected layout before saving an Overview change.

The desired durable assignment on this machine is a screen-and-desktop rule:

```text
Dell Inc.:DELL S3425DW:825314902 + desktop 1
  → Snapping + Columns (2)
```

There must be no competing activity-specific autotile rule for that context.
The prior failure was exactly that: an activity rule with priority 400 selected
autotile and overrode the desktop rule at priority 399. Rule priority, not an
intuitive notion of specificity, decides the winner.

Use the following model and workflow:

| Goal | Correct surface | Important consequence |
| --- | --- | --- |
| Make a new zone definition | `Placement → Snapping → Layouts` → **New Layout** | Creates a distinct layout; use **Duplicate** before changing a built-in preset. |
| Edit the current layout | `Meta+Shift+E` | Opens the layout already assigned to the focused screen; it does not make a new layout. |
| Choose a layout for the current work context | `Overview` → monitor → **Snapping** → layout → **Apply** | Saves a context assignment, including the current mode. |
| Set a fallback | Layout card menu → **Set as Default** | Has no effect while an explicit context assignment exists. |
| Put new windows into empty zones | Per-layout **Auto-assign** control | Does not activate or select that layout. |
| Fast-switch layouts | Edge zone selector, `Meta+Alt+Space`, or quick-layout slots | Changes the current context's assignment; it is not a harmless preview. |

Editing a built-in layout or changing its per-layout properties makes a
copy-on-write user override under the same identity. It therefore still looks
like `Columns (2)` rather than a new named layout. The only user layout present
after the 2026-09-08 experiment is such an override of `Columns (2)`; it is a
valid two-column JSON file, not a corrupt custom layout.

For a layout intended to survive activity changes, prefer a screen-and-desktop
assignment through the Rules page or the daemon's
`assignLayoutToScreenDesktop` API. The Overview screen works for ordinary
current-context changes, but an activity-specific rule can intentionally
override that broader assignment. Verify before testing a drag:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.LayoutRegistry.getScreenStates
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Rules.getAllRules
```

If either screen query is empty and KWin reports a `Placeholder-1` output, do
not rewrite layouts or rules. The current KVM disconnects HDMI-A-1 when it
switches the monitor to another computer, so this state is expected hardware
behavior rather than a PlasmaZones failure. PlasmaZones has no real screen
context to which it can apply assignments until the KVM returns the display.

The planned replacement KVM has EDID emulation. It should keep the display's
identity and mode visible to the active computer while the video path is
switched, avoiding most output removal/re-add events and preserving KWin's
screen context. After installation, verify that a KVM switch no longer makes
`getScreenStates` empty before removing this diagnostic caveat.

PlasmaZones 3.4.12 does have hotplug recovery: it removes overlay surfaces for
a removed output, recreates them when the output returns, and its KWin effect
debounces screen changes before restoring zone geometry. That is recovery
*after* an output returns, not continuous operation while KWin has no output.
`KeepOnResolutionChange` covers a resolution change; it cannot assign zones or
draw highlights against an absent screen. A monitor power action that leaves
the output present is therefore benign, while a power action or KVM that makes
KWin remove the output uses this remove/re-add recovery path.

This is also the intended laptop dock/undock model. PlasmaZones identifies a
screen from EDID manufacturer, model, and serial (using the connector only to
disambiguate otherwise identical displays), so a re-docked physical monitor
should regain its per-screen layout assignment even if its connector name
changes. For windows that remain open in the same Plasma session, the effect
waits for the output topology to settle and reapplies their zone geometry.
This is not a separate saved *topology-profile database*, nor a promise to
restore arbitrary application windows after logout or after the application
has closed; KWin session restoration remains responsible for that scope.

### Focus follows mouse without automatic raise

Verified 2026-09-09. KWin owns global pointer focus, including ordinary,
floating, snapped, and tiled windows. The intended KWin `[Windows]` state is:

```ini
FocusPolicy=FocusFollowsMouse
AutoRaise=false
ClickRaise=true
DelayFocusInterval=0
```

Apply and reload it live with:

```bash
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key FocusPolicy FocusFollowsMouse
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key AutoRaise false
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key ClickRaise true
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key DelayFocusInterval 0
qdbus6 org.kde.KWin /KWin reconfigure
```

Do not also enable PlasmaZones' three mode-local focus-follow-mouse options:
`snappingFocusFollowsMouse`, `autotileFocusFollowsMouse`, and
`scrollingFocusFollowsMouse`. Leave all three `false`; otherwise a mode's
handler duplicates KWin's global focus management and its snapping mode only
applies to snapped windows.

Verify the running compositor, rather than relying only on `kwinrc`:

```bash
qdbus6 org.kde.KWin /KWin org.kde.KWin.supportInformation \
  | rg 'focusPolicy:|delayFocusInterval:|clickRaise:|autoRaise:'
```

Rollback to the prior Click-to-Focus setup:

```bash
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key FocusPolicy ClickToFocus
kwriteconfig6 --file ~/.config/kwinrc --group Windows \
  --key DelayFocusInterval 300
qdbus6 org.kde.KWin /KWin reconfigure
```

The pre-change files are at `~/.config/plasmazones.bak-ffm-20260909/`.

### Native KWin drag tiling disabled (PlasmaZones sole drag handler)

Configured 2026-09-16 with KWin 6.7.5 and PlasmaZones 3.4.16; interactive
verification after relogin is pending. KWin hardcodes
Shift-drag to its own custom tiling (upstream `src/window.cpp`,
`QuickTileFlag::Custom` paths) with no configuration switch;
`ElectricBorderTiling=false` does not cover that path. While `[Tiling]`
groups in `~/.config/kwinrc` still held layouts, Shift-drag displayed
KWin's native overlay (observed as roughly 40/20/40 columns) instead of a
free move. The intended end state is that PlasmaZones is the only
drag-placement handler and Shift-drag is a plain free move, matching
FancyZones.

The intended `~/.config/kwinrc` state:

- Both `[Tiling][<desktop-id>][<output-uuid>]` groups keep an explicitly
  empty array: `tiles={"layoutDirection":"horizontal","tiles":[]}`.
  `TileManager::readSettings()` creates children only for non-empty
  arrays, so no default layout is regenerated. Deleting the groups or
  writing an empty/invalid value would regenerate the three-column
  default.
- `[Windows] ElectricBorderTiling=false` and
  `ElectricBorderMaximize=false` disable native edge-drag half-tiling and
  top-edge-drag maximize.

The `ElectricBorder*` keys apply live via
`qdbus6 org.kde.KWin /KWin reconfigure`. The empty `[Tiling]` layout does
not reload on reconfigure (`TileManager::readSettings()` runs when desktop
roots are created, not on reconfigure), so it takes effect at the next
Plasma login. To remove native tiling immediately without a relogin,
delete every native tile in KWin's tile editor instead.

Verify after relogin: Shift-drag shows no native overlay and drops
freely; a plain title-bar drag shows PlasmaZones' overlay; PlasmaZones
Snap Assist still appears after a zone snap. Runtime confirmation of the
edge keys:

```bash
qdbus6 org.kde.KWin /KWin org.kde.KWin.supportInformation \
  | rg 'electricBorderTiling:|electricBorderMaximize:'
```

KWin regenerates `[Tiling]` entries whenever its tile editor saves a
layout; if native Shift-drag snapping ever reappears, re-apply the empty
arrays.

This empties only the two existing desktop/output layouts, not a global
Shift-handler switch. New outputs or desktops can acquire default layouts.
The running compositor can also save its old in-memory layout before logout;
check the saved arrays again after relogin if the overlay remains.

The 2026-09-16 drag trace also showed PlasmaZones disabling drag activation
on Shift, then auto-assigning the dragged window at drop and opening Snap
Assist. Removing KWin targets does not prove that separate behavior resolved;
if Shift-drop still snaps, investigate PZ auto-assignment next rather than
rewriting its already-correct triggers. No PZ settings were changed here.

Backup: `~/.config/kwinrc.bak-pz-only-20260916`. Rollback, after comparing
later changes, from outside the Plasma session:

```bash
cp -p ~/.config/kwinrc.bak-pz-only-20260916 ~/.config/kwinrc
```

Then log into Plasma again.

### Snap Assist disabled

Configured and applied 2026-10-03 with PlasmaZones 3.4.19.

Dragging a window into one half of the 2-zone `Columns (2)` layout sometimes
raised a window picker asking what to put in the other half. It was mistaken for
KWin tiling bleed-through; it is PlasmaZones' own Snap Assist overlay
(`popup.snapAssist.show`), an Aero-Snap-style picker that fills empty zones
(PlasmaZones whatsnew 1.13.0).

It fires only for a user-intent zone drop (`commitSnap ... intent= user`) that
leaves at least one zone empty, with at least one eligible candidate window.
PlasmaZones' own gates are logged as `showSnapAssist: feature disabled` and
`showSnapAssist: no empty zones or candidates`. On a 2-zone layout that means it
appears when the first window of a pair is dropped while the other half is still
empty, and it never appears for `intent= auto` placements. Between 2026-09-20 and
2026-10-03 the journal held 85 `commitSnap` and only 3 `showSnapAssist` events.

This is independent of the KWin native tiling work above: PZ placement is
region-based, so the popup appeared even when the pointer was nowhere near a
screen edge.

The desired end state is that it never appears. It is disabled through the
daemon's D-Bus API:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Settings.setSetting snapAssistFeatureEnabled false
```

`setSetting` takes a `QDBusVariant`; the bare `false` literal is accepted and the
call returns `true` on success. `snapAssistEnabled` is left `true` — it is not the
master gate (PlasmaZones whatsnew 1.11.3, "Master toggle for snap assist") and the
feature gate short-circuits first. `snapAssistTriggers` (currently `modifier 0 /
mouseButton 4`) and `snapAssistGraceMs` (150) are likewise left alone.

Verify:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Settings.getSetting snapAssistFeatureEnabled
grep -n SnapAssist ~/.config/plasmazones/config.json
```

The daemon persists this itself into `~/.config/plasmazones/config.json` as
`Snapping.Behavior.SnapAssist.FeatureEnabled`. That file is daemon-owned; edit it
only through the D-Bus API or with the service stopped.

Rollback:

```bash
qdbus6 org.plasmazones /PlasmaZones \
  org.plasmazones.Settings.setSetting snapAssistFeatureEnabled true
```

Runtime end-to-end confirmation (no `popup.snapAssist.show` in the journal after a
drag into a zone with the other half empty) was still outstanding at the time of
writing.

### Maximize is lost across a minimize cycle on a snapped window

Verified 2026-10-03 with PlasmaZones 3.4.19 and KWin 6.7.5 on the Dell
ultrawide, snapping mode + `Columns (2)`.

Symptom: maximize a window, minimize it, un-minimize it, and it comes back in
its **zone** rather than maximized.

This is PlasmaZones' own minimize-float cycle, not KWin, and it is deterministic
on a zone-snapped window:

1. Minimizing a snapped window makes PZ **float** it so the zone slot is freed.
   The daemon logs the zone it is holding on to:
   `Saved pre-float zones for "<id>" -> QList("{<zone>}")`.
2. Un-minimizing **restores** the window to that saved zone. The effect logs
   `Snap: window unminimized, unfloating: "<id>"` followed by
   `slotApplyGeometryRequested: ... geo: QRect(<zone rect>) zoneId: "{<zone>}"`
   while `currentFrame` is still the maximized rect.
3. Every snap placement deliberately clears KWin's maximize bit, because a
   surviving maximize would fight the zone rect:
   `Demoting KWin maximize for snap placement of "<id>" into QRect(...)`
   (source: `demoteMaximizeForSnapPlacement`, issue #1036).

PZ saves the zone assignment across the cycle but captures **no maximize
state**: `Control.getFullState` window records carry only `windowId`,
`screenId`, `zoneId`, and `isFloating`. Snapping mode also has no maximize
interception — the effect declines it explicitly (`Maximize interception:
declining "<id>" — not a tiled window, KWin keeps the request`); per-mode
maximize exists for scrolling only, and the project's own
`docs/maximize-intercept-plan.md` records snapping's answer as an open question
("snapping has no such state today").

Measured, on a probe window snapped to the right zone
(`getWindowInfo`: `maximizeHorizontal`/`maximizeVertical`):

| step | geometry | maximize H/V |
| --- | --- | --- |
| snapped, free | 400,400 600x500 | 0 / 0 |
| after maximize | 0,0 3440x1394 | 2 / 1 |
| after minimize | 0,0 3440x1394 | 2 / 1 (minimized) |
| after un-minimize | 1721,0 1719x1394 | **0 / 0** |

The control case isolates the cause: an identical **floating** window (not
zone-snapped, so PZ never minimize-floats it) went through the same three steps
and came back at 2 / 1 — still maximized.

There is no setting for this. PZ always minimize-floats a snapped window, with
no opt-out, and snapping has no pre-maximize slot to restore from. Current
version is 3.4.19 and it is the newest tag, so there is no upgrade path. No
matching upstream issue exists (nearest is #1036, which introduced the demote);
it is an unreported gap.

Workarounds:

- Toggle the window to floating first (`Meta+F`, `toggleWindowFloatShortcut`)
  before minimizing; a floating window keeps its maximize. Clunky, and the
  window leaves its zone while floating.
- Re-maximize after restoring. Nothing is lost except the maximize state.

A bug report was filed upstream on 2026-10-03 as a **Discussion** (the repo
disables blank issues and routes bug reports to
`discussions/new?category=bug-reports`):

- https://github.com/fuddlesworth/PlasmaZones/discussions/1131

The posted text is kept verbatim at
[plasmazones-maximize-minimize-report.md](plasmazones-maximize-minimize-report.md).
It includes the control case, the journal excerpt, and the source-level
references. Watch that discussion for a fix; if one lands, re-verify the table
above and then delete this section.

Reproduce non-destructively with `qdbus6 org.kde.KWin /KWin
org.kde.KWin.getWindowInfo <uuid>` for observation
(`maximizeHorizontal`/`maximizeVertical` are 2 / 1 when fully maximized) and a
throwaway window driven by a KWin script (`org.kde.kwin.Scripting.loadScript`
then `org.kde.kwin.Script.run` on `/Scripting/Script<id>`; the maximize method
is `setMaximize(bool,bool)`, and matching is by `resourceClass`).

## Secret storage

The two desktops ship competing secret stores. They were consolidated onto
gnome-keyring so that one keyring serves every session. See
[passwordless-login.md](passwordless-login.md) for the full chain, including the
deliberate decision to leave that keyring unencrypted.

Relevant state at the time of the change, which made it a clean cutover:

- `~/.local/share/kwalletd/` was empty; no wallets existed.
- `~/.local/share/keyrings/` did not exist.
- There were 0 NetworkManager connections, so no saved WiFi secrets were lost.
- `kwalletd6` was running but held nothing.

The gnome-keyring XDG autostart entries are guarded with
`OnlyShowIn=GNOME;Unity;MATE;Cinnamon;`, so those desktop files do not run in a
Plasma session. The daemon nevertheless runs there: it is started on demand by
the user-level `gnome-keyring-daemon.socket` (enabled, `WantedBy=sockets.target`)
and by D-Bus activation of `org.freedesktop.secrets` when an application first
asks for a secret. Repointing the KDE secret portal at it is what makes it the
working backend there. Verified 2026-09-21: stopping
`gnome-keyring-daemon.service` with the socket left active still starts the
daemon and serves secrets on first use.

## Caveat for future work

Because Plasma was assembled piecemeal, assumptions that hold for a stock
CachyOS or stock Arch KDE install do not necessarily hold here. Check that a
component is actually installed before relying on it.
