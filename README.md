# TP-Link EX20v v2 için OpenWrt

TP-Link EX20v v2'ye (EcoNet EN7528, Türk Telekom AX1800) stok firmware'in kendi
shell'inden, UART gerekmeden tam OpenWrt kurulur. Ana sistem slot B + UBI'de,
küçük bir kurtarma sistemi slot A'da durur.

> **Uyarı:** Bu kurulum stok firmware'i siler. Kiralık / ISS'ye ait cihazlarda
> önce aşağıdaki [Sorumluluk reddi](#sorumluluk-reddi) bölümünü okuyun.
> Kuruluma başlamadan önce yedek adımlarını (1–2) atlamayın.

## Sorumluluk reddi

**Bu depodaki yamalar, scriptler ve imajlar "OLDUĞU GİBİ" (AS IS), hiçbir garanti
verilmeden sunulur.** Çalışacakları, belirli bir amaca uygun olacakları ya da
cihazınıza zarar vermeyecekleri garanti edilmez (GPL-2.0, madde 11–12).

**Kiralık cihazlar.** Türkiye'de EX20v cihazlarının çoğu internet servis
sağlayıcısı (ISS) tarafından kiralanır veya ücretsiz verilir ve mülkiyeti
ISS'ye aittir. Böyle bir cihazın yazılımını değiştirmek:

- abonelik sözleşmenizin veya kullanım koşullarının ihlali sayılabilir,
- cihazın iadesinde arıza / hasar bedeli ya da cezai şart talep edilmesine,
- ISS'nin uzaktan yönetiminin (TR-069), uzaktan destek ve arıza kaydı
  hizmetlerinin, telefon (VoIP/FXS) ve DSL bağlantısının kaybına,
- ISS'nin bu cihaz üzerinden destek vermeyi reddetmesine

yol açabilir. **Cihaz size ait değilse, kurulumdan önce ISS'nizden yazılı izin
alın ya da kendi satın aldığınız bir cihaz kullanın.** Cihazı iade etmeden önce
stok yazılıma döndürmek (bkz. [Stoka dönüş](#stoka-dönüş-denenmedi)) tamamen
sizin sorumluluğunuzdadır; bu işlem denenmemiştir ve başarılı olacağı garanti
edilmez.

**Riskler.** Kurulum flash belleğe yazar. Elektrik kesintisi, yanlış dosya,
donanım farkı veya bu yazılımdaki bir hata cihazı kullanılamaz hale getirebilir;
bu durumda kurtarma için seri konsol (UART) bağlantısı gerekebilir. Bu depoyu
kullanarak oluşabilecek her türlü donanım arızası, veri kaybı, hizmet kesintisi,
sözleşme ihlali, maddi veya hukuki sonuçtan **yalnızca kullanıcı sorumludur**;
depo sahibi ve katkıda bulunanlar sorumlu tutulamaz.

**Bağlantısızlık.** Bu proje bağımsız bir topluluk çalışmasıdır. TP-Link,
Türk Telekom, EcoNet, MediaTek veya OpenWrt projesi ile herhangi bir bağı
yoktur ve onlar tarafından onaylanmamıştır. Adı geçen markalar sahiplerine
aittir ve yalnızca cihazı tanımlamak için kullanılmıştır.

Bu metin hukuki tavsiye değildir. Emin değilseniz sözleşmenizi okuyun veya
ISS'nize danışın.

## Çalışanlar / çalışmayanlar

| Özellik | Durum |
| --- | --- |
| Ethernet (WAN + 3 LAN), PPE donanım offload | çalışıyor, kabloda gigabit, CPU ~%0 |
| Wi-Fi 2,4 + 5 GHz (MT7915 DBDC) | çalışıyor |
| İnternet → Wi-Fi PPE offload (stok "ExtIf" yöntemi) | çalışıyor, 5 GHz'de ~780 Mbit/s |
| Port, Wi-Fi, güç, internet, USB LED'leri; reset butonu | çalışıyor |
| USB, 2 çekirdek / 4 thread | çalışıyor |
| Kalıcı ayarlar (UBI, ~350 MB), LuCI'den sysupgrade | çalışıyor |
| VDSL/ADSL modem, telefon (FXS) | çalışmıyor (açık kaynak sürücü yok) |

WAN varsayılanı `eth0.35` + PPPoE (Türk Telekom altyapısı). VLAN'sız bir ISS'de
`eth0.2` + DHCP kullanın. LAN = `eth0.1`, `192.168.1.1`.

## Performans

Türk Telekom PPPoE (VLAN 35) hattında ölçüldü:

| | Hızlandırma yokken | Bu imajla |
| --- | --- | --- |
| Kablolu indirme | ~150 Mbit/s, tek çekirdek %100 | gigabit, CPU ~%0 |
| Wi-Fi indirme (5 GHz, 2x2 telefon) | 130–330 Mbit/s | ~780 Mbit/s |
| Wi-Fi yükleme | hattın sınırı | hattın sınırı |

Nasıl çalışıyor:

- **Kablolu:** Bağlantılar SoC'nin PPE motoruna bağlanır. NAT, VLAN ve PPPoE
  tamamen donanımda yapılır.
- **İnternet → Wi-Fi:** EN7528'de WED yok, PPE paketi doğrudan Wi-Fi kartına
  gönderemez. Bu yüzden stok yazılımın `hw_nat` "ExtIf" yöntemi kullanılır.
  PPE NAT'ı ve başlık düzenlemesini yapar, paketi CPU'ya hazır olarak verir;
  sürücü de onu ağ yığınını atlayarak doğrudan Wi-Fi'ye iletir. Varsayılan
  olarak açıktır. Kapatmak için:
  `echo 0 > /sys/module/econet_eth/parameters/wifi_offload`
- **Wi-Fi → internet:** Yazılım flowtable ile yapılır. Stokun `SendToPpe` yolu
  henüz yok. 57 Mbit/s yüklemeli hatta gerek olmadı; simetrik hatlarda
  ileride eklenebilir.
- Wi-Fi ve NAT yükü, packet steering (RPS) ile CPU1+CPU3'e dağıtılır.

Kontrol:

```sh
nft list flowtables | grep -E "devices|flags"      # eth0 ve br-lan görünmeli, flags offload
grep -E "repl_ok|rx_cpu" /sys/kernel/debug/econet_ppe/diag
```

`repl_ok_v4` kablolu, `rx_cpu_xmit` Wi-Fi'ye giden donanım bağlantılarıdır;
`rx_cpu_nomatch` 0 kalmalıdır. Darboğaz araması için `scripts/wifitest.sh`
ve `scripts/diag_perf.sh` var. `diag_perf.sh` PPPoE şifresini gizler.

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
- Network → Firewall → *Software flow offloading* ve *Hardware flow offloading*
  açın. Kontrol: `nft list flowtables` çıktısında `eth0`, `br-lan` ve
  `flags offload`.
- Güncelleme: System → Backup / Flash Firmware → `ex20v-v2-sysupgrade.bin`.
  "Ayarları koru" işaretli kalsın. SSH'tan `sysupgrade -n` ayarları siler.
- Saat dilimi (İstanbul) ve cihaz adı (`EX20v`) ilk açılışta ayarlanır.
  PPPoE WAN'da netifd'nin sürekli tekrar denediği `wan_6` arayüzü kapatılır.

**Bilinen durum:** Kurulumdan sonraki ilk açılışta PPPoE bağlanırken LAN IP'si
de değiştirilirse dnsmasq "crash loop" durumuna düşebilir. Belirti: LAN'da IP
gelmez, statik IP ile arayüze girilir. Çözüm: bir kez `reboot`.

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

## Yamalar

| Yama | Ne yapar |
| --- | --- |
| `0001` | EX20v v2 cihaz desteği: DTS, imaj, kurtarma, LED, ağ |
| `0002` | v1 portunun PPE offload'lu `econet-eth` sürücüsü + port LED'leri |
| `0003` | v1'in çalışma ayarları: RPS, `wan_6` döngüsü, saat dilimi, IPTV |
| `0004` | firewall4: flowtable'da `eth0.X` yerine `eth0` (v1'den; kablolu PPE için şart) |
| `0005` | mt76: 5 GHz bandına ayrı MAC (v1'den) |
| `0006` | firewall4: hw offload'da `br-lan` de flowtable'da (Wi-Fi hızlı yolu) |
| `0007` | econet-eth: internet → Wi-Fi PPE offload (CPU çıkışlı, "ExtIf") |
| `0008` | `0007`'yi varsayılan açık yapar |

## Teşekkür ve lisans

- [OpenWrt](https://github.com/openwrt/openwrt) — EcoNet EN7528 hedefi.
- [cjdelisle/econet_eth](https://github.com/cjdelisle/econet_eth) — Ethernet sürücüsü (Caleb James DeLisle).
- Emre Yavuzalp — EX20v (v1) OpenWrt portu (fork:
  [ozgunokan/openwrt-tplink-ex20v](https://github.com/ozgunokan/openwrt-tplink-ex20v)):
  PPE donanım offload'lu `econet-eth` yamaları, LED/buton GPIO'ları, port
  eşlemesi, firewall4 flowtable düzeltmesi, mt76 MAC yaması ve çalışma
  ayarları. `0002`–`0005` bu çalışmaları yazarlarının adlarıyla içerir.
  - Root erişimi için Laserbird'e teşekkürler.
- Wi-Fi offload yöntemi, stok TP-Link/EcoNet `hw_nat.ko`'daki "ExtIf" yolundan
  (yalnızca davranışından) esinlenmiştir; vendor kodu kopyalanmamıştır.

Yamalar ve OpenWrt değişiklikleri GPL-2.0 lisanslıdır (OpenWrt ve Linux ile aynı).
