#!/bin/sh
# EX20v v2 boot slot araci
#   sh /tmp/slot.sh          -> sadece goster (yazmaz)
#   sh /tmp/slot.sh set 1    -> slot B (kernel_2/rootfs_2) sec
#   sh /tmp/slot.sh set 0    -> slot A (kernel/rootfs) sec
# Bayrak: flash 0x240000 = config (mtdblock2) + 0x100000, 1 bayt ASCII '0'/'1'
# Stok libcmm oal_sys_setBootIndex ile ayni islem: 256KiB blogu oku, ilk bayti degistir, geri yaz.
export PATH="$PATH:/usr/sbin:/sbin:/usr/bin:/bin"
DEV=/dev/mtdblock2
BS=262144
BLK=4   # 0x100000 / 0x40000

cur() { dd if=$DEV bs=$BS skip=$BLK count=1 2>/dev/null | head -c 1; }
show() {
  F=$(cur)
  echo "bootflag = '$F'  ($( [ "$F" = 1 ] && echo 'slot B: kernel_2/rootfs_2' || echo 'slot A: kernel/rootfs'))"
  echo "simdi calisan rootfs: $(grep ' / / ' /proc/self/mountinfo | grep squashfs | awk '{print $3}')  (31:5=slot A rootfs, 31:8=slot B rootfs_2)"
}

if [ "$1" != "set" ]; then show; exit 0; fi

case "$2" in 0|1) ;; *) echo "sadece 0 veya 1"; exit 1;; esac

show
cd /tmp || exit 1
dd if=$DEV of=/tmp/flagblk.bin bs=$BS skip=$BLK count=1 2>/dev/null
[ "$(wc -c < /tmp/flagblk.bin)" -eq $BS ] || { echo "HATA: blok okunamadi"; exit 1; }
printf "$2" > /tmp/newblk.bin
dd if=/tmp/flagblk.bin bs=1 skip=1 2>/dev/null >> /tmp/newblk.bin
[ "$(wc -c < /tmp/newblk.bin)" -eq $BS ] || { echo "HATA: yeni blok boyutu yanlis"; exit 1; }
echo "yaziliyor: bootflag -> '$2'"
dd if=/tmp/newblk.bin of=$DEV bs=$BS seek=$BLK count=1 conv=notrunc 2>/dev/null
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
A=$(md5sum < /tmp/newblk.bin)
B=$(dd if=$DEV bs=$BS skip=$BLK count=1 2>/dev/null | md5sum)
if [ "$A" = "$B" ]; then echo "DOGRULANDI"; else echo "!! DOGRULAMA BASARISIZ, REBOOT ETME, ciktiyi gonder"; fi
show
rm -f /tmp/flagblk.bin /tmp/newblk.bin
