#!/system/bin/sh
# QSC legacy uninstaller.
DST=/data/qsc
dumpsys battery reset >/dev/null 2>&1

if [ -f "$DST/qsc.pid" ]; then
	oldpid="$(cat "$DST/qsc.pid" 2>/dev/null)"
	if [ -n "$oldpid" ]; then
		kill "$oldpid" 2>/dev/null
	fi
fi

mount -o rw,remount /system 2>/dev/null
rm -f /system/etc/init.d/99qsc 2>/dev/null
rm -rf "$DST"
echo "QSC legacy edition uninstalled. Reboot to apply."
