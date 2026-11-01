# Kurulum rehberi: posta kutusundan SAP'deki ilk sonuca

> [English](../WALKTHROUGH.md) | **Türkçe** · [Projeyi tanıyın](../../README.tr.md) · [Geliştirici rehberi](TECHNICAL-GUIDE.md)

Bu rehberi takip etmek ve hazır örneği denemek için ABAP yazmanız gerekmez. Bir modül danışmanı kurulumu koordine edebilir, posta kutusu bilgilerini girebilir, örneği çalıştırabilir ve sonucu inceleyebilir. Sunucu kurulumu ve SAP yetkileri için **Basis**, yani SAP sistem yönetimi ekibi gerekir. Kendi iş sürecinizi eklemek içinse bir ABAP geliştiricisine ihtiyaç vardır.

Hazır örnek e-postayı ve eklerini alır, sonucu kaydeder ve başarılı iletileri başka bir posta klasörüne taşır. Fatura oluşturmaz veya PDF içinden alan okumaz.

Bu rehber **1.1.0 kaynaklarını**, script protokolü **2**'yi anlatır. Ekran görüntüleri önceki **1.0** sürümünün SAP ABAP Platform Trial 2025, Linux/Unicode demosundandır. Ekranları bulmanıza yardımcı olur; güncel sürümün SAP'de test edildiğini göstermez. Alanlar ve başlıklar farklı olabilir.

## Başlamadan önce

Bir geliştirme veya deneme SAP sistemi ve **yalnız bu deneme için ayrılmış posta kutusu** kullanın. Normal işlem iletileri okundu işaretleyebilir ve taşıyabilir. Kişisel veya canlı iş posta kutusuyla başlamayın.

| Rehberdeki terim | Anlamı |
|---|---|
| Uygulama sunucusu | SAP'nin çalıştığı Windows veya Linux makine. Kendi bilgisayarınızdan farklıdır. |
| Basis | SAP sunucusu, kurulum ve yetkilerden sorumlu ekip. |
| Profil | Bir posta kutusuna ait bağlantı ve işleme ayarları. Örneğimiz `INVOICE`. |
| Handler | Her e-posta için ne yapılacağına karar veren ABAP programı. Başlangıçta hazır örneği kullanabilirsiniz. |
| Paket / transport | Geliştirme nesnelerini gruplama ve geliştirmeden test/canlı sisteme taşıma yöntemi. |
| UID | Posta sunucusunun, kutunun belirli bir nesli içindeki ileti numarası. |

