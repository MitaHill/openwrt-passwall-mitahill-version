#!/bin/sh

CONFIG=passwall
CORE_LOG_FILE=/tmp/log/${CONFIG}_core.log

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

"$@" 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
	printf '%s %s：%s ｜%s\n' "$core_name" "$role" "$remarks" "$line" >> "$CORE_LOG_FILE"
done
