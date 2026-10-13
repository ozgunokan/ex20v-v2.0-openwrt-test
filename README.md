# TP-Link EX20v v2 için OpenWrt

TP-Link EX20v v2'ye (EcoNet EN7528, Türk Telekom AX1800) stok firmware'in kendi
shell'inden, UART gerekmeden tam OpenWrt kurulur. Ana sistem slot B + UBI'de,
küçük bir kurtarma sistemi slot A'da durur.

> **Uyarı:** Bu kurulum stok firmware'i siler. Kendi sorumluluğunuzdadır.
> ISS'nizden kiraladığınız bir cihazı değiştirmeden önce sözleşmenize bakın.
> Kuruluma başlamadan önce yedek adımlarını (1–2) atlamayın.

## Çalışanlar / çalışmayanlar

| Özellik | Durum |
| --- | --- |
| Ethernet (WAN + 3 LAN), PPE donanım offload | çalışıyor |
| Wi-Fi 2,4 + 5 GHz (MT7915 DBDC) | çalışıyor |
| Port, Wi-Fi, güç, internet, USB LED'leri; reset butonu | çalışıyor |
| USB, 2 çekirdek / 4 thread | çalışıyor |
| Kalıcı ayarlar (UBI, ~350 MB), LuCI'den sysupgrade | çalışıyor |
| VDSL/ADSL modem, telefon (FXS) | çalışmıyor (açık kaynak sürücü yok) |

WAN varsayılanı `eth0.35` + PPPoE (Türk Telekom altyapısı). VLAN'sız bir ISS'de
`eth0.2` + DHCP kullanın. LAN = `eth0.1`, `192.168.1.1`.

## Flash yerleşimi

Bootloader iki kernel slotundan birini `0x240000`'daki tek bayta göre açar
(`'0'` = slot A, `'1'` = slot B) ve TP-Link başlığındaki MD5/RSA imzayı kontrol
etmez.

| Adres | Stok | OpenWrt sonrası |
| --- | --- | --- |
| `0x0000000` boot, `0x0040000` romfile, `0x0140000` config, `0x0340000` radio | bootloader, ayarlar, MAC, Wi-Fi EEPROM | dokunulmaz (bootflag hariç) |
| `0x0380000` slot A kernel (6 MB) | stok kernel | kurtarma sistemi |
| `0x2980000` slot B kernel (6 MB) | stok kernel | ana OpenWrt kernel |
| `0x2f80000`–`0x1c000000` | stok rootfs, ISS uygulamaları | UBI: rootfs + ayarlar |
| `0x1c000000`+ | BMT havuzu | dokunulmaz |

## İmajlar

[Releases](../../releases) sayfasından ya da Actions'taki son başarılı
derlemenin `ex20v-v2-images` artifact'ından indirin:

| Dosya | Ne için |
| --- | --- |
| `ex20v-rescue.bin` | kurtarma sistemi, slot A |
| `ex20v-kernel.bin` | ana kernel, slot B |
| `ex20v-ubi.bin` | ana rootfs (UBI) |
| `ex20v-v2-sysupgrade.bin` | kurulu sistemi LuCI'den güncellemek |
| `*.sh`, `put_server.py` | kurulum scriptleri |

