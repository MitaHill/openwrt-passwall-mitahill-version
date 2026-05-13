#!/bin/sh

. /usr/share/passwall/utils.sh

test_url() {
	local url=$1
	local try=1
	[ -n "$2" ] && try=$2
	local timeout=2
	[ -n "$3" ] && timeout=$3
	local extra_params=$4
	curl --help all | grep "\-\-retry-all-errors" > /dev/null
	[ $? == 0 ] && extra_params="--retry-all-errors ${extra_params}"
	status=$(/usr/bin/curl -I -o /dev/null -skL $extra_params --connect-timeout ${timeout} --retry ${try} -w %{http_code} "$url")
	case "$status" in
		204|\
		200)
			status=200
		;;
	esac
	echo $status
}

test_proxy() {
	result=0
	status=$(test_url "https://www.google.com/generate_204" ${retry_num} ${connect_timeout})
	if [ "$status" = "200" ]; then
		result=0
	else
		status2=$(test_url "https://www.baidu.com" ${retry_num} ${connect_timeout})
		if [ "$status2" = "200" ]; then
			result=1
		else
			result=2
			ping -c 3 -W 1 223.5.5.5 > /dev/null 2>&1
			[ $? -eq 0 ] && {
				result=1
			}
		fi
	fi
	echo $result
}

url_test_node_cleanup() {
	local node_id="$1"
	[ -n "$node_id" ] || return 0
	local pid_file="/tmp/etc/${CONFIG}/url_test_${node_id}_plugin.pid"
	[ -s "$pid_file" ] && kill -9 "$(head -n 1 "$pid_file")" >/dev/null 2>&1
	pgrep -af "url_test_${node_id}" | awk '! /test\.sh/{print $1}' | xargs kill -9 >/dev/null 2>&1
	rm -rf /tmp/etc/${CONFIG}/*url_test_${node_id}*.*
}

url_test_once() {
	local curlx="$1"
	local probe_url="$2"
	local connect_timeout="${3:-3}"
	local max_time="${4:-5}"
	curl --connect-timeout "$connect_timeout" --max-time "$max_time" -o /dev/null -I -skL -w "%{http_code}:%{time_pretransfer}" -x "$curlx" "$probe_url"
}

url_test_average() {
	local curlx="$1"
	local probe_url="$2"
	local i result code use_time
	local total="0"
	local count=0

	for i in 1 2 3 4 5; do
		result=$(url_test_once "$curlx" "$probe_url" 3 5)
		code="${result%%:*}"
		use_time="${result#*:}"
		case "$code:$use_time" in
			[1-9]*:[0-9]*|[1-9]*:[0-9]*.[0-9]*)
				total=$(awk -v a="$total" -v b="$use_time" 'BEGIN { printf "%.6f", a + b }')
				count=$((count + 1))
			;;
		esac
	done

	[ "$count" -gt 0 ] && {
		awk -v total="$total" -v count="$count" 'BEGIN { printf "200:%.6f", total / count }'
		return 0
	}
	echo "0:"
}

node_to_curlx() {
	local node_id=$1
	local _type=$(echo "$(config_n_get "$node_id" type)" | tr 'A-Z' 'a-z')
	[ -n "${_type}" ] && {
		if [ "${_type}" == "socks" ]; then
			local _address=$(config_n_get "$node_id" address)
			local _port=$(config_n_get "$node_id" port)
			[ -n "${_address}" ] && [ -n "${_port}" ] && {
				local curlx="socks5h://${_address}:${_port}"
				local _username=$(config_n_get "$node_id" username)
				local _password=$(config_n_get "$node_id" password)
				[ -n "${_username}" ] && [ -n "${_password}" ] && curlx="socks5h://${_username}:${_password}@${_address}:${_port}"
			}
		else
			local _tmp_port=$(get_new_port 48900 tcp,udp)
			NO_REC_PROCESS=1 /usr/share/${CONFIG}/app.sh run_socks flag="url_test_${node_id}" node="$node_id" bind=127.0.0.1 socks_port="${_tmp_port}" config_file="url_test_${node_id}.json"
			local curlx="socks5h://127.0.0.1:${_tmp_port}"
		fi
		[ -n "$curlx" ] && echo "$curlx"
	}
}

url_test_node() {
	result=0
	local node_id=$1
	local curlx="$(node_to_curlx "$node_id")"
	local probeUrl=$(config_t_get global_other url_test_url https://www.google.com/generate_204)
	[ -n "$curlx" ] && {
			# 不修复时，这里固定 sleep 2 秒：快节点被强行加等待，慢启动节点仍可能没准备好，导致首次超时或延迟虚高。
			# 修复逻辑：先用短超时请求探测本地 socks/目标链路是否就绪，再连续采样 5 次并只平均成功样本。
			# 预期结果：节点可用性由 5 个采样点共同判断，5 次全部失败才宣告目标节点超时不可用。
			for i in 1 2 3 4 5; do
				result=$(url_test_once "$curlx" "$probeUrl" 1 2)
				case "$result" in
					[1-9]*:*) break ;;
				esac
			done
			result=$(url_test_average "$curlx" "$probeUrl")
	}
	url_test_node_cleanup "$node_id"
	echo $result
}

outbound_ip_node() {
	local node_id=$1
	local curlx="$(node_to_curlx "$node_id")"
	local ipv4 ipv6
	[ -n "$curlx" ] && {
		# 不修复时：用户只能看到节点入口地址，无法判断代理链最终从哪个公网 IP 出口。
		# 修复逻辑：复用节点临时 socks，分别用 curl -4 / curl -6 请求 ip.sb，检测该节点真实 IPv4/IPv6 出口。
		# 预期结果：支持双栈节点时同时返回 IPv4 和 IPv6；不支持某一地址族时该字段留空，不影响另一地址族显示。
		ipv4=$(/usr/bin/curl -x "$curlx" -4 -fsS --connect-timeout 3 --max-time 6 https://ip.sb 2>/dev/null | tr -d ' \t\r\n')
		ipv6=$(/usr/bin/curl -x "$curlx" -6 -fsS --connect-timeout 3 --max-time 6 https://ip.sb 2>/dev/null | tr -d ' \t\r\n')
	}
	url_test_node_cleanup "$node_id"
	echo "ipv4=${ipv4}"
	echo "ipv6=${ipv6}"
}

arg1=$1
shift
case $arg1 in
test_url)
	test_url $@
	;;
url_test_node)
	url_test_node $@
	;;
outbound_ip_node)
	outbound_ip_node $@
	;;
esac
