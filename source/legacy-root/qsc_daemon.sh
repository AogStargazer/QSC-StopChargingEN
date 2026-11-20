#!/system/bin/sh
# QSC Stop Charging daemon for legacy root (Android 1.6–5.x, SuperSU/init.d).
# Use Toybox-compatible parsing and rescan sysfs periodically after boot.
# Reload config.conf every three seconds.

MODDIR=${0%/*}
MCA_IF="/sys/class/xm_power/charger/charge_interface/input_suspend"
MCA_EN_IF="/sys/class/xm_power/charger/charge_interface/charge_enable"
PIDFILE="$MODDIR/qsc.pid"
LOG="$MODDIR/log.log"
NOW_C="$MODDIR/now_c"
POWER_SWITCH="$MODDIR/power_switch"
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

# ---------------- Single-instance guard ----------------
if [ -f "$PIDFILE" ]; then
	old_pid="$(cat "$PIDFILE" 2>/dev/null)"
	if [ -n "$old_pid" ] && [ "$old_pid" != "$$" ] && kill -0 "$old_pid" 2>/dev/null; then
		if [ -r "/proc/$old_pid/cmdline" ] && tr '\0' ' ' < "/proc/$old_pid/cmdline" 2>/dev/null | grep -q "qsc_daemon"; then
			exit 0
		fi
	fi
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
trap 'rm -f "$PIDFILE"; exit 0' TERM INT HUP

# ---------------- Configuration loading ----------------
conf_get() {
	v="$(sed -n "s/^[[:space:]]*$1=//p" "$MODDIR/config.conf" 2>/dev/null | head -n 1 | sed 's/[^0-9].*//')"
	case "$v" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s' "$v"
}

conf_get_or() {
	conf_get "$1" || printf '%s' "$2"
}

load_config() {
	POWER_STOP="$(conf_get_or power_stop 100)"
	POWER_START="$(conf_get_or power_start 95)"
	POWER_STOP_TIME="$(conf_get_or power_stop_time 3)"
	CHARGE_FULL="$(conf_get_or charge_full 0)"
	POWER_RESET="$(conf_get_or power_reset 0)"
	LOG_ENABLED="$(conf_get_or log_enabled 1)"
	case "$LOG_ENABLED" in
		0|1) ;;
		*) LOG_ENABLED=1 ;;
	esac
	LOG_MAX_LINES="$(conf_get_or log_max_lines 300)"
	case "$LOG_MAX_LINES" in
		''|*[!0-9]*) LOG_MAX_LINES=300 ;;
	esac
	[ "$LOG_MAX_LINES" -lt 100 ] && LOG_MAX_LINES=100
}

log_line() {
	[ "$LOG_ENABLED" = "0" ] && return
	echo "$(date +%F_%T) $*" >> "$LOG"
}

CONFIG_SIG=""

update_config_log() {
	new_sig="$POWER_STOP|$POWER_START|$POWER_STOP_TIME|$CHARGE_FULL|$POWER_RESET"
	[ "$new_sig" = "$CONFIG_SIG" ] && return
	if [ -n "$CONFIG_SIG" ]; then
		log_line "Configuration reloaded: stop=$POWER_STOP resume=$POWER_START delay=$POWER_STOP_TIME charge_full=$CHARGE_FULL power_reset=$POWER_RESET"
	fi
	CONFIG_SIG="$new_sig"
}

rotate_log() {
	[ "$LOG_ENABLED" = "0" ] && return
	[ -f "$LOG" ] || return
	lines="$(wc -l < "$LOG" 2>/dev/null)"
	case "$lines" in
		''|*[!0-9]*) return ;;
	esac
	max="$LOG_MAX_LINES"
	case "$max" in
		''|*[!0-9]*) max=300 ;;
	esac
	[ "$max" -lt 100 ] && max=100
	if [ "$lines" -gt "$max" ]; then
		keep=$((max * 2 / 3))
		[ "$keep" -lt 50 ] && keep=50
		delete=$((lines - keep))
		[ "$delete" -gt 0 ] && sed -i "1,${delete}d" "$LOG" 2>/dev/null
	fi
}