Kendiniz derlemek için [Derleme](#derleme) bölümüne bakın.

## Kurulum

Gerekenler: stok firmware'de root shell (SSH → `shell`), Windows/Linux PC,
Python 3, bir TFTP sunucusu (Windows'ta Tftpd64), Ethernet kablosu.

Bütün dosyaları PC'de tek bir klasöre koyun (örn. `C:\tftp`), Tftpd64'ün kök
klasörünü oraya ayarlayın ve aynı klasörde `python put_server.py` çalıştırın.
Aşağıda `PC` = PC'nin stok ağdaki IP'si.

1. **Yedek al (sadece okur).** Stok shell'de:
   ```
   tftp -g -r dump.sh -l /tmp/dump.sh PC
   sh /tmp/dump.sh PC http
   ```
   Klasöre `info.txt`, `md5.txt`, `mtd0…mtd8_*.bin` gelir. `md5.txt` 6. adımda gerekir.
2. **Silinecek alanın yedeğini al (sadece okur, ~368 MB).**
   ```
   tftp -g -r backup_reserve.sh -l /tmp/backup_reserve.sh PC
   sh /tmp/backup_reserve.sh PC
   ```
3. **Stok slot B'den çalışmalı.**
   ```
   tftp -g -r slot.sh -l /tmp/slot.sh PC
   sh /tmp/slot.sh
   ```
   `bootflag = '1'` ve rootfs `31:8` değilse: `sh /tmp/slot.sh set 1`,
   `DOGRULANDI` görün, `/sbin/reboot`.
4. **Kurtarma sistemini slot A'ya yaz.**
   ```
   tftp -g -r flash_a.sh -l /tmp/flash_a.sh PC
   sh /tmp/flash_a.sh PC
   ```
5. **Kurtarmaya geç.** `sh /tmp/slot.sh set 0`, `/sbin/reboot`. PC'nin IP'sini
   `192.168.1.2` yapın, kabloyu LAN1/2/3'e takın, `ssh root@192.168.1.1`.
6. **Ana sistemi kur (stok burada silinir).** Kurtarma sisteminde:
   ```
   wget -O /tmp/install_b.sh http://192.168.1.2:8000/install_b.sh
   sh /tmp/install_b.sh 192.168.1.2
   ```
   Script önce slot B'yi ham okuyup cihazın kendi `md5.txt` yedeğiyle
   karşılaştırır (kötü blok kontrolü); tutmazsa hiçbir şey yazmadan durur.
   Sonra kernel'i yazar ve doğrular, UBI'yi `ubiformat` ile yazar, bayrağı
   `'1'` yapar.
7. **`KURULUM TAMAM` görünce `reboot`.** LuCI: `http://192.168.1.1`.

Herhangi bir adımda `HATA` çıkarsa script durur ve bayrağa dokunmaz.

## İlk ayarlar

- LuCI'deki uyarıdan root şifresi koyun.
- Network → Interfaces → `wan`: PPPoE kullanıcı adı / şifre.
- Network → Wireless: iki radyoyu açın, şifre koyun.
- Network → Firewall → *Hardware flow offloading*. Kontrol: `nft list flowtables`
  çıktısında `flags offload`.
- Güncelleme: System → Backup / Flash Firmware → `ex20v-v2-sysupgrade.bin`.

## Kurtarma

Ana sistem açılmazsa bayrağı `'0'` yapın; kurtarma sistemi açılır, 6. adımı
tekrarlayın. Ana OpenWrt'den:

```
printf '0' > /tmp/bf
dd if=/dev/zero bs=262143 count=1 2>/dev/null | tr '\000' '\377' >> /tmp/bf
mtd write /tmp/bf bootflag
reboot
```

Cihaza hiç erişilemiyorsa tek yol UART (115200 8N1): bootloader'ı durdurup
(`telecomadmin` / `nE7jA%5m`) `0x240000`'daki bayrağı değiştirmek. Bu yol
EX20v'de denenmedi.

### Stoka dönüş (denenmedi)

Kurtarma sisteminde, `put_server.py` açık ve 1–2. adım yedekleri klasörde iken:

```
cd /tmp
wget -O k.bin http://192.168.1.2:8000/mtd7_kernel_2.bin && mtd write k.bin kernel && rm k.bin
wget -O r.bin http://192.168.1.2:8000/mtd8_rootfs_2.bin && mtd -p 0 write r.bin ubi && rm r.bin
for i in 00 01 02 03 04 05 06 07 08 09 10 11; do
  wget -O p.bin http://192.168.1.2:8000/reserve_$i.bin || break
  mtd -p $((0x2000000 + 1$i % 100 * 0x2000000)) write p.bin ubi && rm p.bin
done
```

Sonra bayrağı `'1'` yapıp yeniden başlatın.

## Derleme

Yamalar resmi OpenWrt'nin `2d1c9d1b85` commit'ine uygulanır.

**GitHub Actions:** Bu depoyu fork'layın; `main`'e her push derler, `v*`
tag'i (örn. `v1.0`) imajları Releases'e koyar.

**Ubuntu 22.04/24.04:**

```bash
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext git libncurses-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget
git clone https://github.com/openwrt/openwrt.git && cd openwrt
git checkout 2d1c9d1b85b8e5204420c0dd71a8421ddfe1dfd4
git -c user.name=me -c user.email=me@local am ../openwrt-ex20v-v2/patches/*.patch
./scripts/feeds update -a && ./scripts/feeds install -a
printf '%s\n' CONFIG_TARGET_econet=y CONFIG_TARGET_econet_en7528=y \
  CONFIG_TARGET_MULTI_PROFILE=y CONFIG_TARGET_PER_DEVICE_ROOTFS=y \
  CONFIG_TARGET_DEVICE_econet_en7528_DEVICE_tplink_ex20v-v2=y \
  CONFIG_TARGET_DEVICE_econet_en7528_DEVICE_tplink_ex20v-v2-rescue=y \
  CONFIG_TARGET_ROOTFS_INITRAMFS=y > .config
make defconfig && make download -j8 && make -j$(nproc)
```

Çıktılar `bin/targets/econet/en7528/` altında.

## v1 ile uyumluluk

SoC, RAM, bölüm tablosu, bootflag, MAC/EEPROM yerleri, port sırası ve LED
GPIO'ları v1 ile aynı; NAND çipi farklı (v1 ESMT, v2 Micron, aynı geometri).
Stoktan sıfırdan kurulum v1'de büyük ihtimalle çalışır ama denenmedi.
v1 portu kurulu bir cihaza bu imajı sysupgrade ile yüklemeyin.

## Teşekkür ve lisans

- [OpenWrt](https://github.com/openwrt/openwrt) — EcoNet EN7528 hedefi.
- [cjdelisle/econet_eth](https://github.com/cjdelisle/econet_eth) — Ethernet sürücüsü (Caleb James DeLisle).
- Emre Yavuzalp — EX20v (v1) OpenWrt portu (fork:
  [ozgunokan/openwrt-tplink-ex20v](https://github.com/ozgunokan/openwrt-tplink-ex20v)):
  PPE donanım offload'lu `econet-eth` yamaları, LED/buton GPIO'ları, port
  eşlemesi. `patches/0002-*` bu yamaları yazarlarının adlarıyla içerir.

Yamalar ve OpenWrt değişiklikleri GPL-2.0 lisanslıdır (OpenWrt ve Linux ile aynı).