| Adım | Kimden destek alınır? | Ne zaman devam edilir? |
|---|---|---|
| Posta kutusu hazırlığı | E-posta yöneticisi | Bağlantı bilgileri ve işlenmiş klasörü hazırsa. |
| [0. Sunucu hazırlığı](#0-sunucuyu-hazırlayın-basis) | Basis/sunucu yöneticisi | Sunucu öz testi başarılıysa. |
| [1. Kurulum programını oluşturma](#1-kurulum-programını-oluşturun) ve [2. çalıştırma](#2-kurulum-programını-çalıştırın) | SAP geliştirme yetkili kullanıcı | Seçili adımların tamamı başarılıysa. |
| [2b. Paket ve transport](#2b-canlıya-çıkmadan-önce-paket-ve-transport) | Geliştirici ve Basis | Projenin taşıma süreci belirlenmişse. |
| [3. Posta profili](#3-posta-kutusu-profilini-tanımlayın) | Yetkilendirilmiş danışman/yönetici | Bağlantı testi başarılıysa. |
| [4. İlk çalıştırma](#4-e-postayı-işleyin) ve [5. izleme](#5-e-postaları-ve-ekleri-izleyin) | Danışman/operasyon | Deneme iletisi `S` durumuna ulaşmışsa. |
| [6. Zamanlama](#6-düzenli-çalışmayı-zamanlayın) | Basis/operasyon | Gerçek job kullanıcısıyla arka plan testi başarılıysa. |

İşlem kodlarını SAP GUI'nin komut alanına yazın. Örneğin `SE38`; başka bir işlemin içindeyseniz `/nSE38`. Ekran adları oturum diline göre değişir; görseller İngilizcedir. **Execute**, çalıştır; **Create**, oluştur; **Activate**, etkinleştir anlamındadır.

### Proje dosyalarını alın

[GitHub deposunu](https://github.com/Cheditte/abap-imap-inbound) açın, **Code → Download ZIP** seçin ve arşivin tamamını bir klasöre çıkartın. Bu yöntem için Git kurmanız gerekmez. Klasör düzenini koruyun: Basis'e `server/` ile `script/` birlikte, geliştiriciye ana klasördeki `ZIMAP_INSTALL.abap` gerekir. Farklı indirmelerin sürümlerini karıştırmayın.

**E-posta adresi ve doğru parola tek başına yeterli olmayabilir.** Hesabın IMAP erişimine izin verilmeli ve giriş yöntemi bu projeyle uyumlu olmalıdır. İki adımlı doğrulama veya kurum politikası normal parolayla bağlantıyı engelleyebilir. Posta ekibinden doğrulama alın; OAuth zorunluysa bu sürüm kullanılamaz. [Posta kutusu uygunluğu ve klasör açıklaması](../../README.tr.md#başlamadan-önce-posta-kutunuz-uygun-mu).

### E-posta ekibine gönderebileceğiniz talep

> SAP'nin IMAP üzerinden okuyacağı ayrı bir deneme posta kutusu rica ediyoruz. Giriş adı, IMAP sunucu adı, port ve şifreleme türünü paylaşabilir misiniz? Sunucu kullanıcı adı/parola ile girişe ve UID MOVE işlemine izin vermeli. Bu posta kutusunun içinde, Gelen Kutusu gibi SAP-Processed adlı bir posta klasörü oluşturulmalı; sunucu diskinde veya yerel Outlook arşivinde değil. Hesabın IMAP erişimine ve bu projeyle uyumlu kullanıcı adı/parola yöntemine izin verildiğini doğrulayın. Parolayı kurumun onaylı gizli bilgi paylaşım yöntemiyle iletin. İç sertifika otoritesi kullanılıyorsa gerekli CA sertifikalarını Basis'e verin. SAP gelen iletileri okuyacak, başarıyla işlenenleri SAP-Processed klasörüne taşıyacak.

| Bilgi | Örnek | Ne anlama gelir? |
|---|---|---|
| Sunucu | `mail.example.com` | Gelen posta sunucusunun sertifikayla eşleşen adı. |
| Port / güvenlik | `993` / `IMAPS` | Başından itibaren şifreli bağlantı. `143` / `STARTTLS` da desteklenir. |
| Kullanıcı | `invoices@example.com` | Ekibin verdiği giriş adı; görünen e-posta adresinden farklı olabilir. |
| Kaynak klasör | `INBOX` | Gelen iletilerin bulunduğu klasör. |
| İşlenmiş klasörü | `SAP-Processed` | Başarılı iletilerin taşınacağı klasör; önceden oluşturun. |

**Tablodaki sunucu, kullanıcı ve port değerleri biçim örneğidir; kurulum verisi olarak kopyalamayın.** Gerçek değerleri posta ekibinden alın. `SAP-Processed` önerilen klasör adıdır; başka ad seçerseniz önce o klasörü oluşturun ve SAP profilinde aynı adı kullanın.

OAuth uygulanmadı. **UID MOVE** gerekir; `COPY` alternatifi kapalıdır. Klasör adları ASCII harf/rakam ve `. _ / -` kabul eder; boşluk içeremez. Eski posta sunucularıyla uyum için ASCII parola tercih edin. Parolaları talep kayıtlarına ve ekran görüntülerine koymayın.

### Basis'e gönderebileceğiniz talep

> Bu kurulum ve arka plan job'ı için bir SAP uygulama sunucusu seçilmesini rica ediyoruz. SAP'nin işletim sistemi hesabını doğrulayın, gerekiyorsa PowerShell/curl kurun, posta sunucusunun IMAP portuna dışarı yönlü erişimi sağlayın ve projedeki sunucu kurulum scriptiyle korumalı çalışma klasörünü hazırlayın. ZIMAP_INSTALL'a gireceğimiz klasör yolunu paylaşın. Kurulum, profil bakımı, işleme ve izleme için gerekli SAP rollerini atayın. Örneklerdeki SID, mandant, hesap ve yollar sistemimize göre değiştirilmeli.

Kurulum seçilen sunucunun adını kaydeder. Ayarlar, işleme ve izleme bu sunucuda çalışmalıdır. Basis'in size o sunucuya özel SAP bağlantısı vermesi gerekebilir. Proje programları ve SM69 komutları mandantlar arasında ortaktır; güncellemeleri diğer sahiplerle koordine edin.

## 0. Sunucuyu hazırlayın (Basis)

**Komutları nasıl kullanacaksınız?** İşletim sisteminize uygun bloğun tamamını, açılış ve kapanış süslü parantezleriyle birlikte kopyalayın. Sorulduğunda yalnız kendi değerinizi yazıp Enter basın; yanıtın etrafına tırnak veya köşeli parantez eklemeyin. Sunucu/port posta ekibinden, SAP hesabı ve klasör Basis'ten alınır. Her blok bilgileri tekrar sorar; önceki terminal değişkenlerine bağlı değildir. `ZIMAP_INSTALL`, `ZIMAP_CONFIG`, `ZIMAP_INBOUND`, `ZIMAP_MONITOR` ve `ZIMAP_HANDLER_DEMO` gerçek program adlarıdır ve değiştirilmez.

**Komutları SAP uygulama sunucusunda çalıştırın; danışmanın bilgisayarında değil.** Güncel deponun `server` ve `script` klasörlerini birlikte kullanın. Kurulum hem `imap.ps1` hem `mime.ps1` dosyasını yerleştirir.

Bağlantıyı o sunucudan kontrol edin. Windows örneği:

**Bu komut bloğu gerçek sunucu adını ve portu çalışırken sorar.** Posta ekibinin verdiği değerleri yazıp Enter basın; e-posta adresinizi veya SAP sunucunuzun adını yazmayın. Boş değerle bağlantı testi başlamaz. Kurulumdaki `-AllowedHosts` / `--allowed-hosts` ve SAP profilindeki **Server / Sunucu** alanı için de aynı IMAP sunucu adını kullanın.

```powershell
& {
  $ImapHostName = (Read-Host 'Posta ekibinin verdigi IMAP sunucu adi').Trim()
  $ImapPort = (Read-Host 'Posta ekibinin verdigi IMAP portu').Trim()
  if (@($ImapHostName, $ImapPort) -contains '') {
    throw 'Bilgiler bos birakilamaz. Ilgili ekipten alip tekrar calistirin.'
  }
  Test-NetConnection -ComputerName $ImapHostName -Port ([int]$ImapPort)
}
```

`TcpTestSucceeded : True`, TCP bağlantısını gösterir; girişin veya sertifikanın doğru olduğunu göstermez. Başarısızsa sunucu/ağ ekibi DNS, yönlendirme, güvenlik duvarı ve posta servisini kontrol etmelidir. Gereken bağlantı SAP sunucusundan IMAP portuna dışarı yönlüdür.

### Windows

PowerShell 5.1 veya üzeri ve `curl.exe --version` çıktısında `imaps` bulunan bir curl gerekir. Windows PowerShell'de `curl.exe` yazın; `curl` başka bir komutu ifade edebilir.

Depo klasöründen, yönetici PowerShell oturumunda aşağıdaki bloğu çalıştırın. Sorulduğunda posta ekibinin IMAP sunucusunu, Basis'in doğruladığı Windows SAP hesabını ve tam çalışma klasörünü girin. Boş yanıtla kurulum başlamaz.

```powershell
& {
  $ImapHostName = (Read-Host 'Posta ekibinin verdigi IMAP sunucu adi').Trim()
  $SapOsAccount = (Read-Host 'Basis tarafindan dogrulanan Windows SAP servis hesabi').Trim()
  $ImapRoot = (Read-Host 'Basis tarafindan onaylanan tam calisma klasoru yolu').Trim()
  if (@($ImapHostName, $SapOsAccount, $ImapRoot) -contains '') {
    throw 'Bilgiler bos birakilamaz. Ilgili ekipten alip tekrar calistirin.'
  }
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File server\setup-server.ps1 `
    -AllowedHosts $ImapHostName -SapAccount $SapOsAccount -Root $ImapRoot
}
```

Hesap sorusuna Basis'in doğruladığı tam servis hesabını yazın; `DOMAIN\SAPServiceA4H` yalnız biçim örneğidir. Birden fazla SAP örneği bulunan makinelerde hesabı açıkça vermek belirsizliği önler. curl farklı bir konumdaysa Basis `-CurlPath` parametresine sunucudaki gerçek `curl.exe` dosyasının tam yolunu vermelidir; yol boşluk içeriyorsa tırnak içine alınır.

Varsayılan kök klasör `C:\sapimap`. Yukarıdaki blok klasör yolunu ayrıca sorar; Basis hangi yolu onayladıysa onu girin. Öz test, parola kaydetme ve SAP kurulumunda aynı yolu kullanın. Kısa yol seçin: SAP kök alanı 60 karakterdir; eski harici komut arayüzlerinin toplam parametre sınırı da vardır. Kontrolü geçmek için üst klasör izinlerini gevşetmeyin.

Öz testi çalıştırın. Klasör sorusuna kurulumda kullandığınız tam yolu tekrar girin:

```powershell
& {
  $ImapRoot = (Read-Host 'Basis tarafindan onaylanan tam calisma klasoru yolu').Trim()
  if (@($ImapRoot) -contains '') {
    throw 'Bilgiler bos birakilamaz. Ilgili ekipten alip tekrar calistirin.'
  }
  powershell.exe -NoProfile -File (Join-Path $ImapRoot 'bin\imap.ps1') test
}
```

Başarılı çıktı `PROTOCOL 2`, `VERSION 1.1.0` ve seçilen kökü belirtir; `OK` ile biter. Yönetici hesabıyla bu test yararlıdır; ileride SAP kurulum programının testi gerçek SAP çalışma hesabıyla da geçmelidir.

### Linux

PowerShell (`pwsh`) ve IMAPS destekli curl kurun. Oluşturulan SM69 komutu `/usr/bin/pwsh` bekler. SAP'nin gerçek çalışma kullanıcısını doğrulayın; `a4hadm` örnektir.

Depo klasöründen Bash içinde aşağıdaki bloğu çalıştırın. Sunucu adı posta ekibinden, Linux SAP kullanıcısı ve tam çalışma klasörü Basis'ten alınır; her soruya kendi değerinizle yanıt verin.

```bash
{
  read -r -p 'Posta ekibinin verdigi IMAP sunucu adi: ' imap_host
  read -r -p 'Basis tarafindan dogrulanan Linux SAP kullanicisi: ' sap_os_user
  read -r -p 'Basis tarafindan onaylanan tam calisma klasoru yolu: ' imap_root
  sudo bash server/setup-server.sh \
    --allowed-hosts "${imap_host:?IMAP hostname is required}" \
    --sap-user "${sap_os_user:?SAP OS user is required}" \
    --root "${imap_root:?Working folder is required}"
}
```

Varsayılan kök `/usr/sap/sapimap`. Üst klasörlerden biri root dışındaki kullanıcı/gruplar tarafından yazılabiliyorsa kurulum yolu reddeder. Basis, uygun olduğunda `--root /opt/sapimap` gibi üst klasörleri korumalı, onaylı bir yer seçip her adımda aynı yolu kullanmalıdır. Kontrolü geçmek için mevcut SAP klasörlerinin sahipliğini değiştirmeyin.

Seçilen kökü SAP'nin çalışma kullanıcısıyla test edin. İki soruya önceki kurulumdaki Linux kullanıcı adı ve tam klasör yoluyla yanıt verin:

```bash
{
  read -r -p 'Basis tarafindan dogrulanan Linux SAP kullanicisi: ' sap_os_user
  read -r -p 'Basis tarafindan onaylanan tam calisma klasoru yolu: ' imap_root
  sudo -u "${sap_os_user:?SAP OS user is required}" /usr/bin/pwsh \
    -NoProfile -File "${imap_root:?Working folder is required}/bin/imap.ps1" test
}
```

Çıktı protokol `2`, sürüm `1.1.0` ve seçilen kökü belirtip `OK` ile bitmelidir. Bu yerel ön koşulları kontrol eder; SAP kurulumu ve posta bağlantısı sonraki adımlardadır.

### Sertifika ve danışmana teslim

TLS sertifika doğrulamasını açık tutun. Basis kullanılan curl sürümünün güven deposunu veya `bin/policy.psd1` içindeki `CaCert` üzerinden onaylı CA dosyasını hazırlamalıdır. Windows Schannel ve diğer curl TLS altyapılarının güven mekanizması farklı olabilir.

Basis, danışmana kök klasörü, seçilen SAP sunucusunu ve öz testin başarılı olduğunu iletir. Bu teslim bilgisinde parola bulunmaz.

## 1. Kurulum programını oluşturun

Bu adım SAP geliştirme yetkisi gerektirir. Yetkiniz yoksa aşağıdaki adımları bir geliştiriciye iletin.

1. SAP GUI'de **SE38** açın.
2. Program adı **`ZIMAP_INSTALL`** girip **Create / Oluştur** seçin.
3. Açıklama girin, **Executable program / Çalıştırılabilir program** seçin ve kaydedin.
4. Tek seferlik deneme için **Local Object / Yerel Nesne** (`$TMP`) seçebilirsiniz. Kalıcı kullanım için Basis/geliştiriciyle `ZIMAP` gibi bir müşteri paketi oluşturup installer'ı oraya kaydedin.
5. [ZIMAP_INSTALL.abap](../../ZIMAP_INSTALL.abap) dosyasının tamamını kopyalayıp SAP editörüne yapıştırın.
6. Kaydedin, sözdizimi kontrolü yapın ve etkinleştirin. SAP derleme hatası varsa çalıştırmadan çözün.

![SE38: kurulum programının oluşturulması](../screenshots/01-se38-create.png)

Bu programı bir pakete kaydetmek üretilen nesneleri o pakete atamaz. Kurulum programı bunları şu anda `$TMP` içinde oluşturur. Kalıcı kullanım için [2b adımını](#2b-canlıya-çıkmadan-önce-paket-ve-transport) izleyin.

## 2. Kurulum programını çalıştırın

**SE38** içinde `ZIMAP_INSTALL` girip **Execute / Çalıştır (F8)** seçin.

![Önceki 1.0 demosunun kurulum ekranı](../screenshots/02-install-screen.png)

Geliştirme sistemindeki ilk kurulum için:

| Seçenek | Ne seçilir / ne yapar? |
|---|---|
| DDIC objects | Seçili. Projenin tablolarını, yapılarını, veri elemanlarını ve domain'lerini oluşturur. |
| Programs | Seçili. Ayar, işleme, izleme, include ve örnek handler programlarını oluşturur. |
| SM69 commands | Seçili. SAP'nin scripti başlatacağı komutları oluşturur. |
| Server check | Seçili ve zorunlu. SAP'nin beklenen script sürümünü ve kökü çalıştırabildiğini kontrol eder. |
| Overwrite programs | Yedekleme/inceleme sonrası planlı güncellemede kullanın; yerel değişiklikleri değiştirebilir. |
| Server folder | Basis'in verdiği kök; örneğin `C:\sapimap\` veya `/usr/sap/sapimap/`. |
| I/O mode / code page | Geliştirici başka seçim önermedikçe otomatik bırakın. Eski sistemlerin dosya okuma biçimini etkiler. |
| Uninstall | Seçmeyin. Mandantlar arası ortak nesneleri kaldırır; profil sıfırlama değildir. |

Çalıştırın ve sonuç listesinin tamamını okuyun. Seçili adımlar ve son sunucu kontrolü başarılıysa devam edin. Hata varsa çıktıyı Basis/geliştirme ekibine verin.

Yalnız SM69/sunucu adımları seçilse de geliştirme yetkileri kontrol edilir. Kurulum uygun durumlarda yedeklenen program/metin ve SM69 kayıtlarını geri alır; tam veritabanı işlemi veya sistem yedeği değildir. Başarısız güncellemede DDIC değişikliklerini ve yeni nesneleri gözden geçirin.

## 2b. Canlıya çıkmadan önce: paket ve transport

`$TMP` deneme için uygundur; nesneleri normal paket transport sürecine girmez. Kalıcı kullanım için geliştirme ve Basis ekibiyle kurumunuzun müşteri paketini ve taşıma sürecini kullanın.

1. **Geliştirme sisteminde**, **SE21** veya **SE80** üzerinden `ZIMAP` gibi bir paket oluşturun. Transport katmanını Basis belirlesin.
2. Burada kurup test edin. Mevcut installer ürettiği nesneleri `$TMP` içine koyar.
3. Proje nesnelerini listeleyin: installer, program/include'lar, tablo/yapılar, veri elemanları, domain'ler ve kendi handler'ınız. `ZIMAP*` ile eşleşen ilgisiz nesneleri körlemesine seçmeyin.
4. **SE03 → Change Object Directory Entries** veya uygun **SE80 → Reassign** işlemiyle projeye ait nesneleri pakete atayın ve transport talebinde toplayın. Talep yalnız installer'ı değil, tanımları ve bağımlılıkları da içermelidir.
5. **Test sistemine** aktarın, o sistemin sunucusunu ve yerel ayarlarını hazırlayın, ilk kullanım kontrollerini tekrarlayın. Ardından onaylı canlıya taşıma sürecini izleyin.

**Bu paket/transport yolu projeyle uçtan uca henüz denenmedi.** Güvenmeden önce kendi sistem zincirinizde doğrulayın.

ABAP nesnelerinin transport'u PowerShell'i, işletim sistemi dosyalarını, klasör izinlerini veya parolaları kurmaz. Basis her hedefte SM69 yollarını/yetkilerini incelemeli; profil ve parolaları ilgili sistem/mandant için hazırlamalıdır.

Yalnız sunucu modunun değişikliğe kapalı canlıda çalışacağını varsaymayın: mevcut installer geliştirme yetkisini ve kaynak tutarlılığını yine kontrol eder. Hedef sistem kurulumunu önceden kararlaştırıp test edin; rehber canlı değişiklik kontrollerinin gevşetilmesini gerektirmez.

SAP kaynakları: [Nesne dizini ve paket değiştirme](https://help.sap.com/docs/SAP_NETWEAVER_700/109ce05a6c531014b4e8fe6b0570a984/5738e06c4eb711d182bf0000e829fbfe.html), [harici komutların bakımı](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_752/b17bd20044a44edb9aa7830ee52ffac3/c43a607b505211d189550000e829fbbd.html?locale=en-US&state=PRODUCTION&version=7.52.latest).

## 3. Posta kutusu profilini tanımlayın

**SE38 → `ZIMAP_CONFIG` → Çalıştır** açın. Basis'in verdiği profil bakım rolünü ve seçilen sunucuya bağlı SAP oturumunu kullanın.

Bir profil adı seçin (örneğin **`INVOICE`**) ve posta ekibinin verdiği değerleri girin. Profilin adı örneği bir fatura uygulamasına dönüştürmez.

`INVOICE` seçebileceğiniz bir **örnek profil adıdır**. Kendi adınızı seçebilirsiniz; sonraki çalıştırmalarda, job varyantında ve parola anahtarında kaydettiğiniz adı aynen kullanın. Sunucu/kullanıcı/port kendi posta kutunuza aittir. `ZIMAP_HANDLER_DEMO` ve `MOVE` bu ilk deneme için aynen seçilir. `50`, `20`, `120`, `30` başlangıç sınırlarıdır; süreç gereksinimine ve Basis politikasına göre belirlenir.

![Önceki profil ekranı; GreenMail değerleri deneme verisidir](../screenshots/04-config-profile.png)

| Alan | İlk deneme örneği | Açıklama |
|---|---|---|
| Profil / aktif | `INVOICE` / seçili | Ayarların adı; aktif profiller işlenebilir. |
| Sunucu / port | Kendi IMAP sunucunuz / portunuz | İkisini de posta ekibinden alın; örnek adresi kopyalamayın. |
| Güvenlik / sertifika doğrula | Posta ekibinin verdiği tür / seçili | `IMAPS` veya `STARTTLS` seçimi portla uyumlu olmalıdır. Doğrulamayı açık tutun. |
| Kullanıcı | Kendi posta giriş adınız | Posta ekibinin verdiği giriş adını yazın; örnek e-posta adresini kullanmayın. |
| Parola kaynağı | `S` veya `O` | `S`: SAP'de girilir. `O`: Basis sunucuda saklar. |
| Gelen / işlenmiş klasörü | Posta kutunuzdaki gerçek klasör adları | Örneğin `INBOX` / `SAP-Processed`; iki klasör de mevcut olmalıdır. |
| Taşıma modu | `MOVE` | UID MOVE desteği gerekir. |
| Handler programı | `ZIMAP_HANDLER_DEMO` | Hazır örnek; iş belgesi oluşturmaz. |
| En çok ileti | `50` | Bir çalıştırmadaki örnek üst sınır. |
| En çok boyut | `20` | İleti başına örnek MiB sınırı; sunucu politikası daha düşük olabilir. |
| Zaman aşımı | `120` | Örnek ağ zaman aşımı, saniye. |
| Saklama süresi | `30` | Tamamlanmış yerel arşivler için gün; SAP logunu veya uzaktaki postayı silmez. |

### Parolayı SAP'de girin veya Basis'e bırakın

**`S` kaynağında** parolayı SAP'de girersiniz. SAP tablosuna değil, işletim sistemi izinleriyle korunan düz metin parola dosyasına yazılır. Bu giriş için normal varyant kaydetme ve yazdırma kapatılır. Gerekli SAP koruma API'si yoksa yeni parola girişi kapalıdır; `O` kullanın. Yeni parolayı arka plan varyantıyla girmeyin.

**`O` kaynağında** Basis'e tam **`SID_MANDANT_PROFIL`** anahtarını verin. Sistem `A4H`, mandant `001`, profil `INVOICE` ise anahtar **`A4H_001_INVOICE`** olur. SID ve mandantı **Sistem → Durum / System → Status** altında görebilirsiniz.

Basis sunucuda depo klasöründen işletim sistemine uygun bloğu çalıştırır. Önce gerçek tam profil anahtarı, SAP işletim sistemi hesabı ve kurulumdaki tam klasör yolu sorulur. `A4H_001_INVOICE` değerini aynen kopyalamayın; kendi SID/mandant/profilinizden oluşturun. Parolayı kurulum aracı daha sonra ayrıca sorar; komuta yazmayın.

```powershell
& {
  $ProfileKey = (Read-Host 'Bu sistem ve mandant icin tam SID_CLIENT_PROFILE anahtari').Trim()
  $SapOsAccount = (Read-Host 'Basis tarafindan dogrulanan Windows SAP servis hesabi').Trim()
  $ImapRoot = (Read-Host 'Basis tarafindan onaylanan tam calisma klasoru yolu').Trim()
  if (@($ProfileKey, $SapOsAccount, $ImapRoot) -contains '') {
    throw 'Bilgiler bos birakilamaz. Ilgili ekipten alip tekrar calistirin.'
  }
  powershell.exe -NoProfile -File server\setup-server.ps1 `
    -SetPassword $ProfileKey -SapAccount $SapOsAccount -Root $ImapRoot
}
```

```bash
{
  read -r -p 'Bu sistem ve mandant icin tam SID_CLIENT_PROFILE anahtari: ' profile_key
  read -r -p 'Basis tarafindan dogrulanan Linux SAP kullanicisi: ' sap_os_user
  read -r -p 'Basis tarafindan onaylanan tam calisma klasoru yolu: ' imap_root
  sudo bash server/setup-server.sh \
    --set-password "${profile_key:?Full profile key is required}" \
    --sap-user "${sap_os_user:?SAP OS user is required}" \
    --root "${imap_root:?Working folder is required}"
}
```

Sunucudaki parola dosyası `USER` içeriyorsa boş olmalı veya profildeki kullanıcıyla tam eşleşmelidir. SAP'nin işletim sistemi hesabı ve ayrıcalıklı yöneticiler bu dosyalara erişebilir; koruma dosya izinleridir, parola kasası değildir.

### Kaydedin ve test edin

**Çalıştır (F8)** seçin. Program önce profili yayımlar, sonra bağlantıyı test eder. **Ayarların kaydedilmesi bağlantının başarılı olduğu anlamına gelmez.** Test sonucunu da okuyun.

| Hatanın konusu | Kime iletilir? | Ne kontrol edilir? |
|---|---|---|
| İzin verilmeyen sunucu / kök / yanlış makine | Basis | Politika, seçilen sunucu, yol ve yetkiler. |
| Bağlantı / zaman aşımı | Basis/ağ ekibi | DNS, yönlendirme, port, güvenlik duvarı ve posta servisi. |
| Sertifika / TLS | Basis/posta ekibi | Sunucu adı, sertifika zinciri/süresi ve curl güveni. Doğrulamayı açık tutun. |
| Giriş | Posta ekibi/Basis | Giriş adı, kimlik doğrulama politikası ve parola kaynağı. |
| Klasör / UID MOVE | Posta ekibi | İki klasörün varlığı ve UID MOVE desteği. |

## 4. E-postayı işleyin

Deneme kutusuna küçük PDF veya metin eki bulunan bir ileti gönderin. Konu örneği: `First SAP mail test`.

1. **SE38 → `ZIMAP_INBOUND` → Çalıştır** açın.
2. Üçüncü adımda kaydettiğiniz profil adını girin. Yalnız gerçekten `INVOICE` adıyla kaydettiyseniz `INVOICE` yazın.
3. **List only (no downloads/changes)**, yani yalnız listeleme seçeneğini işaretleyip çalıştırın.
4. Uygun ileti UID'lerinin listelendiğini görün. Bu mod posta indirmez/önizlemez, handler çağırmaz, taşıma veya arşiv temizliği yapmaz.
5. Geri dönün, yalnız listeleme işaretini kaldırıp normal çalıştırın.

![Önceki işleme ekranı; güncel test modu yalnız uygun UID'leri listeler](../screenshots/06-inbound-screen.png)

Normal demo postayı indirip ayrıştırır, ekleri okur, sonucu kaydeder ve başarılı iletiyi profilde belirttiğiniz işlenmiş klasörüne taşır. İndirme iletiyi okundu işaretleyebilir.

Monitörü ve posta kutusunu kontrol edin: başarılı sonuç **`S`** olmalı, ileti işlenmiş klasöründe bulunmalıdır. Konusunda **`TEST-ERROR`** olan iletiler örnek handler'da bilerek hata verir.

## 5. E-postaları ve ekleri izleyin

**SE38 → `ZIMAP_MONITOR` → Çalıştır** açın. Profil ve tarih aralığını seçip çalıştırın. Sorgu başına en çok **1.000 kayıt** gösterilir; gerekirse seçimi daraltın.

![Önceki demonun izleme listesi](../screenshots/08-monitor-list.png)

| Durum | Anlamı | Ne yapılır? |
|---|---|---|
| `S` | Handler başarılı, posta taşıması tamam. | Gerekiyorsa sonucu inceleyin. |
| `E` | Handler başarısı tamamlanmadan işleme hata verdi. | Nedeni düzeltin ve yeniden denemeyi yetkilendirin. |
| `R` | Hata yeniden deneme için işaretlendi. | Normal çalıştırma tekrar dener. |
| `H` | Handler başarısı kaydedildi, posta taşıması bekliyor. | Taşıma sorununu çözün; normal işlem tamamlanmış handler'ı bilerek tekrar çağırmadan taşımayı sürdürür. |

Bir kaydı açıp ayrıntılarını, gövdesini ve ek listesini inceleyin. **PDF, PNG, JPG/JPEG, GIF, BMP ve TXT** bilgisayarınızdaki ilişkili görüntüleyiciyle açılabilir. Excel ve özgün `.eml` dahil diğer türler **yalnız indirilir**; kaydedip uygun uygulamada açın. Eski otomatik `.eml` açma görselleri güncel davranışı göstermez.

Log kayıtları dosyalardan daha uzun süre kalabilir. Saklama süresi tamamlanmış yerel arşivleri temizler; `ZIMAP_LOG` veya uzak işlenmiş klasörünü temizlemez. Bunların saklama süresini veri sahipleriyle ayrıca belirleyin.

### Hata ve yeniden deneme alıştırması

1. Konusunda `TEST-ERROR` bulunan ileti gönderip demo handler ile normal çalıştırın.
2. Bilerek oluşan hatayı monitörde inceleyin.
3. Bir geliştiriciyle nedeni düzeltin veya bu iletiyi kabul eden onaylı deneme handler'ını seçin. Yeniden deneme işareti demonun kuralını değiştirmez.
4. Yetkili monitör kullanıcısı yeniden deneme işlemini seçer. Kayıt `R` olur; normal işleme çalıştırın.

Yeniden deneme log değiştirme yetkisi gerektirir. İşleme ekranındaki **retry errors** seçeneği de seçilen `E` iletilerini bilerek tekrar denemek içindir. `H`, taşıma kurtarmasıyla ele alınır. Tekrar çalıştırmak için log satırlarını veya sunucu dosyalarını silmeyin.

## 6. Düzenli çalışmayı zamanlayın

Basis'ten **SM36** ile `ZIMAP_INBOUND` job'ı oluşturmasını isteyin. Varyantta doğru profil seçili, **yalnız listeleme kapalı** olmalıdır. Sıklığı operasyon ekibiyle belirleyin.

Kurulumun uygulama sunucusunu kullanın. Gerçek, kısıtlı job kullanıcısıyla test edin; geliştirici hesabında önden çalışması yeterli değildir. Basis harici komut, dosya, tablo ve handler'a özel yetkileri kontrol eder. [Rol özeti](../../README.tr.md#yetkiler-ve-işletim-sınırları) README'dedir.

Gerçek iş postalarından önce ABAP geliştiricisi iş kurallarını uygulayıp doğrulamalıdır. Arayüz [geliştirici rehberinde](TECHNICAL-GUIDE.md) anlatılır. Hazır demoyu gösterim amacıyla kullanın.

## 7. Teknik başvuru: SAP hangi komutları çalıştırır?

Bu isteğe bağlı bölüm Basis/geliştirme ekibinin teşhisi içindir; canlı postaya elle komut çalıştırma talimatı değildir.

| SM69 adı | Script işlemi ve sıralı parametreleri |
|---|---|
| `ZIMAP_TEST` | `test`; profil testi için isteğe bağlı `KEY REVISION`. |
| `ZIMAP_LIST` | `list KEY REVISION`; normal SAP çalışması tamamlanmış yerel arşiv temizliği için `PURGE` ekler. Diğer durumda listeleme salt okunurdur. |
| `ZIMAP_FETCH` | `fetch KEY UID UIDVALIDITY REVISION` |
| `ZIMAP_DONE` | `done KEY UID UIDVALIDITY REVISION` |

`KEY`, SID/mandant/profil içerir. Revizyonları SAP yönetir; elle değiştirmeyin. MIME testlerinin ayrı yerel giriş noktası vardır; üretim SM69 komutu değildir.

## 8. Mevcut kurulumu güncelleyin

1.1.0 script protokolünü, profil dosya adlarını ve revizyon saklamasını değiştirir. 1.0 güncellemesini önce geliştirme/testte planlayın.

1. Zamanlanmış işlemeyi durdurun; ortak kurulumu kullanan mandantlarla koordine edin. SAP nesneleri/ayarları/logları, politika, parolalar ve posta klasörlerini onaylı yöntemle yedekleyin.
2. Bekleyen `H` kayıtlarını Basis/geliştirme ekibiyle inceleyin. Eski, sistem/mandant ayrımı olmayan klasörler korunur; **otomatik taşınmaz**. Devam etmeden kayıt/dosya eşleştirmesini planlayın; silerek veya tamamlanmış iş mantığını tekrar çalıştırarak geçmeyin.
3. Aynı sürümden **hem** `imap.ps1` **hem** `mime.ps1` yerleştirin; politikayı koruyup gözden geçirin. SAP nesne ve komutlarını test edilmiş paket/transport süreciyle güncelleyin. SAP ve script protokol `2` kullanmalıdır.
4. Sunucuyu, rolleri ve profilleri kontrol edin. Profilleri tekrar kaydedip `S` parolalarını yeniden girin. `O` parolalarını tam `SID_MANDANT_PROFIL` anahtarıyla oluşturun.
5. Sunucu, bağlantı, salt okunur liste, normal demo, hata/tekrar deneme ve bekleyen taşıma kurtarma kontrollerini yapın. Job kullanıcısı ve iş handler'ını doğrulayıp job'ları yeniden açın.

Posta geçmişi olan profil başka kutuya yönlendirilemez veya silinemez. Posta kimliği değişecekse profili pasifleştirip yenisini oluşturun.

[Doğrulama sınırları](../../README.tr.md#neler-doğrulandı) ve [geliştirici rehberine](TECHNICAL-GUIDE.md) bakın. Diğer başvuru belgelerinde eski 1.0 örnekleri bulunabilir; güncel kurulum yolu bu rehberdir.
