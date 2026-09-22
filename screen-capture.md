# Screen capture

## Desired state

In Plasma Wayland, PrintScreen starts an interactive rectangular region capture.
After the selection is accepted, the PNG is saved under
`~/Pictures/Screenshots/` and that same image is placed on the Wayland
clipboard. Spectacle must not show its main window or its own completion
notification. A small notification with an **Edit Grab** action button appears
after each capture; clicking it opens Spectacle's annotation editor on the
saved file, while ignoring it keeps the flow completely silent.

## Implementation

The tracked source files are:

- `bin/region-screenshot`
- `desktop/region-screenshot.desktop`

They are installed as:

- `~/.local/bin/region-screenshot`
- `~/.local/share/applications/region-screenshot.desktop`

The wrapper uses Spectacle's native KWin capture path:

```sh
spectacle --region --background --nonotify --release-capture --output <file>
wl-copy --type image/png < <file>
```

`--background` avoids Spectacle's main window; `--nonotify` suppresses its
completion notification. The wrapper deliberately does not use Spectacle's
`--copy-image`, because Spectacle does not copy when `--output` is also
given. Instead, `wl-copy` receives the saved PNG after a successful capture.

After the copy, the wrapper shows a notification via `notify-send --wait`
with one action, `edit=Edit Grab`. `notify-send --wait` blocks up to the
10-second expire time and prints the chosen action's name on stdout; a
timeout or dismissal prints nothing and exits nonzero, which the wrapper
treats as "no edit requested" (`|| true`). Because the wrapper runs under
`set -e`, the edit launch must use an `if` block rather than a bare
`[ ... ] && ...` chain: a false test would otherwise abort the script.

### Key routing (keyd F13 bridge)

The desktop entry declares `X-KDE-Shortcuts=F13`. Physical PrintScreen is
remapped to F13 by keyd in `/etc/keyd/default.conf`:

```ini
[main]
print = f13
```

This bridge exists because Plasma 6.7's live global-shortcut daemon (embedded
in `kwin_wayland`) refuses all remote D-Bus rebind attempts
(`setShortcut`, `setShortcutKeys`, `setForeignShortcut`, `setForeignShortcutKeys`,
`setInactive`, `unregister`) for components it does not own, and its key index
caches every binding registered at login. Spectacle's
`org.kde.spectacle.desktop/_launch` ships with a `Print` default, so a custom
action bound to `Print` collides with it in the live daemon and both fire:
the silent grab runs and the full Spectacle GUI also launches. Remapping the
physical key to F13 makes Spectacle's `Print` default unreachable, and
`~/.config/kglobalshortcutsrc` pins both sides durably:

```ini
[org.kde.spectacle.desktop]
_launch=none,none,Launch Spectacle

[region-screenshot.desktop]
_launch=F13,F13,Capture Region to Clipboard
```

Shortcut changes take effect for a new login session; the running daemon
never re-reads them. `keyd` itself reloads live (`sudo keyd reload`), so
between a config change and the next relogin PrintScreen may fire nothing.

## Apply or repair

```bash
install -D -m 755 bin/region-screenshot ~/.local/bin/region-screenshot
install -D -m 644 desktop/region-screenshot.desktop \
  ~/.local/share/applications/region-screenshot.desktop
kbuildsycoca6 --noincremental
```

keyd config (see `keyboard-remapping.md` for the full file):

```bash
sudo keyd check
sudo keyd reload
```

## Verification

Automated wrapper test (covers silent path and edit-action path):

```bash
REGION_SCREENSHOT_SCRIPT=~/.local/bin/region-screenshot \
  bash tests/test-region-screenshot.sh
```

Check the global shortcut registration:

```bash
qdbus6 --literal org.kde.kglobalaccel \
  /component/region_screenshot_desktop \
  org.kde.kglobalaccel.Component.allShortcutInfos
```

The `_launch` entry must report key code `16777270` (Qt's F13 key) in a
session started after the config change. Press PrintScreen and drag a small
region. Verify that one PNG appears in `~/Pictures/Screenshots/`, pasting
into an image-aware application yields that same capture, no Spectacle window
appears, and the notification's Edit Grab button opens Spectacle's editor on
that file. Escape cancels the region selector without saving or changing the
clipboard.

## Rollback

Remove the custom action, restore Spectacle's launcher shortcut, and revert
keyd:

```bash
gdbus call --session --dest org.kde.kglobalaccel \
  --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcut \
  "['region-screenshot.desktop', '_launch']" "@ai []"

gdbus call --session --dest org.kde.kglobalaccel \
  --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcut \
  "['org.kde.spectacle.desktop', '_launch']" "[16777225]"

sudo cp /etc/keyd/default.conf.bak-print-f13-20260913 /etc/keyd/default.conf
sudo keyd check
sudo keyd reload

rm ~/.local/bin/region-screenshot \
  ~/.local/share/applications/region-screenshot.desktop
kbuildsycoca6 --noincremental
```

Log out and back in after the rollback so the global-shortcut daemon reloads
`kglobalshortcutsrc`.
