#!/bin/sh
# EX20v v2: ana OpenWrt kurulumu. KURTARMA (rescue) sisteminde calistirilir.
#   PC: 192.168.1.2, C:\tftp icinde "python put_server.py" acik,
#       ex20v-kernel.bin, ex20v-ubi.bin ve bu cihazin dump.sh ciktisi
#       md5.txt ayni klasorde.
#   sh /tmp/install_b.sh 192.168.1.2
# Yapar: kernel -> slot B (0x2980000), ubi.bin -> ubi (0x2f80000..),
#        bootflag -> '1'. STOK FIRMWARE'IN KALANINI SILER.
PC="$1"; [ -n "$PC" ] || { echo "kullanim: sh /tmp/install_b.sh PC_IP"; exit 1; }
BS=262144

grep -q 'tplink,ex20v-v2' /tmp/sysinfo/board_name 2>/dev/null || { echo "HATA: EX20v v2 degil"; exit 1; }
case "$(awk '$2=="/"{print $3; exit}' /proc/mounts)" in
  rootfs|tmpfs|ramfs) ;;
  *) echo "HATA: kurtarma (initramfs) sisteminde degil"; exit 1;;
esac

for t in ubiformat ubiattach ubidetach mtd wget; do
  command -v $t >/dev/null || { echo "HATA: '$t' yok, hicbir sey yazilmadi"; exit 1; }
done

mtdn() { grep "\"$1\"" /proc/mtd | cut -d: -f1; }
KP=$(mtdn kernel); UP=$(mtdn ubi); FP=$(mtdn bootflag)
[ -n "$KP" ] && [ -n "$UP" ] && [ -n "$FP" ] || { echo "HATA: bolumler bulunamadi"; cat /proc/mtd; exit 1; }
echo "kernel=$KP ubi=$UP bootflag=$FP"

# Guvenlik: ham okunan slot B, BU CIHAZIN stok yedegiyle (dump.sh -> md5.txt) ayni mi?
# Ayni degilse NAND'da bad block kaymasi var: bootloader kernel'i baska yerden okur.
rm -f /tmp/md5.txt
wget -q -O /tmp/md5.txt "http://$PC:8000/md5.txt" || { echo "HATA: md5.txt (dump.sh ciktisi) indirilemedi"; exit 1; }
STOCK_K=$(grep 'mtd7_kernel_2.bin' /tmp/md5.txt | cut -c1-32)
STOCK_R=$(grep 'mtd8_rootfs_2.bin' /tmp/md5.txt | cut -c1-32)
[ ${#STOCK_K} -eq 32 ] && [ ${#STOCK_R} -eq 32 ] || { echo "HATA: md5.txt icinde mtd7/mtd8 satirlari yok"; exit 1; }
echo "== 0/3 bad block kontrolu (ham okuma, birkac saniye)"
KM=$(dd if=/dev/$KP bs=$BS count=24 2>/dev/null | md5sum | cut -c1-32)
ENTRY=$(dd if=/dev/$KP bs=1 skip=108 count=4 2>/dev/null | hexdump -v -e '4/1 "%02x"')
if [ "$KM" = "$STOCK_K" ]; then
  RM=$(dd if=/dev/$UP bs=$BS count=128 2>/dev/null | md5sum | cut -c1-32)
  if [ "$RM" = "$STOCK_R" ]; then
    echo "slot B kernel + rootfs_2 stok yedekle AYNI: bad block kaymasi yok"
  else
    echo "HATA: slot B kernel ayni ama rootfs_2 farkli ($RM). Hicbir sey yazilmadi."; exit 1
  fi
elif [ "$ENTRY" = "00200080" ]; then
  echo "slot B'de zaten OpenWrt kernel'i var: yeniden kurulum"
else
  echo "HATA: slot B ham okuma stok yedekle tutmuyor ($KM)."
  echo "Bad block kaymasi olabilir. Hicbir sey yazilmadi, ciktiyi gonder."; exit 1
fi

cd /tmp || exit 1
rm -f k.bin u.bin
wget -q -O k.bin "http://$PC:8000/ex20v-kernel.bin" || { echo "HATA: ex20v-kernel.bin indirilemedi"; exit 1; }
wget -q -O u.bin "http://$PC:8000/ex20v-ubi.bin" || { echo "HATA: ex20v-ubi.bin indirilemedi"; exit 1; }
KS=$(wc -c < k.bin); US=$(wc -c < u.bin)
echo "kernel: $KS bayt, ubi: $US bayt"
[ "$KS" -le 6291456 ] || { echo "HATA: kernel 6 MiB'dan buyuk"; exit 1; }
[ "$(head -c 4 k.bin | hexdump -v -e '4/1 "%02x"')" = "03000003" ] || { echo "HATA: kernel TP-Link basligi yok"; exit 1; }
[ "$(head -c 4 u.bin)" = "UBI#" ] || { echo "HATA: ubi.bin UBI imaji degil"; exit 1; }

echo "== 1/3 kernel -> slot B"
mtd write k.bin kernel || { echo "HATA: kernel yazilamadi. BAYRAGA DOKUNULMADI."; exit 1; }
A=$(md5sum < k.bin | cut -c1-32)
B=$(dd if=/dev/$KP bs=$KS count=1 2>/dev/null | md5sum | cut -c1-32)
[ "$A" = "$B" ] || { echo "HATA: kernel dogrulanamadi. BAYRAGA DOKUNULMADI."; exit 1; }
echo "kernel DOGRULANDI"

echo "== 2/3 ubi"
ubidetach -p /dev/$UP 2>/dev/null
ubiformat /dev/$UP -y -f u.bin || { echo "HATA: ubiformat basarisiz. BAYRAGA DOKUNULMADI."; exit 1; }
ubiattach -p /dev/$UP >/dev/null 2>&1 && { ubinfo -a | grep -E 'Name|Size'; ubidetach -p /dev/$UP; }
echo "ubi YAZILDI"

echo "== 3/3 bootflag -> '1' (slot B)"
printf '1' > bf.bin
dd if=/dev/zero bs=$((BS-1)) count=1 2>/dev/null | tr '\000' '\377' >> bf.bin
mtd write bf.bin bootflag || { echo "HATA: bootflag yazilamadi"; exit 1; }
F=$(dd if=/dev/$FP bs=1 count=1 2>/dev/null)
[ "$F" = "1" ] || { echo "HATA: bootflag '$F'"; exit 1; }
echo "bootflag = 1 DOGRULANDI"
rm -f k.bin u.bin bf.bin
echo
echo "KURULUM TAMAM. 'reboot' de. Ana OpenWrt 192.168.1.1'de acilacak."
echo "Kurtarmaya donmek icin ana sistemde: bootflag'i '0' yap ve reboot."
