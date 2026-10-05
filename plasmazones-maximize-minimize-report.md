# Posted: PlasmaZones bug report — maximize lost across a minimize cycle

**Posted 2026-10-03** as a Discussion (the repo disables blank issues and routes
bug reports to `discussions/new?category=bug-reports`):

https://github.com/fuddlesworth/PlasmaZones/discussions/1131

Category: Bug Reports · author: smprather · reproduced on PlasmaZones 3.4.19 /
Plasma 6.7.5. Nothing was anonymized: the IDs and screen EDID string are real.
The test window was a throwaway `alacritty --class pzprobe` window, killed
afterwards, so `pzprobe` is a synthetic app id and not a real application.

The text below is exactly what was posted. Summary of the finding and the
workarounds: [desktop-environments.md](desktop-environments.md).

---

### Description

In snapping mode, a zone-snapped window that is **maximized → minimized → un-minimized** comes back **in its zone, un-maximized**. The maximize is silently dropped. It is deterministic on a snapped window; a floating window is unaffected.

The cause is the snap-mode minimize-float cycle. Minimizing a snapped window floats it so its zone slot is freed — the daemon logs the zone it is holding on to — and un-minimizing restores the window to that saved zone. PlasmaZones saves the **zone** across the cycle but captures no **maximize** state, the restore is an unconditional snap placement, and every snap placement deliberately clears KWin's maximize bit (a surviving maximize would fight the zone rect — `demoteMaximizeForSnapPlacement`, from #1036).

Journal excerpt, verbatim, from a throwaway `alacritty` window started with `--class pzprobe` and snapped to the right zone with `Control.snapWindowToZone`. Effect stream (`journalctl --user -t kwin_wayland`), prefixes shortened, timestamps kept:

```text
11:04:01 kwin_wayland  Maximize interception: declining "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" — not a tiled window, KWin keeps the request
11:04:03 kwin_wayland  Snap: window minimized (after debounce), floating: "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" on "Dell Inc.:DELL S3425DW:825314902"
11:04:06 kwin_wayland  Snap: window unminimized, unfloating: "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" on "Dell Inc.:DELL S3425DW:825314902"
11:04:06 kwin_wayland  slotApplyGeometryRequested: "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" (live: "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" ) geo: QRect(1721,0 1719x1394) zoneId: "{05b9766b-d2a1-49ab-94fa-35d3e31f33f9}" screen: "Dell Inc.:DELL S3425DW:825314902" floating: false currentFrame: KWin::RectF(0,0 3440x1394)
11:04:06 kwin_wayland  Demoting KWin maximize for snap placement of "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" into QRect(1721,0 1719x1394)
```

Daemon stream (`journalctl --user -u plasmazones.service`):

```text
11:04:03 plasmazonesd   setWindowFloatingForScreen: windowId= "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" floating= true screen= "Dell Inc.:DELL S3425DW:825314902"
11:04:03 plasmazonesd   Saved pre-float zones for "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" -> QList("{05b9766b-d2a1-49ab-94fa-35d3e31f33f9}") screen: "Dell Inc.:DELL S3425DW:825314902"
11:04:06 plasmazonesd   setWindowFloatingForScreen: windowId= "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" floating= false screen= "Dell Inc.:DELL S3425DW:825314902"
11:04:06 plasmazonesd   commitSnap: "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba" zones= QList("{05b9766b-d2a1-49ab-94fa-35d3e31f33f9}") screen= "Dell Inc.:DELL S3425DW:825314902" intent= user
```

Note `currentFrame: KWin::RectF(0,0 3440x1394)` in the fourth line: at the moment PlasmaZones decides to re-apply the zone rect, the window is still **maximized**, and that placement is what demotes it.

Two further observations:

**The state has nowhere to live.** `org.plasmazones.Control.getFullState` returns window records carrying only `windowId`, `screenId`, `zoneId` and `isFloating`:

```json
{"isFloating": false, "screenId": "Dell Inc.:DELL S3425DW:825314902",
 "windowId": "pzprobe|bdfda3fc-2d48-4e81-a46d-06a287fc64ba",
 "zoneId": "{05b9766b-d2a1-49ab-94fa-35d3e31f33f9}"}
```

