#!/system/bin/sh
# Module action toggles QSC and displays its current status.
MODDIR=${0%/*}

if [ -f "$MODDIR/off_qsc" ]; then
	rm -f "$MODDIR/off_qsc"
	echo "QSC enabled."
else
	touch "$MODDIR/off_qsc"
	echo "QSC disabled. Run this action again to enable it."
fi

state="$(sed -n 's/^description=\[\([^]]*\)\].*/\1/p' "$MODDIR/module.prop" 2>/dev/null | head -n 1)"
[ -n "$state" ] || state="Unknown"
echo "Current status: $state"
grep -E '^(power_stop|power_start|power_stop_time|charge_full|power_reset)=' "$MODDIR/config.conf" 2>/dev/null
echo "--- Recent logs ---"
tail -n 6 "$MODDIR/log.log" 2>/dev/null