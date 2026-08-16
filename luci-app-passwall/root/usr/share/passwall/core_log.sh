#!/bin/sh

CONFIG=passwall
CORE_LOG_FILE=/tmp/log/${CONFIG}_core.log
CORE_LOG_MAX_SIZE=1048576
CORE_LOG_KEEP_LINES=10000
CORE_LOG_LOCK=/tmp/lock/${CONFIG}_core_log_rotate.lock

trim_core_log() {
	[ -f "$CORE_LOG_FILE" ] || return
	[ "$(wc -c < "$CORE_LOG_FILE")" -gt "$CORE_LOG_MAX_SIZE" ] || return
	mkdir "$CORE_LOG_LOCK" 2>/dev/null || return
	if [ "$(wc -c < "$CORE_LOG_FILE")" -gt "$CORE_LOG_MAX_SIZE" ]; then
		tmp_file="${CORE_LOG_FILE}.tmp.$$"
		tail -n "$CORE_LOG_KEEP_LINES" "$CORE_LOG_FILE" > "$tmp_file" && mv -f "$tmp_file" "$CORE_LOG_FILE"
		rm -f "$tmp_file"
	fi
	rmdir "$CORE_LOG_LOCK" 2>/dev/null
}

core_type="$1"
flag="$2"
node="$3"
shift 3

[ "$flag" = "-" ] && flag=""
[ "$node" = "-" ] && node=""

remarks=$(uci -q get ${CONFIG}.${node}.remarks)
[ -n "$remarks" ] || remarks="${node:-$flag}"
[ -n "$remarks" ] || remarks="DNS"

case "$flag" in
	url_test_*) role="URLTest" ;;
	TCP|UDP|TCP_UDP) role="$flag" ;;
	"") role="DNS" ;;
	*)
		[ "$(uci -q get ${CONFIG}.${flag})" = "socks" ] && role="Socks" || role="ACL"
	;;
esac

case "$core_type" in
	sing-box) core_name="Sing-Box" ;;
	xray) core_name="Xray" ;;
	*) core_name="$core_type" ;;
esac

log_lines=0
"$@" 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
	printf '%s %s：%s ｜%s\n' "$core_name" "$role" "$remarks" "$line" >> "$CORE_LOG_FILE"
	log_lines=$((log_lines + 1))
	[ "$log_lines" -lt 100 ] || {
		trim_core_log
		log_lines=0
	}
done
trim_core_log
