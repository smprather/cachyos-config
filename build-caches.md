# Build caches: ccache, sccache, and what Go does by itself

Operational state for compile-time caching on this box. Read this before changing
compiler-cache settings, and before concluding "the cache isn't working" — the two
false negatives at the bottom of this file are the usual reasons.

Set up 2026-10-06. Full change log entry (commands, snapper numbers, rollback) is in
`customizations.md` under that date.

## Desired end state (current, verified)

| Toolchain | Mechanism | Config | Verified |
| --- | --- | --- | --- |
| C/C++ through **makepkg** | `ccache` in `BUILDENV` -> makepkg prepends `/usr/lib/ccache/bin` to `PATH` | `/etc/makepkg.conf` | miss -> **hit** across clean trees (tiny probe package, built twice) |
| C/C++ in **own projects** (cmake) | `-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache` | per project | miss -> **hit** after wiping the build dir |
| **clang / clang++** | same ccache, either direct or via the shipped symlinks | as above | 2 cacheable calls -> 1 hit; via PATH -> hit |
| **Rust** (`cargo`) | `rustc-wrapper = "sccache"` | `~/.cargo/config.toml` | `--release` rebuild after `cargo clean`: **5 Rust hits**, 1.96 s -> 0.33 s |
| **Go** | nothing to wire — `GOCACHE` is built into the toolchain | none | cold 1.867 s -> warm 0.089 s (~21x); no wrapper |
| **Linking** (C/C++ and Rust) | `mold` via `-fuse-ld=mold`; cargo wired in `~/.cargo/config.toml` | see "Linkers" below | ~3x faster than bfd on a 101-object link; binaries verified to run |

Installed for this: `ccache 4.14-1` and `sccache 0.18.0-1.1` (+`hiredis`) for caching, plus
`mold 3.0.0`, `ninja 1.13.2` and `hyperfine 1.21.0` as the speed/measurement layer.
`ccache` is in `extra`; `sccache`, `mold`, `ninja` and `hyperfine` come from
`cachyos-extra-v3` (x86-64-v3 builds).

## The files

    /etc/makepkg.conf                     BUILDENV=(!distcc color ccache check !sign)
    /etc/makepkg.conf.bak-ccache-20261006 the one-line-change backup
    ~/.config/ccache/ccache.conf          max_size = 8.0G
    ~/.config/sccache/config              TOML: [cache.disk] dir, size = 4294967296
    ~/.cargo/config.toml                  [build] rustc-wrapper = "sccache"

None of the three user files has snapper coverage — they are user-scope, so the
rollback is deleting them (see the end of this file). That is also why the exact
contents matter more than usual here.

## Why makepkg's integration is PATH-based (and what follows from it)

makepkg does not set `CC`. `/usr/share/makepkg/buildenv/compiler.sh` implements
`buildenv_ccache()` by prepending `/usr/lib/ccache/bin` to `PATH`, and that directory
holds symlinks for `cc c++ gcc g++ clang clang++` plus the triplet names
(`x86_64-pc-linux-gnu-gcc`). Consequences:

- Any build system *inside* a makepkg build is covered for free — cmake, meson,
  autotools and plain make all just run `cc`/`gcc`, which now resolve through ccache.
  No per-package flags needed.
- `$CC` is **empty** in a PKGBUILD build function. Writing `$CC file.c -o prog` fails
  with `file.c: command not found` (this happened while verifying). Use `cc`, or set
  `CC="ccache gcc"` explicitly.
- A build that hardcodes `/usr/bin/gcc` bypasses the masking entirely.

For builds **outside** makepkg the same masking can be opted into per shell with
`PATH="/usr/lib/ccache/bin:$PATH"`. It is deliberately **not** enabled globally: it
changes every compiler invocation in every shell, including things that inspect their
compiler, and this repo prefers explicit layers over ambient magic.

## Rust: the dev-profile trap

`--release` builds cache cleanly. **Dev-profile builds do not**, and this is the single
most likely reason to think sccache is broken: cargo's dev profile compiles with
`-C incremental`, and sccache refuses to cache incremental compilations. Measured here:
a dev build produced `Compile requests 6 / executed 0 / hits 0` — requests received,
nothing cacheable.

`CARGO_INCREMENTAL=0` opts dev builds into caching at the cost of slower iterative
rebuilds in one directory. That trade is left to the user; it is not set globally, and
the reasoning is in the config file's comments. `ccache 4.14` can also wrap rustc
(`rustc-wrapper = "ccache"`) if sccache ever misbehaves.

## Go: nothing to install

The toolchain ships a content-addressed build/test cache (`GOCACHE=~/.cache/go-build`)
that covers both dependencies and std packages, so unlike C/C++ and Rust there is no
wrapper to add. `GOMODCACHE=~/go/pkg/mod` holds downloaded module sources. If a Go
build feels slow, look at `-p`/`GOMAXPROCS` and the cache, not at ccache.

## Two false negatives worth remembering

