QSC Stop Charging - Experimental legacy root edition
=====================================================

Requirements
------------
- Rooted Android 1.6 to 5.x (SuperSU or equivalent).
- BusyBox at /system/xbin/busybox or /system/bin/busybox.
- A writable kernel charging control. Most Android 1-4 devices lack one.

Installation
------------
1. Copy every file in this directory to the device, for example /data/local/tmp/qsc/.
2. Run as root:
   su -c sh /data/local/tmp/qsc/install.sh
3. The installer copies files to /data/qsc/ and creates BusyBox links in
   /data/qsc/bin/. It adds the 99qsc init.d entry if /system/etc/init.d exists.
   Otherwise it tries /system/etc/install-recovery.sh. If neither exists,
   configure SManager or similar software to run sh /data/qsc/boot.sh at boot.
4. Reboot.

Configuration and diagnostics
-----------------------------
Edit /data/qsc/config.conf. Settings reload every three seconds. The log is
/data/qsc/log.log. To create a diagnostic report:
   su -c sh /data/qsc/probe.sh

Check probe.log for a node marked writable:yes that accepts 0 and 1. If there
are no writable candidates, the kernel lacks a supported userspace control.
If the battery percentage keeps rising after a successful write, check the
other candidate nodes. Since v16, charge_control_limit appears in diagnostics
only. It controls maximum current. Since v17, log_enabled=0 stops new log
entries and log_max_lines sets the trim threshold (default 300, minimum 100).
Since v18, OPlus ColorOS mmi_charging_enable is supported (1 allows charging,
0 stops it).

Manual controls
---------------
Start:  su -c "sh /data/qsc/boot.sh"
Stop:   kill $(cat /data/qsc/qsc.pid)
Pause:  touch /data/qsc/off_qsc
Resume: rm -f /data/qsc/off_qsc

Uninstall
---------
su -c sh /data/local/tmp/qsc/uninstall.sh
