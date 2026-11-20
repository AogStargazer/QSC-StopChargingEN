#!/system/bin/sh
# QSC legacy root installer for Android 1.6–5.x (SuperSU/init.d).
# Usage: su -c sh /data/local/tmp/qsc/install.sh

SRC=${0%/*}
DST=/data/qsc

BB=""
for p in /system/xbin/busybox /system/bin/busybox /sbin/busybox /data/local/tmp/busybox; do
	[ -x "$p" ] && { BB="$p"; break; }
done
if [ -z "$BB" ]; then
	echo "BusyBox was not found. Install it at /system/xbin/busybox and rerun this script."
	exit 1
fi

mkdir -p "$DST" "$DST/bin"
cp "$SRC/qsc_daemon.sh" "$DST/qsc_daemon.sh" 2>/dev/null
cp "$SRC/probe.sh" "$DST/probe.sh" 2>/dev/null
cp "$SRC/config.conf" "$DST/config.conf" 2>/dev/null
cp "$SRC/boot.sh" "$DST/boot.sh" 2>/dev/null
chmod 0755 "$DST/qsc_daemon.sh" "$DST/probe.sh" "$DST/boot.sh" 2>/dev/null
chmod 0644 "$DST/config.conf" 2>/dev/null

for a in awk sed grep wc head tr date tail find printf id; do
	rm -f "$DST/bin/$a" 2>/dev/null
	ln -s "$BB" "$DST/bin/$a" 2>/dev/null || "$BB" ln -s "$BB" "$DST/bin/$a" 2>/dev/null
done

INITD=/system/etc/init.d
if [ -d "$INITD" ]; then
	mount -o rw,remount /system 2>/dev/null
	"$BB" mount -o rw,remount /system 2>/dev/null
	if cp "$SRC/99qsc" "$INITD/99qsc" 2>/dev/null; then
		chmod 0755 "$INITD/99qsc" 2>/dev/null
		echo "Installed init.d entry: $INITD/99qsc"
	else
		echo "Could not write the init.d entry. Copy 99qsc to $INITD/ manually."
	fi
else
	IR=/system/etc/install-recovery.sh
	if [ -f "$IR" ]; then
		mount -o rw,remount /system 2>/dev/null
		if "$BB" grep -q qsc "$IR" 2>/dev/null; then
			echo "install-recovery.sh already contains the QSC startup entry."
		else
			echo "[ -x /data/qsc/boot.sh ] && /data/qsc/boot.sh &" >> "$IR" 2>/dev/null
			echo "Added the startup entry to $IR."
		fi
	else
		echo "Neither init.d nor install-recovery.sh was found."
		echo "Use your ROM startup feature or a tool such as SManager to run this at boot: sh /data/qsc/boot.sh"
	fi
fi

if [ -f "$DST/qsc.pid" ]; then
	oldpid="$(cat "$DST/qsc.pid" 2>/dev/null)"
	if [ -n "$oldpid" ]; then
		kill "$oldpid" 2>/dev/null
	fi
fi
( PATH="$DST/bin:$PATH" sh "$DST/qsc_daemon.sh" >/dev/null 2>&1 & )

echo ""
echo "Installation complete. Configuration: $DST/config.conf  Log: $DST/log.log"
echo "Diagnostics: su -c sh $DST/probe.sh"
