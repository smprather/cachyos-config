# Standard tools

This is the concise, living list of everyday desktop tools intended to be
available on this CachyOS machine. Any tool installed through this repository
or by an agent must be added here. Add an entry when a tool becomes a standing
part of the preferred setup; record detailed diagnosis and changes in
`customizations.md`.

| Tool | Role | Package | Notes |
|---|---|---|---|
| Go | Go compiler and developer toolchain | `go` | Official CachyOS package; provides the `go` command, compiler, formatter, and module tooling. |
| Okular | Primary PDF and general document reader | `okular` | KDE-native; supports annotations, forms, and common document formats. |
| Pinta | Lightweight image editor | `pinta` | GTK4/libadwaita; quick annotations and edits for captured screenshots. |
| Resources | Graphical system and process monitor | `resources` | GNOME Circle application; usable from Plasma and other desktops. |
| btm | Terminal system/process monitor | `cargo:bottom` | Installs the `btm` executable; the `bottom` crate provides a configurable TUI with CPU, memory, disk, network, process, and GPU views. |
| nvglances | NVIDIA-focused terminal system monitor | `cargo:nvglances` | Rust TUI using NVML; shows CPU, memory, network, GPU utilization, and GPU processes. |
| Konsole | KDE terminal emulator | `konsole` | KDE-native terminal, installed 2026-10-11 (26.08.2-1.1 from `cachyos-extra-v3`). Completes the Plasma application set; `alacritty` ("atty") remains the daily driver. |
| fixpanel | One-word recovery for a frozen Plasma panel | user-local: repo `bin/fixpanel`, symlinked into `~/.local/bin` | Added 2026-10-14 after plasmashell froze with its main thread pinned in Qt's EGL fallback retry. Restarts only the shell (`systemctl --user kill -s KILL` + start, then polls the D-Bus probe); open apps and terminals are untouched. The automatic equivalent is `plasmashell-wedge-watch` with its autokill flag. Do not hold the power button instead — the machine is alive when the panel is not. See `plasmashell-wedge.md`. |
| nvidia-driver-watch | Weekly notice when a newer NVIDIA driver is in the repos | user-local: repo `bin/nvidia-driver-watch.sh` + `~/.config/systemd/user/nvidia-driver-watch.{service,timer}` | Added 2026-10-14 because the NVIDIA driver is the last unresolved suspect for the panel freeze and testing one means staying on it for days — without this, "pinned for a test" becomes "pinned forever". Logs to the user journal; also prints the test order for a new driver. `systemctl --user disable --now nvidia-driver-watch.timer` to remove. |
| Shelly | GTK4 package manager with tray notifications | `shelly` (CachyOS, installed 2026-09-30) | **Do not use it to change the system.** `shelly upgrade all` performs real pacman transactions that appear in **neither** `/var/log/pacman.log` **nor** the journal: eight of them between 2026-10-06 and 2026-10-13 exist only as snapper pre/post pairs (155/157/167/169/171/173/179/181, described `/usr/bin/shelly upgrade all --ui-mode`), and that set includes the `qt6-base` 6.11.2 → 6.12.0 and `plasma-workspace`/`kwin` upgrade in the panel-wedge timeline. Use `sudo pacman -Syu` instead — same hooks and snapshots, plus the log. Reading is harmless: version browsing, the update list, and the tray notifier (which is how you learn updates exist) change nothing. See `AGENTS.md` Agent Contract #2 and `plasmashell-wedge.md`. It can be removed with `sudo pacman -Rns shelly`; check that nothing else needs it first (its `Required By` field), in case a CachyOS meta package pulls it in. |
| wezterm | Terminal (the documented daily driver) | `wezterm` | Restored on the new install 2026-10-17; config in `~/.config/wezterm` and the rules in `AGENTS.md` still apply (never run bare `wezterm-gui`). Undo: `sudo pacman -Rns wezterm`. |
| docker + docker-compose | Containers | `docker docker-compose` | Restored 2026-10-17 with `docker.service` enabled and `mylesp` in the `docker` group. Undo: `sudo pacman -Rns docker docker-compose`, disable the unit, `sudo gpasswd -d mylesp docker`. |
| paru | AUR helper | `paru` | Restored 2026-10-17. `system-inventory.md`'s "no AUR helper" note describes Aug 2026; paru was installed later on the old system. |
| blueman | Bluetooth tray manager | `blueman` | Restored; the applet the old desktop used (it was running on the old system). |
| earlyoom | Early OOM killer | `earlyoom` | Restored with its unit enabled. |
| ksnip | Screenshot annotation | `ksnip` | Restored; spectacle captures, ksnip marks up. |
| gnome-keyring | Secret service for non-KDE apps | `gnome-keyring` | Restored alongside the blank `~/.local/share/keyrings/login.keyring` that came with home (`passwordless-login.md`, change 2). |
| ccache, sccache, mold, ninja, hyperfine | Build caches, linker, measurement | same names | Restored 2026-10-17; the wiring and the traps are in `build-caches.md`. Undo per package with `-Rns`. |
| cups | Printing | `cups` | Restored; `cups.socket` enabled. |
| clamav | Antivirus scanner | `clamav` | Restored; `clamav-freshclam.service` enabled. |
| chromium | Browser package | `chromium` | Restored (the profiles were deliberately deleted 2026-10-17, so it starts fresh — see `chrome-fixes.md` for the package, not a profile). |
| go, jre-openjdk, iverilog, klayout, librecad, graphviz, ghostscript, plantuml, git-lfs | Dev / EDA / document toolchain | same names | Restored 2026-10-17 in one transaction (snapper 17/18). |
| zed, neovim-nightly-bin | Editors | `zed neovim-nightly-bin` | Restored 2026-10-17. |
| audacity, decibels, simple-scan, pinta, okular, resources, qalculate-qt, playerctl, pamixer | Desktop tools | same names | Restored 2026-10-17. |
| tcsh, tecla, wl-clip-persist, qt5-wayland, qt5-imageformats, qt5-quickcontrols2, qt6-wayland, kvantum | Compatibility / theme bits | same names | Restored 2026-10-17 for Qt5-era apps and theming. |
| fio | Disk I/O engine behind the before/after benchmark suite | `fio` | Installed 2026-10-17 (`sudo pacman -Syu --noconfirm fio sysbench vkmark`, snapper pre/post 185/186) so the published suite does not depend on the loadout copy at `~/.local/share/loadout/bin/fio`. Drives `scripts/system-benchmark.sh`; results and the variance each metric can bear are in `benchmarks/README.md`. Undo: `sudo pacman -Rns fio`. |
| sysbench | CPU and memory benchmark | `sysbench` | Same install. Single- and 24-thread integer and memory numbers in the suite. Undo: `sudo pacman -Rns sysbench`. |
| vkmark | Vulkan benchmark | `vkmark` | Same install. The suite's GPU section; it has no headless winsys, so it opens a window for a few seconds — run it with the desktop in the state the comparison run will be in. Undo: `sudo pacman -Rns vkmark`. |
| qimgv | Fast image viewer with video playback | `qimgv-git` (chaotic-aur) | Installed 2026-10-17 (`sudo pacman -Syu --noconfirm google-chrome qimgv-git`, snapper 24/25). Pulls `opencv`, `blas`, `cblas`, `lapack`, `verdict` — 575 MiB installed is the real cost of this viewer. `spectacle` captures, `ksnip` annotates, `qimgv` browses. Undo: `sudo pacman -Rns qimgv-git`. |
| netgen | Automatic 3D tetrahedral mesh generator | `netgen-git` (AUR) | Installed 2026-10-17 with `paru -S netgen-git` — in no binary repo, so it is a local build (6.2.2608.r60.g1507093-1). Binary `/usr/bin/netgen`. Undo: `sudo pacman -Rns netgen-git`. |
| magic | VLSI layout system | `magic` (AUR) | Installed 2026-10-17 with `paru -S magic` (8.3.685-1). Pairs with `klayout`/`iverilog` in the EDA set. Binary `/usr/bin/magic`. Undo: `sudo pacman -Rns magic`. |
| PlasmaZones | Window tiling / autotiling for KWin | `plasmazones` (cachyos) | Installed 2026-10-17 at **3.4.19-1** and kept deliberately: on `kwin 6.8.0` it runs `active` + `enabled`, ships `kwin_effect_plasmazones.so`, and produces **zero** `Compositor bridge did not register` lines across a whole boot. Upstream is 3.5.1, but building it locally was rejected — it would add a rebuild-on-every-kwin-upgrade burden for a defect that does not reproduce. Re-test after any kwin major bump by counting `Compositor bridge did not register` over `journalctl --user -b`, and only then build 3.5.1. Undo: `sudo pacman -Rns plasmazones`. |

