# Sunucu kurulumu (Basis için)
> [English](../SERVER-SETUP.md) | **Türkçe**

> **Önceki sürüme ait başvuru:** Bu sayfa 1.0 örnekleri içerir. Güncel 1.1.0 yolları, iki script modülü, sistem/mandant ayrımlı parolalar ve izinler için [kurulum rehberinin Basis bölümünü](WALKTHROUGH.md#1-sunucuyu-hazırlayın-basis) izleyin. Aşağıdaki eski komutları güncel kurulum talimatı olarak kullanmayın.

SAP mail sunucusuyla hiçbir zaman kendisi konuşmaz. Konuşan, **SAP'nin kurulu olduğu makinedeki** küçük bir PowerShell betiğidir (SAP dokümanlarında bu makineye *uygulama sunucusu*, yani *application server* denir). SAP betiği SM69 komutlarıyla başlatır, betik `curl` ile IMAP üzerinden mail sunucusuyla konuşur ve her maili SAP'nin okuyacağı düz dosyalar olarak bırakır. Bu sayfa betiğin nereye konacağını, hangi hesaba hangi izinlerin verileceğini ve nelerin kontrol edileceğini anlatır.

Posta kutusu tarafı (mail ekibinden ne isteneceği) [MAILBOX-SETUP.md](MAILBOX-SETUP.md) sayfasındadır.

```
SAP work process (runs as the SAP OS user)
  │  SM69: ZIMAP_LIST / ZIMAP_FETCH / ZIMAP_DONE / ZIMAP_TEST
  ▼
<root>/bin/imap.ps1 ── curl ── IMAPS ──▶ mail server
  │ reads  <root>/bin/policy.psd1      (your limits)
  │ reads  <root>/conf/<PROFILE>.conf  (written by ZIMAP_CONFIG)
  │ reads  <root>/secret/<PROFILE>.cred
  └ writes <root>/in/<PROFILE>/<UID>/  (mail as files, read by SAP)
```

## 1. Gereksinimler

| | Windows uygulama sunucusu | Linux uygulama sunucusu |
|---|---|---|
| PowerShell | Windows PowerShell 5.1 (Windows Server 2016 ve sonrasında hazır gelir) | `/usr/bin/pwsh` yolunda PowerShell 7 (`pwsh`) |
| IMAPS destekli curl | `C:\Windows\System32\curl.exe` (Windows Server 2019 ve sonrasında hazır gelir) | Dağıtımın `/usr/bin/curl` programı |
| Betiği çalıştıran hesap | `SAP<SID>_<NN>` SAP servisinin hesabı (genelde `SAPService<SID>` ya da bir domain hesabı) | `<sid>adm` |
| Ağ | Uygulama sunucusundan mail sunucusuna: TCP 993 (IMAPS) ya da 143 (STARTTLS) | aynı |

curl'ü kendiniz kontrol edin: `curl --version` çıktısındaki protokol listesinde `imaps` bulunmalı.

Denenenler: Windows PowerShell 5.1 ile Windows 11 (betik testleri ve `setup-server.ps1`'in, SAP hesabı taklit edilerek bir test klasöründe baştan sona çalıştırılması; yerel bir mail sunucusuna bağlantı testi dahil) ve PowerShell 7.4 ile Linux (SAP akışının tamamı). Windows üzerindeki gerçek bir SAP sistemi henüz denenmedi.

## 2. Kurulum

Projeyi (bu repo ya da bir release zip) SAP'nin kurulu olduğu makineye kopyalayın, sonra proje klasöründen kurulum betiğini **yönetici / root olarak** çalıştırın.

**Windows** (yükseltilmiş yani yönetici PowerShell):
```bat
powershell -ExecutionPolicy Bypass -File server\setup-server.ps1 -AllowedHosts mail.example.com
```

**Linux:**
```bash
sudo bash server/setup-server.sh --sap-user <sid>adm --allowed-hosts mail.example.com
```

| Seçenek (Windows / Linux) | Anlamı |
|---|---|
| `-Root` / `--root` | Çalışma klasörü. Varsayılan `C:\sapimap` / `/usr/sap/sapimap`. `ZIMAP_INSTALL` içinde **Server folder** olarak aynı yolu girin. |
| `-AllowedHosts` / `--allowed-hosts` | SAP'nin bağlanabileceği mail sunucuları. İlk çalıştırmada zorunludur. Bu, şirketinizin mail sunucusunun, mail ekibinin verdiği **IMAP sunucu adıdır** (bkz. [MAILBOX-SETUP.md](MAILBOX-SETUP.md#3-talep-şablonu)); bir mail programının hesap ayarlarında da gelen (IMAP) sunucu olarak görünür. IP adresini değil sunucu adını kullanın: yönetici `ZIMAP_CONFIG` içinde **Server** alanına tam olarak bunu yazacak ve ad sunucunun sertifikasıyla uyuşmalı. Birden fazla sunucu: `-AllowedHosts a.example.com,b.example.com` / `--allowed-hosts a.example.com,b.example.com`. Sonradan değiştirmek için `policy.psd1` dosyasını düzenleyin. |
| `-SapAccount` / `--sap-user` | SAP iş süreçlerinin (work process) çalıştığı hesap. Windows bunu SAP servisinden kendisi bulur; Linux'ta verilmesi gerekir (`<sid>adm`). |
| `-AllowInsecure` / `--allow-insecure` | Profillerin sertifika kontrolünü kapatabilmesine izin verir. Yalnızca test sistemlerinde. |
| `-AllowPlainImap` / `--allow-plain` | Şifrelenmemiş IMAP'e izin verir. Önerilmez. |
| `-Force` / `--force` | Var olan `policy.psd1` dosyasının üzerine yazar. Verilmezse mevcut politikanız korunur. |
| `-SetPassword <PROFILE>` / `--set-password <PROFILE>` | Yalnızca, şifre kaynağı `O` olan bir profilin posta kutusu şifresini yazar (bkz. 6. bölüm). |

Demo sistemindeki çıktı:
```
== pwsh and curl check
7.4.6 / curl 7.66.0

== Folders: /usr/sap/sapimap
policy.psd1 written: allowed servers 'greenmail'

== Permissions (SAP user: a4hadm)

== Installation test
  VERSION 1.0.0
  STEP POLICY OK allowed: greenmail
  STEP CURL OK curl 7.66.0
  STEP FOLDERS OK
  OK

Server ready. On the SAP side:
  SE38 > ZIMAP_INSTALL > Server folder: /usr/sap/sapimap/
  Then define the mailbox profile with ZIMAP_CONFIG.
```

Betiği tekrar çalıştırmak güvenlidir: güncel `imap.ps1` dosyasını kopyalar, `policy.psd1` dosyasını korur (`-Force` verilmediyse) ve izinleri yeniden ayarlar.

## 3. Klasörler ve izinler

Kurulum betiği bu klasörleri oluşturur ve izinleri ayarlar; `icacls` ya da `chmod` komutlarını kendiniz çalıştırmanız gerekmez.

| Klasör | İçerik | SAP hesabı | Windows (ACL) | Linux (sahip, mod) |
|---|---|---|---|---|
| `bin` | `imap.ps1`, `policy.psd1` | okuma ve çalıştırma, **değiştiremez** | Administrators, SYSTEM: tam yetki; SAP hesabı: okuma ve çalıştırma | `root:root`, `755` (dosyalar `644`) |
| `conf` | profil ayarları, `ZIMAP_CONFIG` yazar | değiştirme | Administrators, SYSTEM: tam yetki; SAP hesabı: değiştirme | `<sid>adm:sapsys`, `750` |
| `secret` | posta kutusu şifreleri, `ZIMAP_CONFIG` ya da Basis yazar | değiştirme; **başka hiç kimse okuyamaz** | Administrators, SYSTEM: tam yetki; SAP hesabı: değiştirme; devralınan izinler kaldırılır | `<sid>adm:sapsys`, `700` |
| `in` | indirilen mailler, her mail için bir klasör | değiştirme | `conf` ile aynı | `<sid>adm:sapsys`, `750` |
| `done`, `tmp`, `log` | işlenmiş mailler, geçici dosyalar, log | değiştirme | `conf` ile aynı | `<sid>adm:sapsys`, `750` |

`bin` klasörü SAP için neden salt okunur: SAP betiği çalıştırabilir ama değiştiremez. Böylece SAP yetkileri üzerinden sunucuda kendi kodunu çalıştırmak isteyen kimse bunu yapamaz.

## 4. `policy.psd1`: sınırlarınız

`bin/policy.psd1`, SAP'nin aşamayacağı sınırdır. `ZIMAP_CONFIG` içindeki profiller betik her çalıştığında bu dosyaya göre kontrol edilir; sınırın dışına çıkan profil `ERR POLICY` ile reddedilir.

| Anahtar | Anlamı |
|---|---|
| `WorkDir` | Çalışma klasörü (kurulumdaki `Root` ile aynı). |
| `AllowedHosts` | Erişilebilecek tek mail sunucuları (küçük harfli adlar). |
| `AllowInsecure` | `$true`, profillerin sertifika kontrolünü kapatabilmesine izin verir. Üretimde `$false` bırakın. |
| `AllowPlainImap` | `$true`, şifrelenmemiş IMAP'e izin verir. `$false` bırakın. |
| `CaCert` | Mail sunucusunun sertifikası, işletim sisteminin güvenmediği şirket içi bir CA tarafından imzalanmışsa, şirket CA sertifika dosyasının yolu. Boşsa işletim sisteminin sertifika deposu kullanılır. |
| `CheckRevoke` | Yalnızca Windows: sertifika iptal listelerini (revocation list) kontrol eder. İptal sunucularına ulaşılamayan kapalı ağlarda genelde `$false` olur. |
| `CurlPath` | İsteğe bağlı: farklı bir curl programı. Varsayılan: Windows'ta `System32\curl.exe`, Linux'ta `/usr/bin/curl`. |
| `MaxMailBytes`, `RetentionDaysMax`, `TimeoutSecMax` | Mail boyutu, işlenmiş dosyaların saklama süresi ve IMAP zaman aşımı için üst sınırlar. Profiller bunlardan yüksek değer veremez. |

Dosyayı herhangi bir metin editörüyle düzenleyin; değişiklik bir sonraki çalıştırmada geçerli olur.

## 5. SAP'den kontrol

`ZIMAP_INSTALL` SM69 komutlarını oluşturduktan sonra kendi kendine testi **SM49**'da çalıştırabilirsiniz: komut `ZIMAP_TEST`, ek parametre yok. Son satır `OK` olmalı. Ek parametre olarak bir profil adı verirseniz (`ZIMAP_TEST DEMO`) o posta kutusuna bağlantıyı adım adım test eder; `ZIMAP_CONFIG` içinde F8 ile çalışan test de budur.

`ZIMAP_INSTALL` şu komutları tanımlar:

| | Windows | Linux |
|---|---|---|
| İşletim sistemi komutu | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` | `/usr/bin/pwsh` |
| Parametreler | `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File <root>\bin\imap.ps1 <action>` | `-NoProfile -NonInteractive -File <root>/bin/imap.ps1 <action>` |
| Ek parametreler | izinli (profil, UID) | izinli |

`<action>` yerine `list`, `fetch`, `done` ya da `test` gelir. Betik her ek parametreyi (profil adı, UID) kullanmadan önce sıkı bir kalıba göre kontrol eder.

## 6. Şifreler

Varsayılan olarak yönetici posta kutusu şifresini `ZIMAP_CONFIG` içinde yazar; SAP bunu `secret/<PROFILE>.cred` dosyasına yazar ve veritabanında saklamaz. Şifreyi Basis'in tutmasını istiyorsanız profilde **Password source = O** seçin ve şifreyi sunucuda yazın:

```bat
powershell -ExecutionPolicy Bypass -File server\setup-server.ps1 -SetPassword INVOICE
```
```bash
sudo bash server/setup-server.sh --sap-user <sid>adm --set-password INVOICE
```

Şifre ekranda görünmeden okunur. Hiçbir komut satırında geçmez: betik onu curl'e standart girdi (stdin) üzerinden iletir.

## 7. Birden fazla uygulama sunucusu

SM69 komutları ve dosya okumaları, iş sürecinin (work process) çalıştığı uygulama sunucusunda yürür. `ZIMAP_CONFIG` profil dosyalarını, oturum açtığınız sunucuya yazar; `ZIMAP_INBOUND` job'ı ise bu dosyaları kendi çalıştığı sunucuda okur. Birden fazla uygulama sunucusu varsa şu iki yoldan biri izlenir:

- Çalışma klasörünü tüm uygulama sunucularının paylaştığı bir depolama alanına koyun (hepsinde aynı yola bağlı) ve betiği her sunucuya bir kez kurun; ya da
- `ZIMAP_CONFIG` ile `ZIMAP_INBOUND` job'ını aynı sunucuda çalıştırın (logon group / job hedef sunucusu).

Bu kurulum henüz denenmedi; geri bildirim memnuniyetle karşılanır.

### Aynı makinede birden fazla SAP sistemi ya da client

Çalışma klasöründeki dosyalar yalnızca profil adıyla adlandırılır: `conf/INVOICE.conf`, `secret/INVOICE.cred`, `in/INVOICE/...`. SAP sistem kimliği (SID) ve client numarası dosya adında yer almaz.

- **Aynı SAP sisteminde birden fazla client** (örneğin 100 ve 200) aynı çalışma klasörünü kullanır. Profiller SAP'de client'a göre ayrı tutulur; yani iki client da `INVOICE` adında bir profil tanımlayabilir. Bu durumda sunucuda birbirlerinin ayarlarını ve şifresini ezerler. Profillere farklı adlar verin, örneğin `INVOICE_100` ve `INVOICE_200`.
- **Aynı makinede birden fazla SAP sistemi** (nadir bir durum; örneğin geliştirme ve test sisteminin aynı sunucuda olması): her sisteme ayrı bir çalışma klasörü verin, örneğin `C:\sapimap\DEV` ve `C:\sapimap\QAS`. Kurulum betiğini her klasör için bir kez çalıştırın (`-Root` / `--root`) ve her sistemde `ZIMAP_INSTALL` ekranındaki **Server folder** alanına o sistemin klasörünü girin.

İleriki bir sürümde sistem kimliği ve client numarası dosya adlarına otomatik eklenebilir.

## 8. Güncelleme ve kaldırma

- **Güncelleme:** yeni proje sürümünü sunucuya kopyalayın ve kurulum betiğini tekrar çalıştırın. `bin/imap.ps1` değişir, `policy.psd1` korunur. Ardından SAP'de yeni `ZIMAP_INSTALL`'u **Overwrite existing programs** işaretli çalıştırın. Betik ile SAP tarafının sürümleri farklıysa `ZIMAP_CONFIG` içindeki bağlantı testi uyarır.
- **Kaldırma:** `ZIMAP_INSTALL` içinde **Uninstall** çalıştırdıktan sonra `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE`, `ZIMAP_TEST` SM69 komutlarını ve çalışma klasörünü silin.

## 9. Sorun giderme

| Mesaj | Neden | Ne yapılır |
|---|---|---|
| `ERR CFG curl not found` | Varsayılan yolda curl yok | curl kurun ya da `policy.psd1` içinde `CurlPath` verin |
| `ERR CFG curl does not support IMAPS` | curl, IMAP/TLS desteği olmadan derlenmiş | `curl --version` çıktısında `imaps` olan bir curl kullanın |
| `ERR CFG folder missing` / `cannot write to folder` | Kurulum çalıştırılmamış ya da izinler değişmiş | Kurulum betiğini tekrar çalıştırın |
| `ERR POLICY server not allowed` | Profildeki sunucu `AllowedHosts` içinde yok | Onaylıysa `policy.psd1` dosyasına ekleyin |
| `ERR TLS` | Sertifikaya güvenilmiyor | Şirket CA'sını işletim sistemi deposuna kurun ya da `CaCert` verin |
| `ERR CONNECT` | DNS, firewall ya da port | Uygulama sunucusundan ad çözümlemesini ve firewall'u kontrol edin |
| SM49 hatası, SXPG'den çıkış kodu | Komut yok ya da `S_LOG_COM` yetkisi yok | `ZIMAP_INSTALL`'u tekrar çalıştırın; rolü kontrol edin |