set_state() {
	cur="$(sed -n 's/^description=\[\([^]]*\)\].*/\1/p' "$MODDIR/module.prop" 2>/dev/null | head -n 1)"
	[ "$cur" = "$1" ] && return
	sed -i "s|^description=\[[^]]*\]|description=[$1]|" "$MODDIR/module.prop" 2>/dev/null
	chmod 0644 "$MODDIR/module.prop" 2>/dev/null
}

# ---------------- Battery status ----------------
read_battery() {
	BAT_LEVEL=""
	BAT_STATUS=""
	BAT_POWERED=""
	BAT_CHARGING=0

	dbat="$(dumpsys battery 2>/dev/null)"
	BAT_LEVEL="$(printf '%s\n' "$dbat" | sed -n 's/^[[:space:]]*level: *\([0-9][0-9]*\).*/\1/p' | head -n 1)"
	BAT_STATUS="$(printf '%s\n' "$dbat" | sed -n 's/^[[:space:]]*status: *\([0-9][0-9]*\).*/\1/p' | head -n 1)"
	case "$dbat" in
		*"AC powered: true"*|*"USB powered: true"*|*"Wireless powered: true"*|*"Dock powered: true"*)
			BAT_POWERED=1 ;;
	esac

	# Fall back to sysfs if dumpsys fails.
	if [ -z "$BAT_LEVEL" ] && [ -r /sys/class/power_supply/battery/capacity ]; then
		BAT_LEVEL="$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)"
		case "$BAT_LEVEL" in ''|*[!0-9]*) BAT_LEVEL="" ;; esac
	fi

	if [ -z "$BAT_STATUS" ] && [ -r /sys/class/power_supply/battery/status ]; then
		BAT_STATUS="$(cat /sys/class/power_supply/battery/status 2>/dev/null)"
	fi
	if [ -z "$BAT_POWERED" ]; then
		for on in /sys/class/power_supply/*/online; do
			[ -r "$on" ] || continue
			if [ "$(cat "$on" 2>/dev/null)" = "1" ]; then
				BAT_POWERED=1
				break
			fi
		done
	fi

	case "$BAT_STATUS" in
		2|5|Charging|Full)
			BAT_CHARGING=1 ;;
		'')
			[ "$BAT_POWERED" = "1" ] && BAT_CHARGING=1 ;;
	esac
}

# ---------------- Charging controls ----------------
SEEN=""
SWITCH_LIST=""

append_entry() {
	# $1=path $2=resume value $3=stop value
	[ -n "$1" ] || return
	case " $SEEN " in
		*" $1 "*) return ;;
	esac
	[ -e "$1" ] || return
	SEEN="$SEEN $1"
	SWITCH_LIST="$SWITCH_LIST $1,start=$2,stop=$3"
}

build_switch_list() {
	SEEN=""
	SWITCH_LIST=""

	# Prefer custom controls from the legacy list_switch.
	if [ -f "$MODDIR/list_switch" ]; then
		while IFS= read -r line; do
			case "$line" in
				*,start=*,stop=*)
					p="$(printf '%s\n' "$line" | sed -n 's/,start=.*//p')"
					s="$(printf '%s\n' "$line" | sed -n 's/.*,start=//;s/,stop=.*//p')"
					t="$(printf '%s\n' "$line" | sed -n 's/.*,stop=//p')"
					append_entry "$p" "$s" "$t"
					;;
			esac
		done < "$MODDIR/list_switch"
	fi

	# Built-in controls, including common Android 14–17 paths.
	append_entry /sys/class/power_supply/battery/batt_slate_mode 0 1
	append_entry /sys/class/power_supply/battery/store_mode 0 1
	append_entry /sys/class/power_supply/battery/input_suspend 0 1
	append_entry /sys/class/power_supply/battery/charging_enabled 1 0
	append_entry /sys/class/power_supply/battery/charging_enable 1 0
	append_entry /sys/class/power_supply/battery/charge_enable 1 0
	append_entry /sys/class/power_supply/battery/charge_disable 0 1
	append_entry /sys/class/power_supply/usb/input_suspend 0 1
	append_entry /sys/class/power_supply/idt/pin_enabled 1 0
	append_entry /sys/class/qcom-battery/input_suspend 0 1
	# OnePlus/OPlus ColorOS: mmi_charging_enable 1 allows charging and 0 stops it.
	append_entry /sys/class/oplus_chg/battery/mmi_charging_enable 1 0
	append_entry /sys/devices/virtual/oplus_chg/battery/mmi_charging_enable 1 0
	append_entry /sys/class/power_supply/battery/charge_behaviour auto inhibit-charge
	# The charge_control_limit ABI controls maximum charging current.
	# Some devices accept zero but fail to restore the maximum (issue #4). List it in probe.sh only.
	append_entry /sys/kernel/debug/google_charger/chg_suspend 0 1
	append_entry /sys/kernel/debug/google_charger/chg_mode 1 0
	append_entry /proc/driver/charger_limit_enable 0 1
	append_entry /proc/driver/charger_limit 100 1
	append_entry /proc/mtk_battery_cmd/current_cmd 0_0 0_1
	append_entry /proc/mtk_battery_cmd/en_power_path 1 0
	append_entry /proc/mtk_charger/en_power_path 1 0

	# Scan for charging controls that accept safe binary writes.
	for f in /sys/class/power_supply/*/* /sys/class/power_supply/*/*/* /sys/class/qcom-battery/*; do
		[ -f "$f" ] || continue
		n="${f##*/}"
		# Skip handle_stop_charging on devices like Xiaomi 14 because repeat writes can cycle charging.
		[ "$n" = "handle_stop_charging" ] && continue
		# Skip charge_control_limit as described above.
		[ "$n" = "charge_control_limit" ] && continue
		case "$n" in
			*charge_behaviour*)
				append_entry "$f" auto inhibit-charge ;;
			*input_suspend*|*charge*disable*|*disable*charge*|*stop_charge*|*stop_charging*|*charging_suspend*|*slate_mode*|*store_mode*)
				append_entry "$f" 0 1 ;;
			*charging_enabled*|*charging_enable*|*enable_charge*|*enable_charging*)
				append_entry "$f" 1 0 ;;
		esac
	done

	# Record detected nodes for diagnostics.
	: > "$MODDIR/qsc_nodes.log"
	for e in $SWITCH_LIST; do
		echo "${e%%,*}" >> "$MODDIR/qsc_nodes.log"
	done
}

