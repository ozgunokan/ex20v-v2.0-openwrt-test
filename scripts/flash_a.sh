#!/bin/sh
# EX20v v2: TP-Link basligli OpenWrt imajini SLOT A kernel bolumune yazar.
#   sh /tmp/flash_a.sh PC_IP [dosya]   (varsayilan dosya: ex20v-rescue.bin)
# Sadece SLOT B'den calisirken calisir. Slot B'ye ve bayraga DOKUNMAZ.
# Bayragi degistirmek ayri adim: sh /tmp/slot.sh set 0
export PATH="$PATH:/usr/sbin:/sbin:/usr/bin:/bin"
PC="$1"; IMG="${2:-ex20v-rescue.bin}"; MAX=6291456; BS=262144
[ -n "$PC" ] || { echo "kullanim: sh /tmp/flash_a.sh PC_IP"; exit 1; }

root=$(grep ' / / ' /proc/self/mountinfo | grep squashfs | awk '{print $3}')
[ "$root" = "31:8" ] || { echo "HATA: slot B'den calismiyor (rootfs=$root). Durduruldu."; exit 1; }

cd /tmp || exit 1
rm -f /tmp/$IMG
tftp -g -r $IMG -l /tmp/$IMG "$PC" || { echo "HATA: $IMG indirilemedi"; exit 1; }
SZ=$(wc -c < /tmp/$IMG)
echo "imaj boyutu: $SZ"
[ "$SZ" -le "$MAX" ] || { echo "HATA: imaj kernel slotundan (6 MiB) buyuk. Durduruldu."; rm -f /tmp/$IMG; exit 1; }

H=$(head -c 4 /tmp/$IMG | hexdump -v -e '4/1 "%02x"')
E=$(dd if=/tmp/$IMG bs=1 skip=108 count=4 2>/dev/null | hexdump -v -e '4/1 "%02x"')
[ "$H" = "03000003" ] || { echo "HATA: TP-Link basligi yok ($H). Durduruldu."; exit 1; }
[ "$E" = "00200080" ] || { echo "HATA: giris adresi beklenmedik ($E). Durduruldu."; exit 1; }
echo "baslik OK, giris 0x80002000"

# blok sinirina 0xff ile tamamla
PAD=$(( (BS - SZ % BS) % BS ))
if [ $PAD -gt 0 ]; then dd if=/dev/zero bs=$PAD count=1 2>/dev/null | tr '\000' '\377' >> /tmp/$IMG; fi
N=$(( $(wc -c < /tmp/$IMG) / BS ))
echo "yaziliyor: $N blok -> slot A kernel (/dev/mtdblock4)"
dd if=/tmp/$IMG of=/dev/mtdblock4 bs=$BS count=$N conv=notrunc 2>/dev/null
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
A=$(md5sum < /tmp/$IMG | cut -c1-32)
B=$(dd if=/dev/mtd4 bs=$BS count=$N 2>/dev/null | md5sum | cut -c1-32)
if [ "$A" = "$B" ]; then
  echo "DOGRULANDI. Slot A artik $IMG. Bayrak hala '1' (stok, slot B)."
else
  echo "!! DOGRULAMA BASARISIZ. BAYRAGI DEGISTIRME, ciktiyi gonder."
fi
rm -f /tmp/$IMG
