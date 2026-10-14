#!/bin/sh
# EX20v v2 Wi-Fi darbogaz testi. Her modda: modu ayarla, SONRA speedtest baslat,
# test calisirken "sh /tmp/wifitest.sh olc" ile 10 sn CPU dagilimini al.
#   sh /tmp/wifitest.sh durum   -> mevcut ayarlar
#   sh /tmp/wifitest.sh hwkapa  -> donanim offload KAPALI (yazilim offload acik)
#   sh /tmp/wifitest.sh rpskapa -> RPS KAPALI (hw offload acik)
#   sh /tmp/wifitest.sh normal  -> ikisi de acik (varsayilan)
#   sh /tmp/wifitest.sh olc     -> 10 sn olcum: cekirdek basina usr/sys/sirq/idle + PPE sayaclari
#   sh /tmp/wifitest.sh detay TELEFON_IP -> PPE kabul/ret, baglanti bayraklari, drop sayaclari
set_hw() { uci set firewall.@defaults[0].flow_offloading='1'; uci set firewall.@defaults[0].flow_offloading_hw="$1"; uci commit firewall; fw4 reload >/dev/null 2>&1; }
set_rps() { for q in /sys/class/net/eth0/queues/rx-*/rps_cpus /sys/class/net/phy*-ap0/queues/rx-*/rps_cpus; do echo "$1" > "$q" 2>/dev/null; done; }
durum() {
	echo "flow_offloading=$(uci -q get firewall.@defaults[0].flow_offloading) hw=$(uci -q get firewall.@defaults[0].flow_offloading_hw)"
	echo "rps eth0=$(cat /sys/class/net/eth0/queues/rx-0/rps_cpus) phy0=$(cat /sys/class/net/phy0-ap0/queues/rx-0/rps_cpus 2>/dev/null) phy1=$(cat /sys/class/net/phy1-ap0/queues/rx-0/rps_cpus 2>/dev/null)"
	nft list flowtables | grep -E "devices|flags"
}
snap() { grep '^cpu[0-9]' /proc/stat; }
case "$1" in
hwkapa)  set_hw 0; set_rps a; durum ;;
rpskapa) set_hw 1; set_rps 0; durum ;;
normal)  set_hw 1; set_rps a; durum ;;
durum)   durum ;;
olc)
	P=/sys/kernel/debug/econet_ppe/diag
	a=$(snap); pa=$(grep -E "rxc_call|rxc_nolookup_v4" $P 2>/dev/null)
	sleep 10
	b=$(snap); pb=$(grep -E "rxc_call|rxc_nolookup_v4" $P 2>/dev/null)
	echo "cekirdek  usr%  sys%  sirq%  irq%  idle%"
	echo "$a" > /tmp/s1; echo "$b" > /tmp/s2
	awk 'NR==FNR { for (k=2;k<=8;k++) o[$1,k]=$k; next }
	{ u=$2-o[$1,2]; n=$3-o[$1,3]; s=$4-o[$1,4]; i=$5-o[$1,5]; w=$6-o[$1,6]; q=$7-o[$1,7]; sq=$8-o[$1,8];
	  t=u+n+s+i+w+q+sq; if(t==0)t=1;
	  printf "%-8s %5.0f %5.0f %6.0f %5.0f %6.0f\n",$1,100*(u+n)/t,100*s/t,100*sq/t,100*q/t,100*i/t }' /tmp/s1 /tmp/s2
	echo "--- PPE (10 sn fark):"; echo "$pa" > /tmp/p1; echo "$pb" > /tmp/p2
	awk 'NR==FNR { o[$1]=$2; next } { printf "%-16s %d\n",$1,$2-o[$1] }' /tmp/p1 /tmp/p2
	echo "--- conntrack: $(cat /proc/sys/net/netfilter/nf_conntrack_count), offload: $(grep -c OFFLOAD /proc/net/nf_conntrack 2>/dev/null)"
	rm -f /tmp/s1 /tmp/s2 /tmp/p1 /tmp/p2 ;;
detay)
	# Wi-Fi testi SIRASINDA: PPE kabul/ret, FOE bind sayisi, telefonun baglanti bayraklari, drop sayaclari
	IP="$2"
	P=/sys/kernel/debug/econet_ppe
	echo "--- diag:"; grep -E "repl_|rxc_bound|rxc_noslot" $P/diag
	echo "--- foe:"; head -2 $P/foe | tail -1
	echo "--- telefon baglantilari ($IP):"
	grep "src=$IP " /proc/net/nf_conntrack | grep -E "tcp|udp" | sed 's/ mark=.*//' | head -8
	echo "--- drop/hata:"
	for d in eth0 phy1-ap0 phy0-ap0 br-lan pppoe-wan; do
		[ -d /sys/class/net/$d ] || continue
		st=/sys/class/net/$d/statistics
		echo "$d rx_drop=$(cat $st/rx_dropped) tx_drop=$(cat $st/tx_dropped) rx_err=$(cat $st/rx_errors) tx_err=$(cat $st/tx_errors)"
	done
	echo "--- softnet (drop sutunu 2.):"; cat /proc/net/softnet_stat ;;
*) sed -n 2,9p "$0" ;;
esac