set_switch_value() {
	# $1=entry $2=start|stop
	ent="$1"
	side="$2"
	path="${ent%%,*}"
	rest="${ent#*,}"
	case "$side" in
		start)
			val="${rest#start=}"
			val="${val%%,stop=*}"
			;;
		*)
			val="${rest#*,stop=}"
			;;
	esac
	val="$(printf '%s' "$val" | tr '_' ' ')"
	[ -e "$path" ] || return 1
	cur="$(cat "$path" 2>/dev/null | tr -d '\r\n')"
	[ "$cur" = "$val" ] && return 2
	case "$cur" in
		*"[$val]"*) return 2 ;;
	esac
	chmod 0644 "$path" 2>/dev/null
	printf '%s\n' "$val" > "$path" 2>/dev/null || return 1
	return 0
}

apply_side() {
	side="$1"
	ok=""
	fails=""
	for ent in $SWITCH_LIST; do
		set_switch_value "$ent" "$side"
		rc=$?
		if [ "$rc" = "0" ]; then
			ok="$ok ${ent%%,*}"
		elif [ "$rc" != "2" ]; then
			fails="$fails ${ent%%,*}"
		fi
	done
	if [ -n "$fails" ]; then
		if [ ! -f "$MODDIR/.fail_warn" ]; then
			log_line "Failed to write these charging controls. Check SELinux and permissions: $fails"
			touch "$MODDIR/.fail_warn"
		fi
	else
		rm -f "$MODDIR/.fail_warn"
	fi
	printf '%s' "$ok"
	if [ -n "$ok" ]; then
		return 0
	fi
	if [ -n "$fails" ]; then
		return 1
	fi
	return 2
}

hide_icon_enabled() {
	case "$(conf_get hide_charging_icon)" in
		1) return 0 ;;
		0) return 1 ;;
	esac
	case " $SWITCH_LIST " in
		*"/charger.0/stop_charge,start="*) return 0 ;;
	esac
	return 1
}

