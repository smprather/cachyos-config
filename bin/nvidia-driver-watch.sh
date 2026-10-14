#!/usr/bin/env bash
# nvidia-driver-watch — tell me when a newer NVIDIA driver is available in the repos.
#
# Why this exists (2026-10-14): the NVIDIA driver is the last unresolved suspect for the
# plasmashell freeze — its EGL layer is in the captured backtrace (see plasmashell-wedge.md).
# Testing a candidate driver means *staying* on it for a few days; without this, "pinned for
# a test" silently becomes "pinned forever".
#
# Installed as a user timer (weekly). History:  journalctl --user -t nvidia-driver-watch
#
# The packaging trap this lives alongside: linux-cachyos-nvidia-open depends on
# linux-cachyos=<exact> AND nvidia-utils=<exact>; linux-cachyos-lts-nvidia-open does the same
# for the LTS pair. So the prebuilt-module packages can only be held by holding both kernels
# too. nvidia-open-dkms is the pin-free alternative: hold the driver, keep the kernels moving.
set -u

say() { logger -t nvidia-driver-watch -- "$*"; printf '%s\n' "$*"; }

installed="$(pacman -Q nvidia-utils 2>/dev/null | awk '{print $2}')"
[ -n "$installed" ] || { say "nvidia-utils is not installed"; exit 0; }

avail=""; src=""

# checkupdates downloads fresh databases into a throwaway dbpath: no system mutation, and no
# partial-upgrade hazard. Output format: "<name> <oldver> -> <newver>", and it prints nothing
# at all when nothing is upgradable.
if command -v checkupdates >/dev/null 2>&1; then
    cu="$(checkupdates 2>/dev/null || true)"
    if [ -n "$cu" ]; then
        avail="$(printf '%s\n' "$cu" | awk '$1=="nvidia-utils"{ print ($3=="->" ? $4 : $2) }' | head -1)"
        src="fresh repo query (checkupdates)"
    else
        src="fresh repo query (checkupdates: nothing upgradable)"
    fi
fi

# Fall back to the locally cached sync DB. Two caveats, both worth knowing: it goes stale
# between `pacman -Sy` runs, and pacman's IgnorePkg can hide a held package from the
# upgrade comparison entirely — which is precisely the case a held driver creates.
if [ -z "$avail" ]; then
    avail="$(pacman -Si nvidia-utils 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}')"
    [ -n "$src" ] || src="local sync DB (can be stale; IgnorePkg hides held packages)"
fi

[ -n "$avail" ] || { say "could not determine the available nvidia-utils version"; exit 0; }

if [ "$avail" = "$installed" ]; then
    say "nvidia-utils $installed is current — source: $src"
    exit 0
fi

say "nvidia-utils: installed $installed, repos offer $avail — a different driver is available"
say "(source: $src)"
say "Do not take it blindly: a driver generation change is what this machine's panel freeze"
say "followed. Test order, from plasmashell-wedge.md: 1) fresh login; 2) the running"
say "plasmashell must map libnvidia-eglcore (GPU rendering) and must not spin; 3) suspend and"
say "resume once, then check for 'NVRM: GPU0 kgmmuInvalidateTlb_GM107' lines; 4) leave it a"
say "day — the wedge watchdog captures the EGL spin automatically if it happens."
if grep -qE '^\s*IgnorePkg.*nvidia' /etc/pacman.conf 2>/dev/null; then
    say "A hold is currently in place, so pacman will not list it. To take this update:"
    say "  sudo sed -i '/^\\s*IgnorePkg/d' /etc/pacman.conf && sudo pacman -Syu"
fi
exit 0
