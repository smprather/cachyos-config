# Chrome Browser Notes

## Current state

As of 2026-09-07, the daily Google browser is Stable Chrome:

```text
google-chrome 152.0.7977.82-1
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
--ozone-platform=x11
```

These carry forward the tested NVIDIA/Plasma playback workaround from Canary:
use ANGLE's OpenGL backend and run through XWayland instead of Chrome's native
Wayland/Vulkan path.

The user confirmed smooth video playback on 2026-09-07 after switching to
Stable Chrome with these flags. This is the working playback baseline; retain
it unless a concrete regression warrants further changes. Hardware video
decoding remains unverified, separately from the confirmed smooth playback.

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
