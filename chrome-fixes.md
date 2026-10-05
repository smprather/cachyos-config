# Chrome Browser Notes

## Current state

As of 2026-10-04, the daily Google browser is Stable Chrome, running **native
Wayland** (no XWayland):

```text
google-chrome 154.0.8037.97-1
```

Chrome Canary was removed after YouTube playback in Plasma Wayland showed GPU
process instability. Its profile data under `~/.config/google-chrome-canary/`
was not deleted.

Stable Chrome reads user flags from:

```text
~/.config/chrome-flags.conf
```

Current contents:

```text
--use-angle=gl
```

`--use-angle=gl` is still load-bearing: it keeps rendering on ANGLE's OpenGL
backend rather than Vulkan. `--ozone-platform=x11` was **removed** on
2026-10-04; see [Native Wayland confirmed](#native-wayland-confirmed-2026-10-04).

Do not re-add `--ozone-platform=x11` casually. If Chrome ever needs to fall
back to XWayland again, the taskbar pin must be changed in the same step — see
[Taskbar pin depends on the ozone platform](#taskbar-pin-depends-on-the-ozone-platform).

## Native Wayland confirmed (2026-10-04)

`--ozone-platform=x11` was inherited from Canary-era work on 2026-09-07 and had
never been re-tested against a current Chrome. Re-examining that decision showed
its own notes already contradicted the hardware-blame premise:

> The NVIDIA driver, Vulkan, and OpenGL stack were verified independently.

and

> native Wayland Chrome Canary is stable when ANGLE is forced to its OpenGL
> backend

What actually drove the x11 flag was YouTube **stutter**, not crashes, and the
2026-09-07 evidence for it was a *muted, disposable-profile probe*. Those same
notes flagged the gap and it was never closed:

> Behavior-level verification is still required: play the YouTube video that
> stuttered and inspect YouTube "Stats for nerds" for dropped frames.

For the record, the user did test the XWayland baseline afterwards and the
stutter was gone. That result was never written down until now, which is why
the flag looked unjustified when it was questioned later.

Since that decision Chrome moved from ~140 (Canary) to 154 Stable and the
NVIDIA driver from 610.57.04 to 615.71.09.

### Gate 1 — disposable-profile probe (non-destructive)

Run without touching the live profile, invoking the real binary directly so the
wrapper cannot re-inject the x11 flag:

```bash
PROBE=/tmp/pz-wayland-probe
rm -rf "$PROBE"; mkdir -p "$PROBE"
setsid /opt/google/chrome/google-chrome \
  --user-data-dir="$PROBE" \
  --use-angle=gl \
  --no-first-run --no-default-browser-check \
  --disable-features=Translate about:blank >/tmp/pz-probe.out 2>&1 &
```

**`/opt/google/chrome/google-chrome` must be used, not `/usr/bin/google-chrome-stable`.**
The wrapper execs the binary with the contents of `chrome-flags.conf`
prepended, so invoking it would silently reintroduce `--ozone-platform=x11` and
the probe would prove nothing.

Result: GPU process alive with `--ozone-platform=wayland --use-angle=gl`,
`--gpu-recent-crash-count=0`, no crash dumps, no `Crash Reports` directory
created at all. The probe emitted the known-benign
`is not compatible with Vulkan` warning, which is **expected and harmless**:
Vulkan is Chrome's default GL backend, and `--use-angle=gl` keeps rendering on
OpenGL. That warning is not evidence of instability and must not be treated as
a reason to re-add the x11 flag.

Tear down by PID, never `pkill -f`:

```bash
kill "$(pgrep -f 'user-data-dir=/tmp/pz-wayland-probe' | head -1)"
rm -rf /tmp/pz-wayland-probe
```

### Gate 2 — real playback (user-verified)

With Chrome fully quit, the x11 line was removed and Chrome relaunched on the
normal profile:

```bash
cp -p ~/.config/chrome-flags.conf \
  ~/.config/chrome-flags.conf.bak-x11-removal-<timestamp>
grep -v -- '--ozone-platform=x11' ~/.config/chrome-flags.conf \
  > ~/.config/chrome-flags.conf.tmp \
  && mv ~/.config/chrome-flags.conf.tmp ~/.config/chrome-flags.conf
```

Verified after ~12 minutes including 4K playback:

| signal | result |
| --- | --- |
| GPU process | single, uptime 11:49, `--gpu-recent-crash-count=0` |
| GPU process flags | `--ozone-platform=wayland --use-angle=gl` |
| Renderers with `--disable-gpu-compositing` | 0 of 36 (no GPU fallback) |
| New crash dumps | 0; newest overall is still 2026-09-14 |
| Playback | user-confirmed smooth, no stutter, incl. 4K |

Hardware video decoding is still **unverified** in the NVDEC sense. The
`featureStatus.video_decode` and empty `videoDecoding` array disagreement noted
in the 2026-09-07 audit still applies; do not read smooth playback as proof of
NVDEC.

### Rollback

Restore the flag file and restart Chrome:

```bash
cp ~/.config/chrome-flags.conf.bak-x11-removal-20261004-225738 \
  ~/.config/chrome-flags.conf
```

Then set the taskbar pin back to `applications:com.google.Chrome.desktop`, or
the pinned icon will not match the running window — see the next section.

## Taskbar pin depends on the ozone platform

Chrome ships **two** desktop files from the same package, and only one is
correct at a time:

| desktop file | `StartupWMClass` | `NoDisplay` | intended for |
| --- | --- | --- | --- |
| `com.google.Chrome.desktop` | `google-chrome` | `true` | Wayland `app_id` `com.google.chrome` |
| `google-chrome.desktop` | `Google-chrome` / `google-chrome` | unset | XWayland `WM_CLASS`, and the app menu |

When a running Chrome fails to match the pinned launcher, Plasma's
Icons-only Task Manager keeps the pinned launcher in place *and* adds a separate
entry for the window. That is the "running app takes a new icon space" symptom.

### How Plasma resolves it

`TaskManager::windowUrlFromMetadata()` in
`plasma-workspace/libtaskmanager/tasktools.cpp` resolves a window's launcher URL
in this order:

1. If `xWindowsWMClassName` is non-empty (an **X11** window), match
   `StartupWMClass` against it case-insensitively. Both Chrome desktop files
   match, so `sortServicesByMenuId()` breaks the tie by prepending whichever
   `menuId` **starts with** the WM class. `google-chrome.desktop` wins;
   `com.google.Chrome` starts with `com.`, so it loses.
2. If `appId` is non-empty (a **Wayland** window), the WM-class step is skipped
   entirely, and `appId` is matched against `StartupWMClass`, then
   `desktopEntryName()`, then `Name`.

So the resolution depends on which platform Chrome is actually using:

| Chrome runs as | Window metadata | Resolves to | Pin must be |
| --- | --- | --- | --- |
| XWayland | `WM_CLASS = google-chrome` | `google-chrome.desktop` | `applications:google-chrome.desktop` |
| native Wayland | `app_id = google-chrome` | `google-chrome.desktop` | `applications:google-chrome.desktop` |

Both rows currently resolve to `google-chrome.desktop`, which is why the current
pin works. The `com.google.Chrome.desktop` pin is what produces the duplicate
icon.

Chrome's Wayland `app_id` was confirmed empirically as `google-chrome` (Chrome
takes it from the desktop entry it was launched from), not `com.google.chrome`.
PlasmaZones logs it:

```bash
journalctl --user -t kwin_wayland --since '-12 min' --no-pager \
  | grep -oE 'appId: "[^"]*"' | sort | uniq -c
#    14 appId: "alacritty"
#     9 appId: "google-chrome"
```

### Verify the pin matches

```bash
qdbus6 org.kde.plasmashell /PlasmaShell \
  org.kde.PlasmaShell.evaluateScript \
  'var ps=panels();for(var i=0;i<ps.length;i++){var ws=ps[i].widgets();for(var j=0;j<ws.length;j++){var w=ws[j];if(w.type==="org.kde.plasma.icontasks"){w.currentConfigGroup=["General"];print(JSON.stringify(w.readConfig("launchers",[])));}}}'
```

For the merge to hold, the entry must read `applications:google-chrome.desktop`.

**Caution: `launchers` is a list, not a string.** The config file stores it
comma-joined, and `readConfig("launchers", "")` hands back a comma-joined
*string* that looks perfectly correct and survives a plain `print()`. That is
how a string-vs-list mistake goes unnoticed.

**Do not test this with `Array.isArray()`.** Plasma's QJSEngine returns a
`QVariantList` wrapper, which stringifies as an array but is **not** a native
`Array` — `Array.isArray()` returns `false` even for the healthy value. A check
written that way reports the good state as broken.

The real discriminator is `length` and the type of element zero:

```javascript
var v = w.readConfig("launchers", []);
print(JSON.stringify({
  length: v.length,             // 7 for the good list
  first: String(v[0]),          // "applications:systemsettings.desktop"
  firstIsChar: String(v[0]).length === 1   // true only if it came back a string
}));
```

- Good: `length` is `7` and `first` is a whole launcher URL.
- Broken: `length` is ~120 (character count of the joined string) and `v[0]` is
  the character `"a"`.

Writing a comma-joined string into the key makes Plasma treat the whole value as
a single invalid launcher and silently drop the rest of the pins. Write it back
as a real array:

```javascript
w.currentConfigGroup = ["General"];
var v = w.readConfig("launchers", []);
var a = [];
for (var k = 0; k < v.length; k++) { a.push(String(v[k])); }   // native array
w.writeConfig("launchers", a);
```

`writeConfig` does accept a native JS array and persists it as a proper list —
it is only the *read* side that returns a wrapper.

Backup before editing:

```bash
cp -p ~/.config/plasma-org.kde.plasma.desktop-appletsrc \
  ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak-chrome-pin-<timestamp>
```

### Visual check

The panel is 46px tall at the bottom on this 3440x1440 screen (offset 46 from
the work area). Capture and crop it rather than trusting the config alone, and
inhibit idle first — a DPMS-blanked display returns black:

```bash
spectacle -m -b -n -o /tmp/panel.png
magick /tmp/panel.png -crop 1000x46+0+1394 +repage -scale 380% /tmp/panel-zoom.png
```

Compare slot counts rather than eyeballing. Counting icon runs by pixel column
gave `10 slots` with a duplicate Chrome before the pin fix and `9 slots` after,
which is the measurable form of "the running app uses the pinned item's space".

## Stable Chrome stdout/stderr audit (2026-09-07)

Launched the normal Stable profile with both output streams captured in the
user journal. Chrome was not already running, so this captured the actual
browser rather than a launcher forwarding to an existing instance:

```bash
systemd-run --user --unit=chrome-diagnostics --collect \
  --property=StandardOutput=journal --property=StandardError=journal \
  /usr/bin/google-chrome-stable
journalctl --user -u chrome-diagnostics.service -f
```

This is a transient diagnostic launch, not an enabled startup service. Exit
Chrome normally when finished. A subsequent ordinary launch does not inherit
this journal capture.

Observed messages and disposition:

- `MESA-LOADER` permission errors for `nvidia-drm_gbm.so` and `dri_gbm.so`:
  the files exist and are readable. Two disposable-profile probes reported
  NVIDIA RTX 3060 ANGLE/OpenGL rendering, enabled GPU compositing and WebGL,
  `sandboxed: true`, and `processCrashCount: 0`. These warnings did not imply
  loss of GPU rendering in the probes. The exact failing load path remains
  unconfirmed; do not change library permissions or disable the sandbox.
- `/etc/profile.d/Hyprland.sh`, owned by `cachyos-hypr-noctalia`, exports
  `GBM_BACKEND=nvidia-drm` and `EGL_PLATFORM=wayland` even in Plasma. Removing
  both variables only from a test Chrome's environment eliminated the
  NVIDIA-specific loader warning, but the `dri_gbm.so` warning remained and
  GPU feature status was unchanged. No persistent environment edit was made.
- `DEPRECATED_ENDPOINT` from `google_apis/gcm`: push-service registration
  failed in the normal profile and a fresh profile. Another fresh-profile
  probe reported `PHONE_REGISTRATION_ERROR` / `wrong_secret`. Extensions are
  not necessary to reproduce this. It is not evidence of a graphics failure;
  the precise server-side cause was not established. A previous analogous
  cross-platform incident is documented in the
  [Chromium developer discussion](https://groups.google.com/a/chromium.org/g/chromium-dev/c/PJXcS2qqYs0).
- `g_main_context_pop_thread_default: assertion 'stack != NULL' failed`:
  appeared in the normal profile and both fresh-profile probes. This indicates
  an internal GLib context-lifetime error, not a missing desktop package.
  No local configuration fix was established. See the
  [GLib context API requirements](https://developer.gnome.org/documentation/tutorials/main-contexts.html).
- `Created TensorFlow Lite XNNPACK delegate for CPU`: informational model
  initialization output, not an error.

The DevTools `SystemInfo.getInfo` probes had empty `videoDecoding` and
`videoEncoding` capability arrays, despite `featureStatus.video_decode` saying
`enabled`. Do not interpret that status alone as proof of hardware video
decoding or smooth YouTube playback. These were short startup tests.

Existing Chrome flags were retained. No logging suppression, feature-disabling
flags, or driver/package changes were added merely to silence diagnostics.
Temporary evidence (not durable across `/tmp` cleanup):
`/tmp/chrome-baseline-Ocofkl/{startup.log,gpu.json}` and
`/tmp/chrome-clean-env-jdlEnL/{startup.log,gpu.json}`.

## Legacy Canary notes

The sections below record the diagnostics that led to abandoning Canary as the
daily browser. They are retained as history, not as the current target state.

## Fontconfig error

### Symptom

Chrome Canary reported:

```text
Fontconfig error: Cannot load default config file: File not found
```

### Diagnosis

- The desktop session is GNOME on Wayland.
- `/etc/fonts/fonts.conf` exists and is readable.
- `fc-match` successfully resolves fonts using the system configuration.
- No malformed per-user Fontconfig configuration was present.
- An A/B test confirmed that an invalid `FONTCONFIG_FILE` reproduces the exact message, while explicitly using `/etc/fonts/fonts.conf` removes it.

### Fix

Created:

```text
~/.config/environment.d/90-fontconfig.conf
```

Contents:

```ini
FONTCONFIG_FILE=/etc/fonts/fonts.conf
```

The current GNOME user service environment was refreshed with:

```bash
systemctl --user set-environment FONTCONFIG_FILE=/etc/fonts/fonts.conf
```

A Chrome Canary launch through the user-service environment completed with zero Fontconfig errors.

### Rollback

Remove `~/.config/environment.d/90-fontconfig.conf`, then log out and back in. To clear it immediately from the current user service environment:

```bash
systemctl --user unset-environment FONTCONFIG_FILE
```

## GPU process crash

### Symptom

Chrome Canary's GPU process repeatedly exited with `SIGSEGV` in NVIDIA's `libnvidia-glcore.so.610.57.04` while using `--ozone-platform=wayland`.

### Initial workaround

The initial conservative workaround was:

```text
~/.config/chrome-canary-flags.conf
```

with:

```text
--disable-gpu
```

This stopped the crashes but disabled hardware acceleration and GPU-backed WebGL performance.

### Current fix

The NVIDIA driver, Vulkan, and OpenGL stack were verified independently. A visible WebGL test showed that native Wayland Chrome Canary is stable when ANGLE is forced to its OpenGL backend, and NVIDIA reported the Chrome GPU process using GPU memory.

The active flag is:

```text
--use-angle=gl
```

This preserves hardware acceleration while avoiding the crashing default backend. Chrome Canary still prints its existing Wayland/Vulkan compatibility warning; temporary `--disable-vulkan` and `--disable-features=Vulkan` tests did not remove that diagnostic, but the tested GL path did not create a new crash dump.

### Rollback

Remove `--use-angle=gl` from `~/.config/chrome-canary-flags.conf`, then restart Chrome Canary. If the default path crashes again, restore `--disable-gpu` as the safe fallback.

## YouTube stutter in Plasma

### Symptom

After switching back to Plasma Wayland on 2026-09-07, YouTube playback in
Chrome Canary was stuttery.

### Diagnosis

The active session was KDE/Plasma Wayland. Chrome Canary was running with the
previously documented `--use-angle=gl` flag, but its live process tree showed a
GPU process with `--gpu-recent-crash-count=3`. Many renderer processes also had
`--disable-gpu-compositing`, which means Chrome had fallen back after GPU
process failures.

Fresh crash reports existed from 2026-09-07 11:21-11:22 under
`~/.config/google-chrome-canary/Crash Reports/completed/`.

The NVIDIA driver and OpenGL/EGL stack were not generally broken:

```bash
nvidia-smi
glxinfo -B
eglinfo -B
```

Those checks showed the RTX 3060 on driver 610.57.04 and working NVIDIA
OpenGL/EGL paths.

A disposable native-Wayland Canary probe with `--use-angle=gl` did not crash on
`about:blank`, but it logged:

```text
'--ozone-platform=wayland' is not compatible with Vulkan. Consider switching to '--ozone-platform=x11' or disabling Vulkan
```

It also skipped the NVIDIA VA-API device:

```text
Should skip nVidia device named: nvidia-drm
```

Forcing NVIDIA VA-API with
`LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct` and
`--enable-features=VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks,AcceleratedVideoDecodeLinuxGL`
was tested against a muted YouTube embed in a disposable profile. That path
crashed the GPU process with exit code 139 and caused WebGL context loss, so it
must not be used as the fix.

The same muted YouTube embed under `--ozone-platform=x11 --use-angle=gl` did
not crash the GPU process during the probe. It still did not show NVDEC usage,
so this is a stability fix for Chrome's compositor path, not confirmed hardware
video decode.

### Fix

Updated:

```text
~/.config/chrome-canary-flags.conf
```

Contents:

```text
--use-angle=gl
--ozone-platform=x11
```

This keeps the prior ANGLE OpenGL workaround and runs Chrome Canary through
XWayland inside the Plasma Wayland session, avoiding the native
Wayland/Vulkan path that Chrome itself warned about.

Chrome Canary must be fully restarted for this to apply. New windows launched
while the old browser process is still alive will continue using the old
process and old GPU fallback state.

### Verify

After fully restarting Chrome Canary:

```bash
ps -eo pid,ppid,comm,args | rg -i 'chrome.*gpu-process|chrome.*renderer'
nvidia-smi pmon -c 1
```

Expected process evidence:

- Chrome child processes include `--ozone-platform=x11`.
- The GPU process no longer accumulates fresh `--gpu-recent-crash-count`
  increments during YouTube playback.
- Renderers are not broadly relaunched with `--disable-gpu-compositing`.

Behavior-level verification is still required: play the YouTube video that
stuttered and inspect YouTube "Stats for nerds" for dropped frames.

### Rollback

Restore the previous flag file:

```bash
cp ~/.config/chrome-canary-flags.conf.bak-20260907-121005 ~/.config/chrome-canary-flags.conf
```

Then fully restart Chrome Canary.

## Separate warnings observed

These were not changed because they are unrelated to Fontconfig:

- `GtkSettings` reported that `gtk-modules` is not a valid property. The existing GTK configuration contains `gtk-modules=colorreload-gtk-module`.
- Chrome Canary warned that Wayland is not compatible with Vulkan in its current path. The active workaround is the tested hardware-accelerated `--use-angle=gl` path.
