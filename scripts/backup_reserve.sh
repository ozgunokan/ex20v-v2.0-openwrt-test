#!/bin/sh
# EX20v v2 (STOK firmware): reserve_area (mtd10, 368 MiB) yedegi, SADECE OKUMA.
# PC'de C:\tftp icinde "python put_server.py" acik olmali.
#   sh /tmp/backup_reserve.sh PC_IP
export PATH="$PATH:/usr/sbin:/sbin:/usr/bin:/bin"
PC="$1"; [ -n "$PC" ] || { echo "kullanim: sh /tmp/backup_reserve.sh PC_IP"; exit 1; }
cd /tmp || exit 1
rm -f /tmp/rd10; mknod /tmp/rd10 c 90 20
BS=262144; CH=128          # 128 blok = 32 MiB parca
TOTAL=1474                 # 0x17080000 / 0x40000
: > reserve_md5.txt
i=0; part=0
while [ $i -lt $TOTAL ]; do
  n=$CH; [ $((i+n)) -gt $TOTAL ] && n=$((TOTAL-i))
  F=$(printf 'reserve_%02d.bin' $part)
  echo "okunuyor: $F (blok $i, $n blok)"
  dd if=/tmp/rd10 of=/tmp/$F bs=$BS skip=$i count=$n 2>/dev/null
  sz=$(wc -c < /tmp/$F)
  [ "$sz" -eq $((n*BS)) ] || { echo "HATA: $F eksik okundu ($sz)"; rm -f /tmp/$F /tmp/rd10; exit 1; }
  md5sum /tmp/$F | sed 's#/tmp/##' >> reserve_md5.txt
  if curl -s -f -T /tmp/$F "http://$PC:8000/$F" >/dev/null; then echo "gonderildi: $F"; else echo "HATA gonderilemedi: $F"; rm -f /tmp/$F /tmp/rd10; exit 1; fi
  rm -f /tmp/$F
  i=$((i+n)); part=$((part+1))
done
curl -s -f -T reserve_md5.txt "http://$PC:8000/reserve_md5.txt" >/dev/null && echo "gonderildi: reserve_md5.txt"
rm -f /tmp/rd10
echo "Bitti. Flash'a hicbir sey yazilmadi."
