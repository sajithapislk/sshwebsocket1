#!/bin/bash
limit_file="/etc/xray/user-limit-ssws"
log_file="/var/log/xray/access.log"
chain="XRAY_SSWS_LIMIT"

if [ ! -f "$limit_file" ]; then
	exit 0
fi

if [ ! -f "$log_file" ]; then
	exit 0
fi

if ! command -v iptables >/dev/null 2>&1; then
	exit 0
fi

iptables -L "$chain" >/dev/null 2>&1 || iptables -N "$chain"
iptables -C INPUT -j "$chain" >/dev/null 2>&1 || iptables -I INPUT -j "$chain"

while read -r user limit; do
	if [ -z "$user" ]; then
		continue
	fi
	case "$limit" in
	""|*[!0-9]* ) continue ;;
	esac
	ips=$(tail -n 500 "$log_file" | grep -w "$user" | awk '{print $3}' | sed 's/tcp:\/\///g' | cut -d ":" -f 1 | awk '!seen[$0]++')
	if [ -z "$ips" ]; then
		continue
	fi
	count=$(printf "%s\n" "$ips" | grep -c .)
	if [ "$count" -le "$limit" ]; then
		continue
	fi
	block=$(printf "%s\n" "$ips" | tail -n +$((limit + 1)))
	for ip in $block; do
		if [ -n "$ip" ]; then
			iptables -C "$chain" -s "$ip" -j DROP >/dev/null 2>&1 || iptables -I "$chain" -s "$ip" -j DROP
			echo "$(date +"%Y-%m-%d %H:%M:%S") - $user - $ip - $count" >> /root/log-limit-xray.txt
		fi
	done
done < "$limit_file"