qsc_power_stop() {
	ok="$(apply_side stop)"
	rc=$?
	if [ -e "$MCA_EN_IF" ]; then
		mca_en_cur="$(cat "$MCA_EN_IF" 2>/dev/null | tr -d '\r')"
		case "$mca_en_cur" in
			*"qsc 0"*) ;;
			*)
				if printf 'qsc all 0\n' > "$MCA_EN_IF" 2>/dev/null; then
					ok="$ok $MCA_EN_IF"
					rc=0
				fi ;;
		esac
	fi
	if [ -e "$MCA_IF" ]; then
		mca_cur="$(cat "$MCA_IF" 2>/dev/null | tr -d '\r')"
		case "$mca_cur" in
			*"micharge 1"*) ;;
			*)
				if printf 'micharge all 1\n' > "$MCA_IF" 2>/dev/null; then
					ok="$ok $MCA_IF"
					rc=0
				fi ;;
		esac
	fi
	if hide_icon_enabled; then
		dumpsys battery unplug >/dev/null 2>&1
	fi
	if [ "$rc" = "0" ]; then
		NODE_WARN=0
		log_line "Set charging controls to stop: $ok"
		return 0
	fi
	if [ "$rc" = "1" ]; then
		return 1
	fi
	if [ -z "$SWITCH_LIST" ] && [ ! -e "$MCA_IF" ] && [ ! -e "$MCA_EN_IF" ] && [ "$NODE_WARN" = "0" ]; then
		NODE_WARN=1
		log_line "No usable charging controls found. Run probe.sh to check device support."
	fi
	return 2
}

qsc_power_start() {
	ok="$(apply_side start)"
	rc=$?
	if [ -e "$MCA_EN_IF" ]; then
		mca_en_cur="$(cat "$MCA_EN_IF" 2>/dev/null | tr -d '\r')"
		case "$mca_en_cur" in
			*"qsc 1"*) ;;
			*)
				if printf 'qsc all 1\n' > "$MCA_EN_IF" 2>/dev/null; then
					ok="$ok $MCA_EN_IF"
					rc=0
				fi ;;
		esac
	fi
	if [ -e "$MCA_IF" ]; then
		mca_cur="$(cat "$MCA_IF" 2>/dev/null | tr -d '\r')"
		case "$mca_cur" in
			*"micharge 0"*) ;;
			*)
				if printf 'micharge all 0\n' > "$MCA_IF" 2>/dev/null; then
					ok="$ok $MCA_IF"
					rc=0
				fi ;;
		esac
	fi
	dumpsys battery reset >/dev/null 2>&1
	if [ "$rc" = "0" ]; then
		NODE_WARN=0
		log_line "Set charging controls to resume: $ok"
		return 0
	fi
	return $rc
}

do_power_reset() {
	sleep 2
	qsc_power_stop
	sleep 1
	qsc_power_start
}

# ---------------- Initialization ----------------
dumpsys battery reset >/dev/null 2>&1
rm -f "$NOW_C"
load_config
update_config_log
log_line "Started: stop=$POWER_STOP resume=$POWER_START delay=$POWER_STOP_TIME charge_full=$CHARGE_FULL power_reset=$POWER_RESET"
build_switch_list
[ -n "$SWITCH_LIST" ] || log_line "No charging controls found at boot. Scanning will continue."

LOOP=0
NODE_WARN=0