## Do not install MarkdownBlaze

An offline Markdown viewer (`bwets/MarkdownBlaze`, WebKitGTK/GTK3 + Photino) that
**does not render on this machine**. Installed and verified twice:

- **1.0.23** (2026-10-06): dies with `Gdk-Message: Error 71 (Protocol error)
  dispatching to Wayland display`, no document loaded.
- **1.0.26** (2026-10-17): opens a window and paints a black content area
  (~99.7% black, 6 distinct colours) with or without a document argument. It stays
  alive and logs **no error at all**, which is worse than the crash.

The workaround this repo used to document — `/usr/local/bin/MarkdownBlaze` running
`WEBKIT_DISABLE_DMABUF_RENDERER=1` — **has no effect on 1.0.26**: captures are
byte-identical with and without it, as are the Mesa-EGL-pin settings that
containered plasmashell on 2026-10-14.

Two traps, both worth keeping:

1. **The old acceptance test is obsolete.** "No `Protocol error` in the log" now
   passes on a completely blank window. The only valid check is a screen grab
   showing rendered content.
2. **Its SHA256SUMS prefixes `./arch/`**, so `sha256sum -c` verifies nothing —
   compare the hash by hand against the exact asset line.

Removed 2026-10-17 (snapper 36/37, 250 MiB reclaimed; the package alone pulled
`webkit2gtk-4.1`, `enchant`, `harfbuzz-icu`, `hyphen`, `libmanette`, `woff2`,
`xdg-dbus-proxy`). Do not reinstall it without first checking whether upstream has
fixed rendering on WebKitGTK + NVIDIA Wayland — verified by screen grab, never by
absence of an error string.