There is no maximize dimension on the snap record.

**Snapping has no maximize interception.** The effect declines it explicitly (`Maximize interception: declining … — not a tiled window, KWin keeps the request`, first line above). Per-mode maximize is implemented for scrolling only, and `docs/maximize-intercept-plan.md` records snapping's answer as an open question — "snapping has no such state today".

**Control case, which isolates the cause.** An identical window that is *floating* rather than zone-snapped, so PlasmaZones never minimize-floats it, went through the same three steps and came back **still maximized**. Being snapped into a zone is what triggers the loss.

Measured with `qdbus6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo <uuid>` (`maximizeHorizontal` / `maximizeVertical` are `2` / `1` when fully maximized):

| step | geometry | maximize H/V |
| --- | --- | --- |
| snapped, free | 400,400 600x500 | 0 / 0 |
| after maximize | 0,0 3440x1394 | 2 / 1 |
| after minimize | 0,0 3440x1394 | 2 / 1 (minimized) |
| after un-minimize | 1721,0 1719x1394 | **0 / 0** |
| *floating control:* after un-minimize | 0,0 3440x1394 | **2 / 1** |

I found no setting that controls this and no opt-out from minimize-float, and `v3.4.19` is the newest tag, so there is no upgrade path. I searched existing discussions and issues before posting; the nearest is #1036, which introduced the demote.

### Expected Behavior

Un-minimizing should restore the window to the state it was in immediately before it was minimized — including **maximized**, if that is what it was.

FancyZones is the reference here and does not behave this way: it acts as if there is **always an implicit full-screen zone available**. A maximized window is a placement like any other, so minimize/restore is a round trip that returns it maximized. KWin's own behaviour, with no zone manager involved, is the same.

To be clear, the snapping-mode minimize-float cycle itself looks right — freeing the zone while the window is minimized is deliberate and worth keeping. It just needs to carry the maximize state along with the zone, so the un-minimize restore puts the window back the way it was.

Related: if snapping grew a real per-mode maximize — the pre-maximize slot `docs/maximize-intercept-plan.md` describes as missing — then "maximize a snapped window" would have a defined meaning and this round trip would have something to restore to. As it stands, maximize on a snapped window is passed through to KWin and then quietly discarded by the next placement.

### Steps to Reproduce

1. Snapping mode on a screen with a multi-zone layout (I used the built-in `Columns (2)`, 2 zones, otherwise default settings).
2. Put a window into a zone — drag it there, or scope it deterministically with `qdbus6 org.plasmazones /PlasmaZones org.plasmazones.Control.snapWindowToZone <windowId> 2 <screenId>`.
3. Maximize the window (titlebar button or `Meta+PgUp`).
4. Minimize it.
5. Un-minimize it.

**Result:** the window returns to its zone rectangle, un-maximized.
**Expected:** it returns maximized.

For the deterministic, mouse-free variant used for the measurements above: spawn a throwaway window (`alacritty --class pzprobe -e sleep 600`), snap it with `Control.snapWindowToZone`, then drive maximize / minimize / un-minimize from a KWin script (`org.kde.kwin.Scripting.loadScript`, then `run()` on `/Scripting/Script<id>`; the maximize call is `window.setMaximize(true, true)`, with the window matched by `resourceClass`). Observe after each step with `org.kde.KWin.getWindowInfo <uuid>`.

Reproduces with default settings.

### PlasmaZones Version

```text
plasmazones-editor 3.4.19
plasmazonesd 3.4.19
```

CachyOS package `plasmazones 3.4.19-1`. `v3.4.19` is the newest upstream tag.

### Display Server

Wayland

### Desktop Environment

Plasma 6.7.5 (`kwin 6.7.5`, `plasma-desktop 6.7.5`, `plasma-workspace 6.7.5`)

### Distribution

CachyOS (Arch-based)

### Checklist

- [x] I searched existing discussions and issues
- [x] I can reproduce this with default settings
