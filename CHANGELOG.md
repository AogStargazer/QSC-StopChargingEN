# Changelog

## v18 — 20261004 (versionCode 2026100422)

- Added support for the OnePlus/OPlus ColorOS charging control `mmi_charging_enable`: `1` allows charging and `0` stops it.
- Check both `/sys/class/oplus_chg/battery/` and `/sys/devices/virtual/oplus_chg/battery/`.
- Fixed boot-time charging-control detection on OnePlus Ace 2 Pro with ColorOS 16.
- Updated both the Android 5–17 module and the experimental legacy root edition.

## v17 — 20261004 (versionCode 2026100421)

- Added `log_enabled`. Set it to `0` to stop writing new entries. Existing logs are kept.
- Added `log_max_lines` to trim old entries automatically. Default: 300. Minimum: 100.
- Updated both editions.

## v16 — 20261004 (versionCode 2026100420)

- Fixed repeated write failures on Xiaomi 13 (fuxi, HyperOS 4, kernel 5.15, issue #4). Writing zero succeeded, but restoring the maximum failed.
- The kernel defines `charge_control_limit` as a maximum current, so it is now listed only by `probe.sh`. Dedicated controls such as `qcom-battery/input_suspend` handle charging. Xiaomi 17 Pro already uses MCA.
- Fixed both editions.

## v15 — 20261004 (versionCode 2026100419)

- Maintenance and optimization.

## v14 — 20261004 (versionCode 2026100418)

- Maintenance and optimization.

## v13 — 20261004 (versionCode 2026100417)

- Removed temperature-based charging thresholds.
- Replaced the two toggle scripts with a single root manager action.
- Removed obsolete temperature settings and variables including `TEMP_*`, `BAT_TEMP`, `cpu_log*`, and `log_log*`.

## v12 — 20261004 (versionCode 2026100416)

- Fixed frozen battery capacity readings on Unisoc `stop_charge` devices while the charging icon is hidden. This could prevent charging from resuming at `power_start`.
- Read capacity from sysfs during the simulated unplug state and update the system display. Reset the simulated state when charging resumes.

## v11 — 20261004 (versionCode 2026100415)

- Added `hide_charging_icon` with automatic defaults. On Unisoc `charger.0/stop_charge` devices, use the simulated unplug state to hide the icon until charging resumes.
- Fixed the charging icon on Tianyi No. 1 2021 (Unisoc UD710).

## v10 — 20261004 (versionCode 2026100414)

- On Xiaomi 17 Pro, use the `micharge` client for the `input_suspend` vote so the battery reports `DISCHARGING` and the icon disappears.
- The `qsc` client still controls charging through `charge_enable`. Tested on Xiaomi 17 Pro.

## v9 — 20261004 (versionCode 2026100413)

- Fixed Xiaomi 17 Pro continuing to charge after a successful `input_suspend` write.
- Use MCA `charge_enable`: `qsc all 0` stops charging and `qsc all 1` resumes it. Retain `input_suspend` as a supplementary control.

## v8 — 20261004 (versionCode 2026100412)

- Found that Xiaomi 17 Pro exposes `charge_control_limit` but does not implement its setter.
- Added initial MCA support through `/sys/class/xm_power/charger/charge_interface/input_suspend`.
- Updated the probe to list `xm_power` and follow symlinks for battery, USB, and wireless properties.
- Redmi Note 12 Turbo was confirmed working.

## v7 — 20261004 (versionCode 2026100411)

- Maintenance and optimization. Charging behavior matches v6.

## v6 — 20261004 (versionCode 2026100410)

- Tested `charge_control_limit` on Xiaomi 17 Pro, using zero for stop and `charge_control_limit_max` (16 on that device) for resume.
- The probe now checks file permission bits and lists battery, USB, and wireless attributes.
- Retained `charge_behaviour` support.

## v5 — 20261004 (versionCode 2026100409)

- Added initial support for standard `charge_behaviour` values `auto` and `inhibit-charge`, including a bracketed current value.
- Extended the probe to list `/sys/class`, charging directories, and relevant node permissions.
- Retained the Xiaomi 14 charge cycling fix.

## v4 — 20261004 (versionCode 2026100408)

- Fixed repeated charge cycling on Xiaomi 14 by skipping `handle_stop_charging`.
- Skip writes when the node already holds the requested value and log actual changes only. Tested on Xiaomi 14.

## v3 — 20261004 (versionCode 2026100407)

- Added `updateJson`, the update manifest, and in-manager release notes.
- Users on v1 or v2 must install v3 manually before updating from a root manager.

## v2 — 20261004 (versionCode 2026100406)

- Added Qualcomm `qcom-battery/input_suspend` support. Tested on Redmi K40 and Redmi K50U.
- Added `/sys/class/qcom-battery` to the probe and node scan.

## v1 — 20261004 (versionCode 2026100405)

- Initial release.
- Added a Magisk, KernelSU, ReSukiSU, and APatch installer, live configuration reload, local diagnostics, and an experimental legacy root edition for Android 1.6–5.x.