1. **`cc prog.c -o prog` is not cacheable.** ccache declines any invocation that also
   links ("called for link") and files it under uncacheable calls. It looks exactly
   like ccache ignoring you. Real builds compile with `-c` and link separately;
   compile-only invocations are what the cache serves. A probe that does
   compile+link in one line will always report 0 cacheable calls.
2. **sccache's config is TOML, not JSON.** `~/.config/sccache/config` written as JSON
   fails every start with `TOML parse error ... expected key`. The schema, discovered
   from the binary's own error messages: top level accepts
   `cache`, `dist`, `server_startup_timeout_ms`, `basedirs`, `client_side_mode`;
   `[cache]` accepts `azure|disk|gcs|gha|memcached|redis|s3|webdav|oss|cos|multilevel`;
   `[cache.disk]` accepts `dir`, `size`, `preprocessor_cache_mode`, `rw_mode`.
   `size` is **bytes**. Verify any edit with `sccache --stop-server; sccache --show-stats`
   — the header prints the resolved location and max size.

## Disk budget

Both caches are on `/` (48G free when this was written):

    ccache   8.0G   (~/.cache/ccache)     default was 5.0G
    sccache  4 GiB  (~/.cache/sccache)    default was 10 GiB

Both evict LRU when over cap, so these are budget knobs, not correctness knobs — raise
`max_size` / `size` if free space allows and hit rates matter more than headroom. The
8.0G/4GiB split is arbitrary; what matters is that neither can grow unbounded on a box
that is already 80% full.

ccache's `sloppiness` is deliberately left empty. Setting it trades correctness for hit
rate and is the wrong default for a machine whose builds are meant to be trustworthy.

## Linkers: mold is installed, wired, and the only LTO-safe choice

Nothing above caches *linking*, so the linker is the other half of build time. Measured
on this box (2026-10-06, hyperfine, 5 runs each, 101 objects, 24 threads):

    stripped        bfd 39.7 ms | lld 17.4 ms | mold 23.3 ms
    with -g         bfd 120.0 ms | mold 38.1 ms | lld 40.2 ms      (16 MB binary)

Both are ~3x faster than bfd; lld wins the tiny optimized link, mold wins the debug-info
case. **mold is the default anyway, because lld is not safe here.**
`g++ -flto=auto -fuse-ld=lld` fails outright:

    ld.lld: error: undefined symbol: main

lld cannot consume GCC LTO objects. mold loads the GCC LTO plugin and links them
correctly — both produce a working binary, and mold's was the smaller one. `lto` is
enabled in makepkg's OPTIONS, so this is not a corner case on this machine. Do not
"optimize" this to lld on the strength of the 17.4 ms number alone.

Wiring:

    ~/.cargo/config.toml   [target.x86_64-unknown-linux-gnu]
                           rustflags = ["-C", "link-arg=-fuse-ld=mold"]
    cmake projects         -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold  (or LINKER: per target)
    ad-hoc                 g++ -fuse-ld=mold ...

Changing `rustflags` invalidates cargo fingerprints: every Rust project recompiles once.

`/etc/makepkg.conf` is deliberately left on the default linker so system and AUR packages
link exactly as Arch expects. To opt in per build: `LDFLAGS+=" -fuse-ld=mold"` (mold, not
lld, for the LTO reason). All three linkers were checked against the full makepkg LDFLAGS
set including `-Wl,--sort-common` and `-Wl,-z,pack-relative-relocs`, and all accept it.

`ninja` is installed but is **not** a claimed speedup: a full 100-TU cmake rebuild with
`-j 24` measured **3.23 s (ninja) vs 3.30 s (make)** — a tie. It is here because meson
requires it and most tooling assumes it. Do **not** set `CMAKE_GENERATOR=Ninja` globally:
makepkg builds inherit the environment, and a PKGBUILD that calls `make` explicitly would
then fail for want of a Makefile.

## Not enabled (deliberate)

- **Global PATH masking** (`/usr/lib/ccache/bin`) and **`CARGO_INCREMENTAL=0`** — both
  described above.
- **A changed `makepkg` linker** — opt in per build instead, as above.
- **`libeatmydata`** (disables fsync during builds): a genuine speedup for I/O-heavy
  builds, but it trades crash safety during package installation. Not installed on purpose.

## Rollback

    # makepkg: restore the one line (or the whole file)
    sudo cp -a /etc/makepkg.conf.bak-ccache-20261006 /etc/makepkg.conf

    # user configs: remove them; the caches themselves can stay or go
    rm ~/.config/ccache/ccache.conf        # or: ccache -C  (clears cache contents)
    rm ~/.config/sccache/config            # sccache --stop-server  to stop the daemon
    rm ~/.cargo/config.toml                # this file only sets rustc-wrapper

    # packages (hiredis is only there for sccache)
    sudo pacman -Rns ccache sccache         # the caches
    sudo pacman -Rns mold ninja hyperfine   # linker, build system, benchmark tool

    # linker wiring: delete the [target.x86_64-unknown-linux-gnu] rustflags block in
    # ~/.cargo/config.toml (next build of each project recompiles once)
