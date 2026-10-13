#!/bin/sh
# EX20v v2 bilgi toplama + mtd yedekleme (SADECE OKUMA)
# Kullanim:
#   sh /tmp/dump.sh PC_IP          -> TFTP ile gonderir
#   sh /tmp/dump.sh PC_IP http     -> PC'de put_server.py calisiyorsa HTTP (port 8000) ile gonderir

export PATH="$PATH:/usr/sbin:/sbin:/usr/bin:/bin"

PC="$1"
MODE="${2:-tftp}"
if [ -z "$PC" ]; then
  echo "Kullanim: sh /tmp/dump.sh PC_IP [tftp|http]"
  exit 1
fi

cd /tmp || exit 1

send() {
  if [ "$MODE" = "http" ]; then
    curl -s -f -T "$1" "http://$PC:8000/$1" >/dev/null
  else
    tftp -p -l "$1" -r "$1" "$PC"
  fi
  RC=$?
  if [ $RC -eq 0 ]; then echo "gonderildi: $1"; else echo "HATA gonderilemedi: $1"; fi
  rm -f "$1"
  return $RC
}

echo "== Sistem bilgisi toplaniyor =="
{
  echo "### version";      cat /proc/version
  echo "### cpuinfo";      cat /proc/cpuinfo
  echo "### meminfo";      cat /proc/meminfo
  echo "### mtd";          cat /proc/mtd
  echo "### partitions";   cat /proc/partitions
  echo "### dev mtd";      ls -l /dev/mtd* /dev/ubi* 2>&1
  echo "### mounts";       cat /proc/mounts
  echo "### df";           df
  echo "### ubinfo";       ubinfo -a 2>&1
  echo "### mtd sysfs"
  for d in /sys/class/mtd/mtd*; do
    echo "$d name=$(cat $d/name 2>/dev/null) dev=$(cat $d/dev 2>/dev/null) size=$(cat $d/size 2>/dev/null) erase=$(cat $d/erasesize 2>/dev/null) write=$(cat $d/writesize 2>/dev/null) oob=$(cat $d/oobsize 2>/dev/null) flags=$(cat $d/flags 2>/dev/null)"
  done
  echo "### pci"
  for d in /sys/bus/pci/devices/*; do
    echo "$d vendor=$(cat $d/vendor) device=$(cat $d/device) subv=$(cat $d/subsystem_vendor 2>/dev/null) subd=$(cat $d/subsystem_device 2>/dev/null) class=$(cat $d/class 2>/dev/null)"
  done
  echo "### interrupts";   cat /proc/interrupts
  echo "### iomem";        cat /proc/iomem 2>&1
  echo "### lsmod";        lsmod
  echo "### ifconfig";     busybox ifconfig -a
  echo "### ps";           ps
  echo "### var log";      ls -l /var/log 2>&1
} > info.txt 2>&1

if ! send info.txt; then
  echo "!! Ilk dosya gonderilemedi, PC tarafindaki sunucuyu duzeltip tekrar calistir. Durduruldu."
  exit 1
fi

echo "== mtd bolumleri yedekleniyor (tek tek) =="
: > md5.txt
for n in 0 1 2 3 4 5 7 8; do
  if [ -e /dev/mtd$n ]; then
    SRC=/dev/mtd$n
  else
    # /dev altinda yoksa /tmp icinde salt-okuma amacli dugum olustur (flash'a dokunmaz)
    DEV=$(cat /sys/class/mtd/mtd$n/dev 2>/dev/null)
    if [ -n "$DEV" ]; then
      rm -f /tmp/rd_mtd$n
      mknod /tmp/rd_mtd$n c ${DEV%%:*} ${DEV##*:}
      SRC=/tmp/rd_mtd$n
    else
      MSG="mtd$n cihaz dosyasi yok, atlandi"
      echo "$MSG"; echo "$MSG" >> md5.txt
      continue
    fi
  fi
  NAME=$(cat /sys/class/mtd/mtd$n/name 2>/dev/null)
  F="mtd${n}_${NAME}.bin"
  echo "okunuyor: $SRC -> $F"
  if dd if=$SRC of=$F bs=4096 2>dd_err.txt; then
    md5sum "$F" >> md5.txt
    send "$F"
  else
    MSG="HATA okuma: $SRC $(cat dd_err.txt)"
    echo "$MSG"; echo "$MSG" >> md5.txt
    rm -f "$F"
  fi
  rm -f dd_err.txt /tmp/rd_mtd$n
done
send md5.txt

echo "== Bitti. Flash'a hicbir sey yazilmadi. =="
