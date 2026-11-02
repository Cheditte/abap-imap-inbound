# Google Cloud üzerinde demo ortamı
> [English](../../cloud/GCP-DEMO.md) | **Türkçe**

Öğrenme ve ekran görüntüleri için geçici demo ortamı. Kaynak oluşturmadan hesabınızın maliyet ve deneme kredisi koşullarını kontrol edin. Güncel SAP 0.9.1 çalışma zamanı hedef sistemde doğrulanmayı bekliyor.

```
Windows (SAP GUI) ──SSH tüneli──► Google Cloud VM (Ubuntu 24.04)
                                   ├─ a4h        SAP ABAP Cloud Developer Trial 2025
                                   │              └─ /usr/sap/sapimap  (imap.ps1, PowerShell 7)
                                   └─ greenmail  test mail sunucusu (IMAPS 3993, SMTP 3025)
```

SAP portları internete açılmaz. Her şey yalnızca VM'in içinde (127.0.0.1) dinler ve Windows'tan bir SSH tüneliyle erişilir.

## 1. SSH anahtarı (Windows, bir kez)

```bat
ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\sapimap -C demo
```
```bat
type %USERPROFILE%\.ssh\sapimap.pub
```
Çıkan satırı kopyalayın (`ssh-ed25519 AAAA... demo`).

## 2. VM'i oluşturma (Google Cloud Console → Cloud Shell, sağ üstte)

```bash
gcloud config set project PROJECT_ID
```
```bash
gcloud services enable compute.googleapis.com
```
```bash
gcloud compute instances create sapimap-demo \
  --zone=europe-west3-c \
  --machine-type=e2-highmem-4 \
  --image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud \
  --boot-disk-size=200GB --boot-disk-type=pd-balanced \
  --metadata=ssh-keys="demo:PASTE_PUBLIC_KEY_LINE_HERE"
```

- `e2-highmem-4`: 4 vCPU, 32 GB RAM (SAP'nin önerdiği bellek).
- 200 GB disk: SAP 150 GB önerir; açılmış imaj tek başına 53 GB'tan büyüktür.
- Çıktıdaki `EXTERNAL_IP` değerini not edin.

## 3. Dosyaları kopyalama ve kurulum (Windows)

```bat
scp -i %USERPROFILE%\.ssh\sapimap -r imap demo@EXTERNAL_IP:~/
```
```bat
ssh -i %USERPROFILE%\.ssh\sapimap demo@EXTERNAL_IP
```
VM'de kurulumu `tmux` içinde çalıştırın; böylece bağlantı koparsa kurulum durmaz:
```bash
tmux new -s setup
```
```bash
cd ~/imap && sudo bash cloud/setup-vm.sh
```
Bağlantı koparsa yeniden bağlanın ve `tmux attach -t setup` ile devam edin.

Betik şunları yapar: Docker'ı kurar, çekirdek parametrelerini ayarlar, SAP lisansını kabul etmenizi ister, Docker Hub'a giriş yapar (ücretsiz bir Docker Hub hesabı gerekir), GreenMail'i başlatır, SAP imajını çeker ve başlatır, PowerShell 7'yi kurar, sunucu kurulumunu çalıştırır ve örnek mailleri gönderir. En uzun adım, imajın çekilmesi ve SAP'nin ilk açılışıdır.

Betik, Basis'in çalıştıracağı sunucu kurulumunun aynısını çalıştırarak ([WALKTHROUGH.md](WALKTHROUGH.md)) biter, altı örnek mail gönderir ve kendi kendini SAP kullanıcısıyla (`a4hadm`) sınar. Son satırlarda `STEP POLICY OK`, `STEP CURL OK`, `STEP FOLDERS OK` ve `OK` görünmelidir.

## 4. SAP GUI bağlantısı (Windows)

Tüneli ayrı bir pencerede açık tutun:
```bat
ssh -i %USERPROFILE%\.ssh\sapimap -N -L 3200:127.0.0.1:3200 -L 3300:127.0.0.1:3300 -L 50001:127.0.0.1:50001 demo@EXTERNAL_IP
```

SAP Logon → yeni bağlantı: application server `127.0.0.1`, instance number `00`, system ID `A4H`. Client `001`, kullanıcı `DEVELOPER`; şifre SAP'nin [trial image sayfasında](https://github.com/SAP-docs/abap-platform-trial-image) yazar.

## 5. SAP'de kurulum

[SAP kurulum adımları](WALKTHROUGH.md#31-kurulum-programını-oluşturun) içindeki geliştirici adımlarını izleyin. Bu demoda sunucu ana klasörü `/usr/sap/sapimap`'tir; `ZCHE_IMAP_INSTALL`, Linux ve Unicode olduğunu kendisi anlar.

`ZCHE_IMAP_CONFIG`'te demo posta kutusu şöyledir: server `greenmail`, port `3993`, IMAPS, sertifika kontrolü kapalı, kullanıcı `sap@demo.local`, parola kaynağı `S`, şifre `sapdemo` (yalnızca GreenMail test değerleri; ekranın varsayılanı `O` kaynağıdır).

## 6. Ekran görüntüleri

| # | Ekran | Ne göstermeli |
|---|---|---|
| 1 | `ZCHE_IMAP_INSTALL` çıktısı | DDIC, programlar, sözdizimi kontrolleri, SM69 komutları, sunucu testi OK |
| 2 | `ZCHE_IMAP_CONFIG` | Profil ve adım adım bağlantı testi |
| 3 | `ZCHE_IMAP_INBOUND`, yalnız listeleme | Yalnız uygun ileti numaraları; içerik veya ek önizlemesi yok |
| 4 | Aynı rapor, test modu kapalı | İşlenen mailler |
| 5 | `ZCHE_IMAP_MONITOR` | Liste, mail ayrıntıları, bilgisayarda açılmış bir PDF ve bir görsel |
| 6 | Hata senaryosu | Konusunda `TEST-ERROR` geçen bir mail: durum `E`, sonra yeniden işleme |
| 7 | SM37 | Periyodik job ve spool çıktısı |
| 8 | PowerShell | `test/run-tests.ps1` çıktısı; `test/run-imap-tests.ps1` testini GreenMail portlarına erişilebilen VM üzerinde çalıştırın |

Ekran görüntülerinde gerçek sunucu, müşteri ya da kişi adı olmamalı; demo `demo.local` kullanır.

Ekran görüntülerinin altına bir not ekleyin: *"Run on ABAP Platform Trial 2025 (Linux, Unicode). Older and non-Unicode releases need to be verified separately."* (Not, ekran görüntüleriyle birlikte yayımlanacağı için İngilizce bırakıldı. Anlamı: ABAP Platform Trial 2025 (Linux, Unicode) üzerinde çalıştırıldı; daha eski ve Unicode olmayan sürümler ayrıca doğrulanmalıdır.)

## 7. Kapatma

Yeniden kullanacaksanız durdurun (yalnızca disk ücretlendirilir):
```bash
sudo docker stop -t 7200 a4h
```
```bash
gcloud compute instances stop sapimap-demo --zone=europe-west3-c
```

İşiniz bittiğinde silin (tüm ücretler durur):
```bash
gcloud compute instances delete sapimap-demo --zone=europe-west3-c
```

`docker stop` komutundaki uzun zaman aşımı (`-t 7200`), SAP HANA'nın verilerini diske yazmasına izin verir; makineyi doğrudan kapatmayın.
