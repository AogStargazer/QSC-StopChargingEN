## v18 — 20261004 (versionCode 2026100422)

- Added support for the OnePlus/OPlus ColorOS charging control `mmi_charging_enable`: `1` allows charging and `0` stops it.
- Check both `/sys/class/oplus_chg/battery/` and `/sys/devices/virtual/oplus_chg/battery/`.
- Fixed boot-time charging-control detection on OnePlus Ace 2 Pro with ColorOS 16.
- Updated both the Android 5–17 module and the experimental legacy root edition.

See [CHANGELOG.md](CHANGELOG.md) for the full history.
