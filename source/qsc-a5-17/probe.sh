#!/system/bin/sh
# QSC diagnostics for Android 14–17. Run if charging does not stop and attach probe.log to your report.
# Supports Magisk, KernelSU, ReSukiSU, and APatch.
MODDIR=${0%/*}
# ---------------- Android 5–11 compatibility: BusyBox fallback ----------------
BUSYBOX=""
for p in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /system/xbin/busybox /system/bin/busybox /sbin/busybox; do
	[ -x "$p" ] && { BUSYBOX="$p"; break; }
done
if [ -n "$BUSYBOX" ]; then
	BB_BIN="$MODDIR/.bbin"
	mkdir -p "$BB_BIN" 2>/dev/null
	for a in awk sed grep wc head tr date tail find printf; do
		if ! command -v "$a" >/dev/null 2>&1; then
			rm -f "$BB_BIN/$a" 2>/dev/null
			ln -s "$BUSYBOX" "$BB_BIN/$a" 2>/dev/null
		fi
	done
	PATH="$BB_BIN:$PATH"
fi
OUT="$MODDIR/probe.log"

{
	echo "==== QSC probe $(date +%F_%T) ===="
	echo "release=$(getprop ro.build.version.release) sdk=$(getprop ro.build.version.sdk)"
	echo "brand=$(getprop ro.product.brand) model=$(getprop ro.product.model)"
	echo "cpu=$(grep -i Hardware /proc/cpuinfo 2>/dev/null | head -n 1)"
	echo "$(getprop ro.build.display.id)"
	echo "uid=$(id -u 2>/dev/null) selinux=$(getenforce 2>/dev/null)"
	echo "magisk=$(magisk -v 2>/dev/null)"
	echo "ksud=$(ksud -V 2>/dev/null || ksud --version 2>/dev/null)"
	echo "resukisu=$(resukisu -V 2>/dev/null)"
	echo ""
	echo "---------- dumpsys battery ----------"
	dumpsys battery 2>&1
	echo ""
	echo "---------- Candidate charging controls ----------"
	CANDIDATES="/sys/class/power_supply/battery/batt_slate_mode
/sys/class/power_supply/battery/store_mode
/sys/class/power_supply/battery/input_suspend
/sys/class/power_supply/battery/charging_enabled
/sys/class/power_supply/battery/charging_enable
/sys/class/power_supply/battery/charge_enable
/sys/class/power_supply/battery/charge_disable
/sys/class/power_supply/usb/input_suspend
/sys/class/power_supply/idt/pin_enabled
/sys/class/qcom-battery/input_suspend
/sys/class/xm_power/charger/charge_interface/input_suspend
/sys/class/xm_power/charger/charge_interface/charge_enable
/sys/class/xm_power/charger/charge_interface/suspend_status
/sys/class/power_supply/battery/charge_behaviour
/sys/class/power_supply/battery/charge_control_limit
/sys/class/power_supply/battery/charge_control_limit_max
/sys/class/power_supply/battery/charge_control_end_threshold
/sys/class/power_supply/battery/constant_charge_current_max
/sys/class/power_supply/battery/input_current_limit
/sys/class/power_supply/battery/battery_charging_enabled
/sys/kernel/debug/google_charger/chg_suspend
/sys/kernel/debug/google_charger/chg_mode
/proc/driver/charger_limit_enable
/proc/driver/charger_limit
/proc/mtk_battery_cmd/current_cmd
/proc/mtk_battery_cmd/en_power_path
/proc/mtk_charger/en_power_path"
	for f in $CANDIDATES; do
		if [ -e "$f" ]; then
			lsline="$(ls -l "$f" 2>/dev/null)"
			w="no"
			case "$lsline" in -*w*) w="yes" ;; esac
			echo "$f = $(cat "$f" 2>/dev/null) | writable:$w | $lsline"
		fi
	done
	echo ""
	echo "---------- Automatic scan ----------"
	find /sys/class/power_supply /sys/class/qcom-battery /sys/kernel/debug -maxdepth 3 -type f 2>/dev/null | grep -E -i 'input_suspend|charge.*(enable|disable|stop|suspend)|(enable|disable|stop).*charge|slate_mode|store_mode|charge_behaviour|charge_control|current_limit' | while IFS= read -r f; do
		lsline="$(ls -l "$f" 2>/dev/null)"
		w="no"
		case "$lsline" in -*w*) w="yes" ;; esac
		echo "$f = $(cat "$f" 2>/dev/null) | writable:$w | $lsline"
	done
	echo ""
	echo "---------- Extended scan ----------"
	echo "== Top-level /sys/class entries =="
	ls -1 /sys/class 2>/dev/null
	for d in /sys/class/power_supply /sys/class/qcom-battery /sys/class/charger /sys/class/mi_charger /sys/class/xiaomi_charger /sys/devices/virtual/power_supply; do
		[ -d "$d" ] || continue
		echo "== $d =="
		find "$d" -maxdepth 3 2>/dev/null
	done
	for d in /sys/class/power_supply/battery /sys/class/power_supply/usb /sys/class/power_supply/wireless; do
		[ -d "$d" ] || continue
		echo "== $d properties =="
		ls -la "$d/" 2>/dev/null
	done
	for d in /sys/class/xm_power /sys/class/xm_power/charger; do
		[ -d "$d" ] || continue
		echo "== $d properties =="
		ls -la "$d/" 2>/dev/null
	done
	echo "== Matching nodes and write status =="
	find /sys/class /sys/devices/virtual -maxdepth 5 -type f 2>/dev/null | grep -E -i 'charge|batt|suspend|slate|store|behaviour|behavior' | while IFS= read -r f; do
		lsline="$(ls -l "$f" 2>/dev/null)"
		w="no"
		case "$lsline" in -*w*) w="yes" ;; esac
		echo "$f = $(cat "$f" 2>/dev/null) | writable:$w | $lsline"
	done
	echo ""
	echo "---------- qsc_nodes.log ----------"
	cat "$MODDIR/qsc_nodes.log" 2>/dev/null
	echo ""
	echo "---------- list_switch ----------"
	cat "$MODDIR/list_switch" 2>/dev/null
	echo ""
	echo "---------- Recent log.log entries ----------"
	tail -n 80 "$MODDIR/log.log" 2>/dev/null
} > "$OUT" 2>&1

cat "$OUT"
echo ""
echo "Saved to: $OUT"
