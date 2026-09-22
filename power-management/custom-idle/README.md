# Custom idle and suspend implementation

This directory preserves the exact custom idle/suspend implementation found on
the machine on 2026-09-04. It is **not currently trusted or enabled**. Keep it
as the starting point for the planned diagnosis and repair; do not deploy it as
the current power policy without reviewing the known state below.

## Preserved files

| Repository file | Installed source | SHA-256 |
| --- | --- | --- |
| `custom-idle.sh` | `~/.local/bin/custom-idle.sh` | `d5a524507b6df22376120ae28bc2db774a0ae3f356af41d9d7698eacf49c88c9` |
| `custom-idle.service` | `~/.config/systemd/user/custom-idle.service` | `2744b00c9c1dbae9c224fa89346bc7e835c6f2269927955685efc05eb1c9944b` |
| `suspend_if_low_cpu.sh` | `~/.config/hypr/scripts/suspend_if_low_cpu.sh` | `a004cfbfd9bfa4201ae406b5cc590ea9ceacc8e08c19d712c1693e12ab956b2e` |
| `hypridle.conf` | `~/.config/hypr/hypridle.conf` | `46e887e413257d3d1f1ccdd20250dd0e8eb4623be29df3904f3a624660b54c79` |

Verify the preserved copies with:

```bash
./tests/check-power-policy.sh
```

## Known state

- `custom-idle.service` was enabled and running, but its behavior was reported
  as probably not working correctly. It was disabled rather than deleted so it
  can be diagnosed later.
- `custom-idle.sh` mixes Hyprland-only DPMS calls with loginctl idle detection
  and CPU/agent-aware suspend policy. Do not assume its “DE-agnostic” comment is
  accurate.
- The preserved `hypridle.conf` still contains both a five-minute DPMS listener
  and a 30-minute call to `suspend_if_low_cpu.sh`. Its service must remain
  disabled until that configuration is deliberately repaired.
- GNOME currently owns monitor blanking, while suspension is manual only. See
  [the power policy](../../power-idle-suspend.md).

The intended future work is to test idle detection, separate monitor DPMS from
suspend policy, and make the custom service explicitly aware of the active
desktop before re-enabling it.
