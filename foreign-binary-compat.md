# Foreign Binary Compatibility

Notes on running binaries built for other distributions on CachyOS. Recorded
2026-08-29 while debugging a fresh CachyOS install.

## What CachyOS does not have

Arch and CachyOS deliberately omit several libraries that enterprise Linux
distributions ship by default. Binaries built on RHEL, AlmaLinux, or CentOS 8
frequently depend on them:

| Library | Status on CachyOS |
|---|---|
| `libcrypto.so.1.1`, `libssl.so.1.1` | Absent. Arch carries only OpenSSL 3.x. There is no `openssl-1.1` package in any configured repository. OpenSSL 1.1 has been end-of-life and unpatched since September 2023. |
| `libselinux.so.1` | Absent. Arch does not use SELinux at all. |
| `libffi.so.6` | Absent. Arch carries a newer soname. |
| `libxml2.so.2` older soname | Version mismatch against the EL8 build. |

## Symptom

A binary fails to start with a missing shared library, or `ldd` reports
`not found` for one of the libraries above. Example:

```text
tmux: error while loading shared libraries: libcrypto.so.1.1: cannot open shared object file: No such file or directory
```

`ldd` on the binary showed the dependency arriving indirectly, through a bundled
library rather than through `tmux` itself:

```text
libevent_core-2.1.so.6 => /home/mylesp/.local/lib64/libevent_core-2.1.so.6
libcrypto.so.1.1 => not found
```

`readelf -d` on the bundled `libevent_core-2.1.so.6` confirmed the
`NEEDED  libcrypto.so.1.1` entry originated there.

## Root cause pattern

The bundled library had been lifted directly from the EL8 system RPM. Red Hat
builds libevent with `--enable-openssl`, which drags in a `libcrypto.so.1.1`
dependency that EL8 always satisfies and Arch never can.

This is a general pattern: an enterprise distribution enables an optional
feature at build time, the resulting shared object records a `NEEDED` entry for
a library that only that distribution ships, and the binary becomes unusable on
Arch even though the feature itself is never exercised.

## Fix approach

The reliable fix is to find out *why* the dependency is linked and rebuild
without it, rather than bundling the missing library.

For the libevent case: libevent 2.1.8-stable was rebuilt from source with
`--disable-openssl`, which removed the dependency entirely. Verification
covered the soname (unchanged), the symbols the consuming binary needs (all
still exported), the glibc floor (within the EL8 target), and a real smoke test
on this CachyOS box with no `libcrypto` present anywhere on the system.

Bundling an end-of-life TLS stack instead would work but is a genuine security
tradeoff, not a neutral choice.

## Diagnostic commands

```bash
# What does the binary actually need at runtime?
ldd "$(command -v BINARY)"

# Which shared object records the missing dependency?
readelf -d /path/to/lib.so | grep NEEDED

# Where does the loader search?
readelf -d /path/to/binary | grep RUNPATH

# Is the library available anywhere on this system?
ldconfig -p | grep -E 'libssl.so.1|libcrypto.so.1|libselinux|libffi'

# Is there a package for it at all?
pacman -Ss openssl-1.1
```

## Reproducing an EL8 environment

A container is the clean way to inspect or rebuild against the reference
distribution without installing anything on the host:

```bash
docker run --rm almalinux:8 bash -c 'cat /etc/os-release | head -3'
```

Mount a work directory into the container to build there and copy the result
out. Building natively on CachyOS and shipping the result to EL8 targets does
not work, and it silently produces subtly different artifacts.
