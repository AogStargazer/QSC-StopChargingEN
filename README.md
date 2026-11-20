# QSC Stop Charging

QSC controls charging thresholds on rooted Android devices. It stops charging at the configured upper threshold and resumes charging at the lower threshold. The daemon reloads settings every three seconds. Configuration and logs stay on the device. Your root manager can check for updates through `updateJson`.

<img src="https://img.shields.io/badge/Android-5.0%20~%2017-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
<img src="https://img.shields.io/badge/Magisk-%E2%89%A520.4-00AF9A?style=for-the-badge" />
<img src="https://img.shields.io/badge/KernelSU%20%7C%20APatch-Supported-4EAA25?style=for-the-badge" />
<img src="https://img.shields.io/badge/Shell-POSIX-89E051?style=for-the-badge&logo=gnubash&logoColor=black" />
<img src="https://img.shields.io/badge/Network-None-2088FF?style=for-the-badge" />
<img src="https://img.shields.io/badge/License-MIT-F472B6?style=for-the-badge" />

## Tested devices

| Device | Charging control and notes |
|---|---|
| Redmi K40, Redmi K50U | Qualcomm `qcom-battery/input_suspend` |
| Xiaomi 14 | Qualcomm `input_suspend`. Repeated charge cycling fixed in v4. |
| Xiaomi 13 (fuxi) | Qualcomm `input_suspend`. v16 addresses failed restoration of `charge_control_limit` reported in issue #4. |
| Redmi Note 12 Turbo | Confirmed by a user. |
| Xiaomi 17 Pro | MCA `xm_power` uses `charge_enable` to stop charging and `input_suspend` to update the charging indicator. Confirmed in v10. |
| Tianyi No. 1 2021 (TYH211U) | Unisoc UD710 uses `charger.0/stop_charge`. v12 reads sysfs battery capacity when the simulated unplug state freezes the Android battery reading. |

Other Qualcomm devices may work if they expose a writable `/sys/class/qcom-battery/input_suspend` node.

## Installation

### Android 5.0–17

1. Download the [modern module ZIP](dist/QSC定量停充_安卓5-17适配版_20261004.zip).
2. Install it using Magisk, KernelSU, ReSukiSU, SukiSU, or APatch as supported on your Android version. On older Android versions, use Magisk 20.4 or later.
3. Reboot so `service.sh` starts.
4. Edit `/data/adb/modules/QuantitativeStopCharging_switch/config.conf`. The same directory contains `log.log`.

### Android 1.6–5.x

Use the [experimental legacy ZIP](dist/QSC定量停充_安卓1-5遗留root实验版.zip) on rooted devices with BusyBox and a writable charging control. Run `probe.sh` first and look for `writable:yes`.

Copy all files from `source/legacy-root/` to the device, then run the installer as root.

```sh
su -c sh /data/local/tmp/qsc/install.sh
```

The installer copies the files to `/data/qsc/` and tries to install an init.d entry. On devices without init.d, use SManager or a similar tool to run `sh /data/qsc/boot.sh` at boot. Reboot. Settings and logs are in `/data/qsc/config.conf` and `/data/qsc/log.log`.

## Configuration

| Setting | Default | Description |
|---|---:|---|
| `power_stop` | `100` | Stop charging at or above this percentage. Must exceed `power_start`. Set to `110` to disable the cutoff. |
| `power_start` | `95` | Resume charging at or below this percentage. A gap of 5–10 points is suggested. |
| `power_stop_time` | `3` | Seconds to continue charging before cutoff. Use a positive integer. A running countdown cannot be canceled. |
| `charge_full` | `0` | Set to `1` to wait for current to drop below 100 mA after reaching 100%. This takes precedence over the cutoff delay. |
| `power_reset` | `0` | Set to `1` to simulate a reconnect once per charge session for devices that need it to enter fast charging. |
| `log_enabled` | `1` | Set to `0` to stop appending to the existing log. |
| `log_max_lines` | `300` | Trim the oldest lines past this limit, retaining about two-thirds. Minimum 100. |
| `hide_charging_icon` | Auto | Set to `1` or `0` to override the default. Unisoc `stop_charge` devices hide the icon by default. |

For a quick test, set `power_stop=80` and `power_start=70`.

## Toggle and diagnostics

In the modern build, run the root manager's module action to toggle QSC and show its status, settings, and recent logs. The `off_qsc` file in the module directory pauses it. Remove the file to resume. In the legacy build, use `/data/qsc/off_qsc`. Start the legacy daemon with `su -c "sh /data/qsc/boot.sh"` and stop it with `kill $(cat /data/qsc/qsc.pid)`.

```sh
# Modern module
su -c sh /data/adb/modules/QuantitativeStopCharging_switch/probe.sh

# Legacy installation
su -c sh /data/qsc/probe.sh
```

The probe records Android version, device model, battery state, and candidate charging controls in `probe.log`.

| Symptom | Check |
|---|---|
| Module is paused | Remove `off_qsc` or toggle it from the module action. |
| No charging controls found | Look for writable nodes in `probe.log`. Your kernel may omit them. |
| Battery percentage keeps rising after a successful write | The selected control may have no effect on charging. Inspect other candidates. |
| Node write fails | Check permissions and SELinux. Look for `writable:no`. |
| Battery percentage stays flat after cutoff | This is expected when charging stops. |
| No log appears | Verify that you rebooted, enabled the module and logging, and reached the cutoff threshold. |

For an issue report, attach `probe.log`, relevant lines from `log.log`, and the device model, Android version, root manager, and steps to reproduce.

## Release history

| Version | Main change |
|---|---|
| v18 | Added OPlus `mmi_charging_enable` support. |
| v17 | Added logging controls and automatic log trimming. |
| v16 | Stopped writing `charge_control_limit` as a charging switch. |
| v15, v14 | Maintenance and optimization. |
| v13 | Removed thermal controls and combined the toggle scripts into one manager action. |
| v12 | Fixed frozen battery readings after the charging icon was hidden. |
| v11 | Hid the charging icon on supported Unisoc `stop_charge` devices. |
| v10 | Fixed the charging icon remaining visible after cutoff on Xiaomi 17 Pro. |
| v9 | Added direct charge control through MCA `charge_enable`. |
| v8 | Added experimental MCA `input_suspend` support. |
| v7 | Maintenance update. |
| v6 | Tried `charge_control_limit` for cutoff. |
| v5 | Expanded node scanning and added `charge_behaviour` support. |
| v4 | Fixed repeated charging and cutoff on Xiaomi 14. |
| v3 | Added updates from the root manager. |
| v2 | Added Qualcomm support tested on Redmi K40 and K50U. |
| v1 | Initial release. |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes and [RELEASING.md](RELEASING.md) for release steps. The `dist/` directory holds packaged builds. The modern and legacy sources are in `source/qsc-a5-17/` and `source/legacy-root/`.

## Credits

Based on the original QSC release on Coolapk by 大头顶 (20231204). This community adaptation adds newer and legacy Android support and local diagnostics. See [assets/donate](assets/donate) for optional support links.

## License

[MIT](LICENSE) © 2026 L0NE-6
