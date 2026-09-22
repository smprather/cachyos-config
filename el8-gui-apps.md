# EL8-Built GUI Applications on CachyOS

Running enterprise-Linux (EL8/AlmaLinux 8) built binaries on this Arch-family
box. Companion to [foreign-binary-compat.md](foreign-binary-compat.md), which
covers the general library-gap pattern; this file covers the GUI application
saga (Firefox ESR + wezterm) from opencode sessions `ses_fab71abe...` /
`ses_fa26697...` (2026-08-30/09-01, engineering-loadout work). The loadout
project ships EL8-targeted bundles that must also run on this CachyOS host.

## The universal-host rule

Derived three separate times during debugging, now codified in the loadout
repo's AGENTS/ADDING_BINARIES:

1. **Keep the loader path inside the bundle.** `LD_LIBRARY_PATH="$libdir"`
   (the app's own lib dir) only. The host stack is authoritative for every
   soname the host supplies.
2. **Bundle only sonames the host cannot supply** — co-located next to the
   app's other libs, `RPATH=$ORIGIN`, resolved via the existing
   `LD_LIBRARY_PATH`. On Arch-family hosts these are typically:
   `libffi.so.6` (Arch ships .so.8), `libjpeg.so.62` (Arch ships turbo-3
   .so.8), `libssl.so.1.1`/`libcrypto.so.1.1` (Arch is OpenSSL 3 only),
   `libcrypt.so.1` (Arch ships .so.2 — EL8 libxcrypt).
3. **Never export `$prefix/lib64` (the bundled fallback lib set) into
   LD_LIBRARY_PATH for apps that spawn children** — it shadows the host's
   glib/pcre2/GTK with EL8-era copies and poisons everything downstream.
4. **Never ship distro-specific trust proxies** (see Firefox below).

Masking lesson: everything "worked" on the EL8 build box because the host
provided the missing paths natively. Every single failure below was invisible
on the build box and only appeared on CachyOS. Test universal bundles on a
foreign host, not the build host.

## Firefox ESR: three masking layers

The loadout bundle is an EL8 RPM-derived Firefox ESR. On CachyOS it failed
in three stacked ways, each hiding the next:

### Layer 1 — missing sonames

`XPCOMGlueLoad error ... libffi.so.6: cannot open shared object file` — the
bundle's `libxul.so` NEEDs `libffi.so.6`; Arch ships only `.so.8`. Fix:
bundle `libffi.so.6` and `libjpeg.so.62` co-located in the app lib dir
(same pattern the bundle already used for its NSS closure).

Pitfall that produced a false start: calling the inner binary directly
(`~/.local/lib/firefox/firefox-bin`) bypasses the launcher wrapper and its
`LD_LIBRARY_PATH`, reproducing exactly this error even on a fixed install.
Always launch via the wrapper, not the `-bin`.

### Layer 2 — lib64 shadowing (the wrong fix, reverted)

First attempt prepended `$prefix/lib64` (the gui_libs fallback set) to the
wrapper's `LD_LIBRARY_PATH`. That put EL8 GTK3 3.22, glib 2.56-era pcre2 and
friends ahead of the host's stack for firefox AND every child process it
spawned. Symptom: "runs but broken — accessing files out of its install
space", theme engines mismatching, dconf errors. The wezterm case below shows
the same poison pattern with exact symptoms. Reverted; co-located sonames
only.

### Layer 3 — the trust proxy (the real TLS killer)

After the sonames were fixed, every HTTPS site died with
`SEC_ERROR_UNKNOWN_ISSUER` behind an HSTS interstitial — fresh profile or
not, sandbox on or off. HTTP loaded fine (that split — HTTP works, TLS
doesn't — is the tell that trust, not networking, is broken).

Root cause: the bundle shipped EL8's `libnssckbi.so`, which is a **p11-kit
trust proxy** that reads the trust store from hardcoded EL8 paths
(`/etc/pki/ca-trust/...`). Those paths don't exist on Arch-family; the
proxy finds zero roots; every cert is an unknown issuer. On EL8 the same
library works, which is why the build box never caught it.

Two diagnosis traps that cost hours:

- An `LD_LIBRARY_PATH` override "testing the host's module" was silently
  ineffective — the wrapper prepends the bundle dir, so the bundled copy
  always won. When testing overrides of a wrapper's env, verify what actually
  loads (e.g. `ldd` under the wrapper's environment).
- Headless smoke tests under `env -i` were garbage on a Wayland session:
  stripping `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` makes the content process
  exit — the failures were broken repro, not the bug. Also, an older ESR
  build sharing a profile last written by a newer host Firefox
  (`~/.mozilla` is shared across builds) is unsupported and produces
  cert/HSTS weirdness — but the fresh-profile test ruled it out.

Fix: **stop shipping `libnssckbi.so` and `libnsssysinit.so` in the bundle**.
NSS then dlopens the host's trust module, which works on every mainstream
distro — and matches upstream: Mozilla's official Linux tarballs ship no
ckbi either. The build script now hard-fails if they reappear.

Verification that actually catches this class: fetch an HTTPS URL, not just
`--version`. A version-only smoke would have passed every broken iteration.

## wezterm: child-environment poisoning

wezterm's wrapper exported `LD_LIBRARY_PATH=$prefix/lib64` unconditionally
(a Mesa/GLVND fallback for GL-less farm nodes). wezterm is a terminal —
every process launched in it inherits that env. On CachyOS the bundled EL8
glib 2.56 shadowed the host's, so shells inside wezterm produced:

```text
flatpak: symbol lookup error: /usr/lib/libaccountsservice.so.1: undefined symbol: g_once_init_leave_pointer
/bin/grep: unrecognised compile-time option bit(s)     # EL8 libpcre2 shadowing host pcre2
```

Fix shape (now a shared wrapper block in the loadout repo,
`build/gui-wrapper-env.sh`): probe the host with `ldconfig` for
`libEGL.so.1` — host GL present → export nothing; GL-less host → keep the
Mesa fallback export. Env knobs (`LOADOUT_GUI_HOST_GL`, `LOADOUT_GUI_HOST_FONTCONFIG`,
`LOADOUT_GUI_LIB64`) allow per-host override without rebuilds.

Related wezterm issue: binaries NEED `libssl.so.1.1`/`libcrypto.so.1.1`
(EL8 everywhere, absent on Arch) — fixed by bundling those sonames.

Fontconfig warnings from a bundled EL8 fontconfig 2.13 parsing Arch's 2.18
`/etc/fonts` were fixed by `LD_PRELOAD`ing the host's `libfontconfig.so.1`
when present (pins that soname only).

## RPATH vs RUNPATH precedence (the "unbaking" lever)

- `patchelf --set-rpath` writes **RUNPATH**, and `LD_LIBRARY_PATH` outranks
  RUNPATH in the loader. Baked-in resolution stays the floor (direct exec
  still works) while env-driven adaptation can override per-host without
  rebuilds.
- Never `patchelf --force-rpath` on these payloads — old-style RPATH would
  invert the precedence and kill the escape hatch. Documented poison.

## Diagnostic quick checks

```bash
# What actually loads under the wrapper? (not plain ldd on the inner binary)
ldd "$(command -v BINARY)" | grep 'not found'

# Which ELF records the missing NEEDED entry?
readelf -d /path/to/lib.so | grep NEEDED

# Is the soname anywhere?
ldconfig -p | grep -E 'libffi|libjpeg.so.6|libssl.so.1|libcrypt'

# Is an env var shadowing the host? Check what a child shell sees:
echo "$LD_LIBRARY_PATH"

# Trust store sanity (proxy vs roots):
ls -la /usr/lib/libnssckbi.so /etc/pki/ca-trust 2>&1
```

## Build-box rule (cross-compile addendum)

No true cross-compile for glibc targets — the symbol-version floor is set at
link time by the target libc. Build natively in an EL8 userland. Current
mandate in the loadout repo (2026-09-01): the `loadout-build` docker image
(almalinux:8.10, gcc 8.5 + gcc-toolset-14, glibc 2.28, cmake/ninja baked in)
is THE build machine; clang-23 and other `~/.local` tools bind-mount in
read-only. Native CachyOS host is for everyday dev and T1/T2 only; all
payload mutation runs in the container. Reproducing an EL8 environment
one-off: `docker run --rm almalinux:8 bash`.