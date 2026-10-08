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
| MarkdownBlaze | Offline Markdown viewer (read-only) | upstream Arch package, installed with `pacman -U` | WebKitGTK/GTK3 + Photino. **Requires the wrapper `/usr/local/bin/MarkdownBlaze`** — without `WEBKIT_DISABLE_DMABUF_RENDERER=1` it never renders on this NVIDIA Wayland box (Gdk Error 71, no document loaded). No AUR package exists; the shipped desktop entry uses a bare `Exec=MarkdownBlaze`, so the wrapper covers menu and MIME launches too. Listed with the other unowned shims in `system-inventory.md`. |