# ---------------- Main loop ----------------
while true; do
	LOOP="$((LOOP + 1))"
	load_config
	update_config_log
	read_battery

	if [ -z "$BAT_LEVEL" ]; then
		sleep 3
		continue
	fi

	# Rescan every 20 iterations (about 60 seconds) for nodes that appear after boot.
	if [ "$((LOOP % 20))" = "1" ]; then
		build_switch_list
	fi

	off_qsc=0
	if [ -f "$MODDIR/off_qsc" ] || [ -f "$MODDIR/disable" ]; then
		off_qsc=1
		POWER_STOP_NOW=110
		POWER_START_NOW=105
		if [ ! -f "$MODDIR/off_d" ]; then
			set_state "Module disabled"
			touch "$MODDIR/off_d"
			log_line "Module paused. Remove off_qsc or run the module action again to resume."
			rm -f "$NOW_C" "$MODDIR/power_on" "$MODDIR/power_off"
		fi
	else
		POWER_STOP_NOW="$POWER_STOP"
		POWER_START_NOW="$POWER_START"
		if [ -f "$MODDIR/off_d" ]; then
			rm -f "$MODDIR/off_d"
			log_line "Module enabled again."
		fi
	fi

	switch_stop_mode=0
	full_log=0
	reset_log=0

	if [ "$BAT_CHARGING" = "1" ]; then
		rotate_log

		# Check the cutoff threshold.
		if [ "$POWER_STOP_NOW" -gt "$POWER_START_NOW" ] && [ "$BAT_LEVEL" -ge "$POWER_STOP_NOW" ]; then
			if [ "$CHARGE_FULL" = "1" ]; then
				if [ "$BAT_LEVEL" = "100" ] && [ "$POWER_STOP_NOW" = "100" ]; then
					if [ "$BAT_STATUS" = "5" ]; then
						rm -f "$NOW_C"
						log_line "Battery at ${BAT_LEVEL}%. Full-charge cutoff triggered."
					else
						full_log=1
						now_current="$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)"
						if [ -z "$now_current" ]; then
							now_current="$(cat /sys/class/power_supply/battery/current_avg 2>/dev/null)"
						fi
						if [ -n "$now_current" ]; then
							now_current="$(printf '%s' "$now_current" | sed -n 's/-//g;p')"
							case "$now_current" in
								''|*[!0-9]*) ;;
								*)
									if [ "$now_current" -lt 100000 ]; then
										echo "$now_current" >> "$NOW_C"
									else
										rm -f "$NOW_C"
									fi
									now_current_n=0
									if [ -f "$NOW_C" ]; then
										now_current_n="$(wc -l < "$NOW_C" 2>/dev/null)"
									fi
									case "$now_current_n" in
										''|*[!0-9]*) now_current_n=0 ;;
									esac
									if [ "$now_current_n" -ge 3 ]; then
										full_log=0
										rm -f "$NOW_C"
										log_line "Battery at ${BAT_LEVEL}%. Waiting for full-charge cutoff. Current: $now_current"
									fi
									;;
							esac
						fi
					fi
				else
					full_log=0
				fi
			fi
			if [ "$full_log" = "0" ]; then
				switch_stop_mode=1
			fi
		fi

		# Apply the charging cutoff.
		if [ "$switch_stop_mode" = "1" ]; then
			if [ "$CHARGE_FULL" != "1" ] && [ ! -f "$POWER_SWITCH" ]; then
				if [ "$POWER_STOP_TIME" -gt "0" ]; then
					log_line "Battery at ${BAT_LEVEL}%. Charging for another $POWER_STOP_TIME seconds."
					sleep "$POWER_STOP_TIME"
				fi
			fi
			sleep 3
			qsc_power_stop
			rc=$?
			touch "$POWER_SWITCH"
			if [ "$rc" = "0" ]; then
				log_line "Battery at ${BAT_LEVEL}%. Charging stopped."
			fi
		else
			reset_log=1
		fi

		if [ ! -f "$MODDIR/power_on" ] && [ "$off_qsc" != "1" ]; then
			set_state "Charging"
			rm -f "$MODDIR/power_off"
			touch "$MODDIR/power_on"
			if [ "$POWER_RESET" = "1" ] && [ "$reset_log" = "1" ]; then
				do_power_reset
				log_line "Battery at ${BAT_LEVEL}%. Triggering automatic reconnect."
			fi
		fi
	else
		if [ ! -f "$MODDIR/power_off" ] && [ "$off_qsc" != "1" ]; then
			set_state "Not charging"
			rm -f "$NOW_C"
			rm -f "$MODDIR/power_on"
			touch "$MODDIR/power_off"
		fi
	fi

	# Resume charging.
	if [ -f "$POWER_SWITCH" ]; then
		if [ "$BAT_LEVEL" -le "$POWER_START_NOW" ]; then
			sleep 3
			qsc_power_start
			rc=$?
			rm -f "$POWER_SWITCH"
			if [ "$rc" = "0" ]; then
				log_line "Battery at ${BAT_LEVEL}%. Charging resumed."
			fi
		fi
	fi

	sleep 3
done
#version=2026100404
# ##
