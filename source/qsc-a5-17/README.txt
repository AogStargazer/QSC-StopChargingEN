QSC Stop Charging - Android 5-17 module
=======================================

Requirements
------------
Use Magisk 20.4+ on Android 5-11. On Android 12-17, Magisk, KernelSU,
ReSukiSU, SukiSU, and APatch are supported. Use the experimental legacy root
edition for pre-Magisk devices. Both editions require a kernel that exposes a
writable charging control.

Installation
------------
Install the ZIP in your root manager and reboot. The standard Magisk
update-binary also supports compatible recovery installations. The installer
provides fallbacks for set_perm and ui_print, and the daemon can use BusyBox
when the device's Toybox lacks a required tool.

Edit /data/adb/modules/QuantitativeStopCharging_switch/config.conf. The
daemon reloads it every three seconds. The same directory contains log.log.
The default stop threshold is 100%. For a quick test, set power_stop=80 and
power_start=70. The root manager can check for releases using updateJson.

Controls and diagnostics
------------------------
Run the module action in your root manager to toggle QSC and print status
and recent logs. Creating off_qsc in the module directory pauses QSC.
Deleting it resumes normal operation.

If charging does not stop, run the hardware probe as root:

   su -c sh /data/adb/modules/QuantitativeStopCharging_switch/probe.sh

Check probe.log for a writable charging control. If log.log shows a
successful write and the battery level keeps rising, inspect other controls.
A write failure can indicate an SELinux or permission restriction.
If no log exists, verify that the device rebooted, QSC is enabled, logging
is enabled, and the configured threshold has been reached.

The daemon rescans local charging controls approximately every 60 seconds.
It supports Qualcomm qcom-battery/input_suspend, selected Xiaomi MCA
controls, Unisoc stop_charge, and OPlus mmi_charging_enable. The probe also
reports charge_control_limit. QSC stopped writing that maximum-current
control in v16. Logging can be disabled or trimmed through config.conf.

Uninstall
---------
Uninstall from the root manager. The uninstall script stops the daemon and
restores common charging controls. Reboot if charging remains suspended.
