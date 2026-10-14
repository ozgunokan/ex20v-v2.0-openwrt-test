#!/bin/sh
# EX20v v2 performans teshisi. Speedtest CALISIRKEN baslat (betik ~20 sn surer).
#   wget -O /tmp/diag_perf.sh http://PC_IP:8000/diag_perf.sh && sh /tmp/diag_perf.sh PC_IP
PC="$1"; O=/tmp/diag.txt
exec 3>&1 > $O 2>&1
s() { echo; echo "######## $*"; }
s board; cat /tmp/sysinfo/board_name; uname -a
s offload ayarlari; uci show firewall | grep -i offload
s wan; uci show network.wan | sed 's/\(password=\).*/\1***/'; ifstatus wan_6 2>/dev/null | head -5
s flowtables; nft list flowtables
s moduller; lsmod | grep -iE "econet|flow|nft_offload|ppp"
s ppe diag 1; cat /sys/kernel/debug/econet_ppe/diag 2>&1
s softirqs 1; cat /proc/softirqs
s interrupts 1; cat /proc/interrupts
s top; top -b -n1 | head -25
s stat 1; head -6 /proc/stat
sleep 10
s stat 2; head -6 /proc/stat
s softirqs 2; cat /proc/softirqs
s interrupts 2; cat /proc/interrupts
s ppe diag 2; cat /sys/kernel/debug/econet_ppe/diag 2>&1
s "foe ilk 60 satir"; head -60 /sys/kernel/debug/econet_ppe/foe 2>&1
s conntrack sayisi; cat /proc/sys/net/netfilter/nf_conntrack_count
s rps; grep . /sys/class/net/*/queues/rx-*/rps_cpus
s ethtool; ethtool -k eth0 2>/dev/null | grep -iE "hw-tc|checksum|gro|gso|tso"
s netifd log; logread | grep -iE "wan_6|econet|ppe|offload" | tail -40
s dmesg; dmesg | grep -iE "econet|ppe|foe|offload" | tail -40
exec 1>&3 2>&1
echo "bitti: $O"
if [ -n "$PC" ]; then
	if command -v curl >/dev/null; then curl -sT $O http://$PC:8000/diag.txt
	else uclient-fetch -q -O /dev/null --post-file=$O http://$PC:8000/diag.txt; fi && echo "PC'ye gonderildi (C:\\tftp\\diag.txt)"
fi
