#!/system/bin/sh
# QSC legacy startup script for init.d, SManager, and similar tools.
DST=/data/qsc
[ -f "$DST/qsc_daemon.sh" ] || exit 0
PATH="$DST/bin:$PATH"
export PATH
( sh "$DST/qsc_daemon.sh" >/dev/null 2>&1 & )
