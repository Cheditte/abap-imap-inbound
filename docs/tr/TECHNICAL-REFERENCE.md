# Teknik başvuru: bağlantı, işletim ve testler

> [English](../TECHNICAL-REFERENCE.md) | **Türkçe** · [Projeyi tanıyın](../../README.tr.md) · [Kurulum](WALKTHROUGH.md) · [Kod örnekleri](TECHNICAL-GUIDE.md)

Bu dosya, kurulumu hazırlayan Basis ve e-posta ekipleri ile ayrıntıları incelemek isteyen geliştiriciler içindir. **0.9.1 kaynaklarını ve betik protokolü 2'yi** anlatır. Sırayla kurulum yapmak için [adım adım rehberi](WALKTHROUGH.md), kendi iş mantığınızı eklemek için [geliştirici rehberini](TECHNICAL-GUIDE.md) kullanın.

SAP adımlarında okuyucunun SE38 ile program oluşturup etkinleştirebildiği ve çalıştırabildiği varsayılır. Bu rehberde **Basis / sunucu yöneticisi**, sunucunun yönetim sorumluluğunu üstlenen kişi veya ekibi ifade eder; gerekli yetkilere sahipseniz bu kişi siz olabilirsiniz. Posta yönetimi için de aynı ayrım geçerlidir. [Yetkiler sizdeyse hazırlık adımları](SELF-MANAGED-SETUP.md).

## Aradığınız ayrıntıya geçin

- [Posta hesabının uygunluğu](#başlamadan-önce-posta-kutunuz-uygun-mu)
- [Sunucu kurulum komutları](#sunucu-kurulumu-komutlar-ve-kontroller)
- [SAP kurulum seçenekleri](#sap-kurulum-seçenekleri-ve-kontrolleri)
- [Profil alanları ve parola yönetimi](#profil-alanları-ve-sunucuda-parola-yönetimi)
- [Paket ve sistemler arası taşıma](#2b-canlıya-çıkmadan-önce-paket-ve-transport)
- [Saklama ve yeniden deneme](#saklama-ve-yeniden-deneme-ayrıntıları)
- [Mevcut sürümü güncelleme](#8-mevcut-kurulumu-güncelleyin)
- [Test durumu](../../VALIDATION.md)

## İlk kez karşılaşabileceğiniz terimler

| Terim | Bu projede anlamı |
|---|---|
| IMAP | Bir programın posta sunucusundaki iletileri ve klasörleri okumasını sağlayan bağlantı yöntemi. |
| Profil | Bir posta kutusunun sunucu, kullanıcı, klasör ve işleme ayarlarını SAP'de birlikte kaydettiğiniz tanım. |
| Handler | Her e-postayla ne yapılacağını belirleyen ABAP programı. İlk denemede hazır `ZCHE_IMAP_HANDLER_DEMO` örneği kullanılır. |
| Uygulama sunucusu | SAP'nin çalıştığı Windows veya Linux makine. Kurulum komutları kendi bilgisayarınızda değil, bu makinede çalıştırılır. |
| Arka plan işi / job | SAP'nin belirlediğiniz aralıklarla otomatik çalıştırdığı program. Örneğin posta kutusunu düzenli kontrol etmek için kullanılır. |

## Başlamadan önce: posta kutunuz uygun mu?

**Kendi e-posta adresinizi ve doğru parolanızı yazmanız bağlantı için tek başına yeterli olmayabilir.** Web postaya veya Outlook'a giriş yapabiliyor olmanız, bu projenin de aynı bilgilerle bağlanabileceği anlamına gelmez.

E-posta yöneticinizden şu noktaları doğrulamasını isteyin:

- **Hesabın IMAP erişimine izin verilmeli.** Kurum politikasına göre kapalı veya kısıtlı olabilir. Paylaşılan bir kutuda çalışacaksanız, bağlanan hesabın o kutuya erişim yetkisi de olmalıdır.
- **Giriş yöntemi bu projeyle uyumlu olmalı.** Bu sürüm kullanıcı adı/parola ile bağlanır; OAuth, yani tarayıcıya yönlendiren veya erişim belirteci kullanan giriş yöntemi desteklenmez. Yalnız OAuth kabul eden bir hesap bu sürümle kullanılamaz.
- **İki adımlı doğrulamada normal parola yeterli olmayabilir.** Bazı sağlayıcılar uygulama için ayrı parola sunar; bunun hesabınızda kullanılabilir ve kurumunuzca onaylı olup olmadığını e-posta ekibi belirlemelidir. Her hesapta böyle bir seçenek bulunmaz. Sağlayıcıya göre koşullar değişir; örneğin [Microsoft'un bağlantı koşullarına](https://support.microsoft.com/en-us/outlook/pop-imap-and-smtp-settings-for-outlook-com) ve [Google'ın uygulama parolası açıklamasına](https://support.google.com/mail/answer/185833?hl=tr) bakabilirsiniz.
- **SAP sunucusu posta sunucusuna ulaşabilmeli.** Kendi bilgisayarınızdan çalışan bağlantı, SAP sunucusundan güvenlik duvarı nedeniyle engellenebilir. Bunu Basis ve ağ ekibi kontrol eder.
- **İletileri taşıma izni ve sunucu desteği olmalı.** Başarılı iletiler başka bir posta klasörüne taşınır. E-posta ekibi sunucunun bunun için gereken `UID MOVE` özelliğini desteklediğini doğrulamalıdır.

İlk denemede **bu iş için ayrılmış bir deneme posta kutusu** kullanın. Normal çalışma iletileri okundu işaretleyebilir ve başka klasöre taşıyabilir.

### Hangi bilgileri almalısınız?

| Bilgi | Nereden alınır, nereye yazılır? |
|---|---|
| IMAP sunucu adı | E-posta ekibinden alınır; SAP profilindeki **Server / Sunucu** alanına yazılır. E-posta adresiniz veya SAP sunucunuzun adı değildir. |
| Port ve bağlantı güvenliği | E-posta ekibi birlikte verir. Örneğin `993 / IMAPS` yaygın bir çifttir; kendi hesabınız için doğrulanan değerleri kullanın. |
| Giriş kullanıcı adı | E-posta ekibinin verdiği değerdir. E-posta adresinizle aynı olmak zorunda değildir. |
| Parola | E-posta ekibinin onayladığı giriş yöntemine uygun paroladır. Parolayı talep kaydına veya ekran görüntüsüne koymayın. |
| Okunacak klasör | Varsayılan `INBOX`, Gelen Kutusu'nu okur. Başka bir klasörü okumak için o klasörün gerçek IMAP adını/yolunu girin; yalnız seçilen klasör okunur. Görünen Türkçe ad yerine IMAP adını doğrulayın. |
| İşlenmiş klasörü | Başarılı iletilerin taşınacağı posta klasörüdür; aşağıda açıklanıyor. |

Tablodaki sayılar ve adlar örnektir. Kurulumda kendi hesabınızın gerçek bilgilerini kullanın; bilinmeyen bir değeri tahmin etmek yerine ilgili ekipten alın.

### İşlenmiş klasörünü nasıl seçersiniz?

Başarıyla işlenen iletilerin taşınacağı klasörü SAP profilindeki **İşlenmiş klasörü** alanında siz belirlersiniz. Aynı posta kutusundaki mevcut bir klasörü kullanabilirsiniz. `SAP-Processed` yalnız başlangıç değeridir; bu adla yeni klasör oluşturmanız gerekmez.

Seçtiğiniz klasörün gerçek IMAP adını/yolunu girin. Klasör posta sunucusunda mevcut olmalıdır; bilgisayarınızdaki yerel Outlook arşivi veya disk klasörü kullanılamaz. Yeni bir klasör kullanmak isterseniz e-posta yöneticinizden hazırlamasını isteyebilirsiniz.

Klasör adları boşluk veya Türkçe karakter içeremez; İngilizce harfler, rakamlar ve `. _ / -` kullanılabilir.

## Kurulum: hangi sırayla ilerleyeceksiniz?

Aşağıdaki liste bir yol haritasıdır. Ekran adımları ve çalıştırılacak komutlar [adım adım kurulum rehberinde](WALKTHROUGH.md) yer alır.

1. **Proje dosyalarını indirin.** Deponun ana sayfasındaki **Code → Download ZIP** ile indirip arşivin tamamını açın. Git kurmanız gerekmez. Sunucu ve SAP dosyalarını aynı indirmeden kullanın.
2. **Deneme posta kutusunu hazırlayın veya yöneticisinden isteyin.** Yukarıdaki bağlantı bilgilerini alın ve işlenen iletiler için posta kutusundaki mevcut bir klasörü seçin.
3. **Sunucuyu hazırlayın veya yöneticisine hazırlatın.** İşlem SAP uygulama sunucusunda çalışır. PowerShell ve `curl` adlı yardımcı araçlar burada e-postayı alır; ayrı bir entegrasyon sunucusu gerekmez. Basis ağ erişimini ve korumalı çalışma klasörünü hazırlar, klasörün tam yolunu size verir. [Sunucu hazırlığı](WALKTHROUGH.md#2-sapnin-kurulu-olduğu-makineyi-hazırlayın).
4. **SAP programlarını kurun.** **SE38** içinde `ZCHE_IMAP_INSTALL` programını oluşturup projedeki aynı adlı kaynağı yükleyin, etkinleştirin ve çalıştırın. Bu program gerekli SAP programlarını ve tablolarını oluşturur. [SAP kurulum adımları](WALKTHROUGH.md#31-kurulum-programını-oluşturun). Ardından `ZCHE_IMAP` yetki nesnesini ve rolü oluşturun; bunlar olmadan programlar yetki mesajıyla durur. [Yetki adımı](WALKTHROUGH.md#33-yetki-nesnesini-ve-rolü-oluşturun).
5. **Bir posta profili kaydedin.** `ZCHE_IMAP_CONFIG` içinde bir ad seçip gerçek sunucu, kullanıcı ve klasör bilgilerinizi girin. İlk denemede handler olarak `ZCHE_IMAP_HANDLER_DEMO`, taşıma yöntemi olarak `MOVE` seçin. Parola kaynağı `S`, parolayı SAP ekranından girmeniz; `O`, Basis'in sunucuda kaydetmesi anlamına gelir. **F8** ayarları kaydeder ve bağlantıyı test eder; yalnız kaydın oluşması başarılı bağlantı demek değildir. [Profil tanımlama](WALKTHROUGH.md#34-posta-kutusu-profilini-tanımlayın).

Kalıcı kullanım için `ZCHE_IMAP` gibi bir müşteri paketi oluşturun veya projeye ayrılmış paketi kullanın. Installer şu anda ürettiği nesneleri `$TMP` adlı yerel deneme alanına koyar; installer'ı pakete kaydetmek tek başına bunu değiştirmez. Test ve canlı sisteme taşıma için [paket ve transport adımlarını](TECHNICAL-REFERENCE.md#2b-canlıya-çıkmadan-önce-paket-ve-transport) Basis ve geliştiriciyle planlayın.

## İlk denemede ne yapacaksınız?

1. Deneme posta kutusuna küçük bir PDF veya metin eki bulunan e-posta gönderin.
2. SAP'de **SE38** üzerinden `ZCHE_IMAP_INBOUND` programını açın. Kaydettiğiniz profil adını girin. **List only (no downloads/changes)** seçeneğini işaretleyip çalıştırın. Bu adım uygun iletilerin numaralarını (`UID`) listeler; içerik ve ekleri göstermez, e-postaları taşımaz.
3. Listeleme başarılıysa aynı deneme profilini `ZCHE_IMAP_HANDLER_DEMO` ile, bu kez **List only seçeneği kapalı** çalıştırın. Artık ileti ve ekleri gerçekten alınır; örnek programın sonucu kaydedilir ve başarılı ileti işlenmiş klasörüne taşınır.
4. `ZCHE_IMAP_MONITOR` programında sonucu ve ekleri inceleyin. Başarıyla tamamlanan ileti `S` durumunda görünür; posta kutusunda da seçtiğiniz işlenmiş klasöründe bulunmalıdır.
5. Deneme tamamlandıktan sonra kendi iş kurallarınızı ekleyin. Düzenli çalışmayı Basis, kurulum yapılan **aynı SAP uygulama sunucusunda** bir arka plan işi olarak planlasın.

Hazır örnekte SAP'de bir fatura veya sipariş oluşmasını beklemeyin. Bu denemenin amacı posta bağlantısını, dosyaların alınmasını ve sonucu izlemeyi doğrulamaktır.

Monitör, PDF ve yaygın görselleri bilgisayarınızdaki uygun uygulamayla açabilir. Excel ve orijinal e-posta dosyası (`.eml`) dahil diğer türler indirilerek incelenir. Hatalı iletiler, yetkili kullanıcı tarafından yeniden işlenmek üzere seçilebilir.

## Bağlantı kurulmazsa nereden başlamalısınız?

| Gördüğünüz durum | Kimin kontrol etmesi gerekir? |
|---|---|
| E-posta adresi ve parola doğru, ama giriş reddediliyor | E-posta ekibi: IMAP izni, gerçek giriş adı, o posta kutusuna erişim ve desteklenen giriş yöntemi. |
| Sunucu bulunamıyor veya bağlantı zaman aşımına uğruyor | Basis/ağ ekibi: gerçek IMAP sunucu adı, port ve SAP sunucusunun ağ erişimi. |
| Sertifika hatası var | Basis/e-posta ekibi: sunucu adı ve güvenilen sertifikalar. Sertifika doğrulamasını kapatarak geçmeyin. |
| Klasör bulunamıyor veya ileti taşınamıyor | E-posta ekibi: klasör aynı posta kutusunda mevcut mu, adı/yolu doğru mu, taşıma izni ve `UID MOVE` desteği var mı? |
| SAP'de yetki hatası var | Basis/yetkilendirme ekibi: ilgili SAP kullanıcısının program, dosya ve komut yetkileri. |
| Listeleme başarılı ama içerik görünmüyor | **List only** yalnız ileti numaralarını gösterir. İçerik için hazır örnekle normal denemeyi yapın. |

Destek isterken hangi adımda kaldığınızı ve hata metnini paylaşın; parola paylaşmayın. Ayrıntılı kontroller [kurulum rehberinde](WALKTHROUGH.md) bulunur.

## Mevcut bir posta kutusunu neden okuyalım?

Bu proje, SAP'nin belirli aralıklarla mevcut bir posta kutusuna bağlanıp iletileri almasını sağlar. SAPconnect/SMTP ise e-postaların SAP'ye teslim edildiği başka bir akıştır. Seçim kurumunuzun ihtiyacına bağlıdır; [SAP'nin gelen ileti açıklamasına](https://help.sap.com/saphelp_snc700_ehp01/helpdata/en/2b/d9260b4b8a11d1894c0000e8323c4f/content.htm?no_cache=true) bakabilirsiniz.

Kaynaklar klasik ABAP sistemleri için **7.00 and later** uyumluluğunu hedefler. Bu bir uyumluluk sertifikası değildir; hedef SAP sürümünüzde derleme ve çalışma testi gerekir.

## Yetkiler ve işletim sınırları

Basis, yetkileri ilgili kullanıcılara ve tablo yetki gruplarına göre tanımlar. Uygulama tablo erişimini `VIEW_AUTHORITY_CHECK` ile denetler; dosya ve komut yetkileri ayrıca kontrol edilir. Üç tablo `ZCHI` tablo yetki grubundadır: aşağıdaki tabloya göre `ZCHI` için `S_TABU_DIS` yetkisini `03` (görüntüleme) veya `02` (değiştirme) aktivitesiyle verin. Önce `ZCHE_IMAP` yetki nesnesini oluşturun ([kurulum rehberi adım 3.3](WALKTHROUGH.md#33-yetki-nesnesini-ve-rolü-oluşturun)).

| Rol | Gerekli erişim |
|---|---|
| Job kullanıcısı | Profil adı için `ZCHE_IMAP` aktivite `16`; `ZCHE_IMAP_PROFILE` görüntüleme; `ZCHE_IMAP_LOG` değiştirme; `S_LOG_COM` üzerinden `ZCHE_IMAP_LIST`, `ZCHE_IMAP_FETCH`, `ZCHE_IMAP_DONE`; `S_DATASET` üzerinden gelen mail dosyalarını okuma; handler'ın ihtiyaç duyduğu yetkiler. |
| Profil yöneticisi | Profil adı için `ZCHE_IMAP` aktivite `03` ve `02`; `ZCHE_IMAP_PROFILE` görüntüleme/değiştirme; `ZCHE_IMAP_TEST` çalıştırma; `ZCHE_IMAP_CONFIG` için profil ve kimlik bilgisi dosyalarına `S_DATASET` yazma erişimi. |
| İzleme kullanıcısı | Profil adı için `ZCHE_IMAP` aktivite `03` (yeniden deneme için ayrıca `02`); `ZCHE_IMAP_LOG` görüntüleme; `ZCHE_IMAP_MONITOR` için gelen/arşiv dosyalarını okuma. Yeniden işleme ayrıca `ZCHE_IMAP_LOG` değiştirme yetkisi gerektirir. |
| Kurulumu yapan | Proje nesneleri için geliştirme yetkileri ve SM69 komutlarını yönetip test etme yetkileri. Kaldırmada ek client kontrolleri vardır. |

- Proje şifreleri **kendi SAP tablolarına yazmaz**. Kimlik bilgileri işletim sistemi izinleriyle korunan düz metin dosyalardır; SAP servis hesabı ve ayrıcalıklı yöneticiler erişebilir. Uygulama kaydedilmiş şifreyi göstermez.
- SAP'den şifre girişinde normal varyant kaydetme ve yazdırma kapatılır. Gerekli koruma API'si yoksa yeni şifre girişi kapanır; Basis'in yönettiği `O` kaynağını kullanın.
- İzinli mail sunucuları, TLS istisnaları, boyut sınırları ve zaman aşımı `bin/policy.psd1` içinde Basis tarafından belirlenir. SAP servis hesabının `bin` erişimi okuma/çalıştırmayla sınırlıdır.
- Profil dosyaları sistem, client ve profil adına göre ayrılır; revizyon olarak yayımlanır. Mail geçmişi olan profil başka posta kutusuna yönlendirilemez veya silinemez; devre dışı bırakıp yeni profil oluşturun.
- Kurulum tek bir uygulama sunucusuna bağlıdır. Yerel dosyalar uygulama sunucuları arasında otomatik paylaşılmaz.
- Saklama süresi dolan uygun, tamamlanmış **yerel arşivler** normal çalışma sırasında temizlenir. Salt okunur test modu bu temizliği yapmaz. Bu işlem `ZCHE_IMAP_LOG` kayıtlarını veya uzaktaki işlenenler klasörünü silmez.

## Bilinen sınırlar

Kaynak ve hedef klasör aynı veya yalnız büyük/küçük harfle farklı olamaz. Bu kontrol SAP profilinde ve scriptte uygulanır; sunucunuz farklı adları aynı klasöre bağlayabiliyorsa iki ayrı klasör seçtiğinizi ayrıca doğrulayın.

HTML dönüşümü en fazla 2.097.152 UTF-16 karakteri, 20.000 etiket ve etiket başına 16.384 karakter kabul eder. Dönüşümün toplam iş bütçesi 2 saniye, her regex eşleşmesinin zaman aşımı 250 ms'dir. Sınır aşımı veya kapanmayan script/style/head bölümü kontrollü `PARSE` hatası verir. Bu sınırlar ağ zaman aşımından ayrıdır.

- Klasör adlarında ASCII harf, rakam ve `. _ / -` kullanılır; boşluk olmaz. Eski mail sunucularıyla uyum için ASCII şifre tercih edin.
- İlk `text/plain` bölüm metin olarak alınır; yoksa HTML düz metne çevrilir. S/MIME çözme ve `winmail.dat` açma desteği yoktur.
- Bozuk veya desteklenmeyen MIME, aşırı iç içe yapı/parça sayısı ve SAP dosya biçimine sığmayan metadata, tamamlanmış gibi gösterilmek yerine reddedilir.
- Monitör sorgu başına en fazla 1.000 satır gösterir. Gerektiğinde tarih, profil veya durum seçimini daraltın.

## Validation / Doğrulama

Güncel durum için [doğrulama kaydına](../../VALIDATION.md) bakın.

## Mevcut kurulumu güncelleme

Dosyaları değiştirmeden önce [güncelleme adımlarını](TECHNICAL-REFERENCE.md#8-mevcut-kurulumu-güncelleyin) okuyun. 0.9.0; betik protokolünü, profil adlandırmasını ve revizyonlu dosya yapısını değiştirir.

SAP kaynaklarıyla **iki sunucu modülünü birlikte** güncelleyin. Profilleri yeniden kaydedin; `S` şifrelerini yeniden girin. Basis'in yönettiği kimlik bilgileri tam sistem/client/profil anahtarını kullanır. Eski mail dizinleri korunur, **otomatik taşınmaz**. Bekleyen `H` kayıtları ve dosyaları için kontrollü geçiş planı gerekir.

## Geliştirme testleri ve build

Node.js 22+ ve npm geliştirme araçlarıdır; SAP sunucusunda gerekli değildir. Komutları deponun ana klasöründen çalıştırın. PowerShell 7 ile kaynak ve ayrıştırıcı kontrolleri:

```powershell
npm ci --ignore-scripts
pwsh -NoProfile -File test/check-source.ps1
pwsh -NoProfile -File test/run-tests.ps1 -Shell pwsh
```

IMAP paketi, SMTP/IMAPS ve REST API'si açık, geçici bir GreenMail örneği gerektirir. [CONTRIBUTING.md](../../CONTRIBUTING.md) elle başlatma ve test komutlarını içerir. Her koşu ayrı test kullanıcısı oluşturur; bu testleri iş posta kutusuna yönlendirmeyin.

ABAP kaynaklarını değiştirdikten sonra installer'ı yeniden üretin:

```powershell
pwsh -NoProfile -File installer/build.ps1
```

## Sunucu kurulumu: komutlar ve kontroller

Kurulum tek SAP uygulama sunucusuna bağlıdır; ayarlar, işleme ve izleme aynı sunucuda çalışmalıdır. Basis sunucuya özel SAP bağlantısını sağlamalıdır. Proje programları ve SM69 komutları mandantlar arasında ortaktır; değişiklikleri diğer sahiplerle koordine edin.

**Komutları nasıl kullanacaksınız?** İşletim sisteminize uygun bloğun tamamını, açılış ve kapanış süslü parantezleriyle birlikte kopyalayın. Sorulduğunda yalnız kendi değerinizi yazıp Enter basın; yanıtın etrafına tırnak veya köşeli parantez eklemeyin. Sunucu/port posta ekibinden, SAP hesabı ve klasör Basis'ten alınır. Her blok bilgileri tekrar sorar; önceki terminal değişkenlerine bağlı değildir. `ZCHE_IMAP_INSTALL`, `ZCHE_IMAP_CONFIG`, `ZCHE_IMAP_INBOUND`, `ZCHE_IMAP_MONITOR` ve `ZCHE_IMAP_HANDLER_DEMO` gerçek program adlarıdır ve değiştirilmez.

**Komutları SAP uygulama sunucusunda çalıştırın; SAP GUI kullandığınız bilgisayar farklı olabilir.** Güncel deponun `server` ve `script` klasörlerini birlikte kullanın. Kurulum hem `imap.ps1` hem `mime.ps1` dosyasını yerleştirir.

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

Windows PowerShell 5.1 ve `curl.exe --version` çıktısında `imaps` bulunan **curl 8.0.0 veya üzeri** gerekir. Eski Windows sürümlerindeki `curl.exe` daha eskidir; güncel bir curl kurup yolunu `-CurlPath` ile verin. curl 8'den eskiyse kurulum anlaşılır bir mesajla durur. Windows PowerShell'de `curl.exe` yazın; `curl` başka bir komutu ifade edebilir.

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
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ImapRoot 'bin\imap.ps1') test
}
```

Başarılı çıktı `PROTOCOL 2`, `VERSION 0.9.1` ve seçilen kökü belirtir; `OK` ile biter. Yönetici hesabıyla bu test yararlıdır; ileride SAP kurulum programının testi gerçek SAP çalışma hesabıyla da geçmelidir.

### Linux

PowerShell (`pwsh`) ve IMAPS destekli **curl 8.0.0 veya üzeri** kurun. Birçok SAP Linux sürümünde `/usr/bin` altındaki curl 7.x'tir; daha yeni bir curl kurup kuruluma `--curl-path /tam/yol/curl` verin, kurulum bunu `bin/policy.psd1` dosyasına yazar. curl 8'den eskiyse kurulum anlaşılır bir mesajla durur. Oluşturulan SM69 komutu `/usr/bin/pwsh` bekler. SAP'nin gerçek çalışma kullanıcısını doğrulayın; `a4hadm` örnektir.

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

Varsayılan kök `/usr/sap/sapimap`. Mevcut üst klasörlerden biri root'a ait değilse veya root dışındaki kullanıcı/gruplar tarafından yazılabiliyorsa kurulum yolu reddeder. Basis, uygun olduğunda `--root /opt/sapimap` gibi üst klasörleri korumalı, onaylı bir yer seçip her adımda aynı yolu kullanmalıdır. Kontrolü geçmek için mevcut SAP klasörlerinin sahipliğini değiştirmeyin.

Seçilen kökü SAP'nin çalışma kullanıcısıyla test edin. İki soruya önceki kurulumdaki Linux kullanıcı adı ve tam klasör yoluyla yanıt verin:

```bash
{
  read -r -p 'Basis tarafindan dogrulanan Linux SAP kullanicisi: ' sap_os_user
  read -r -p 'Basis tarafindan onaylanan tam calisma klasoru yolu: ' imap_root
  sudo -u "${sap_os_user:?SAP OS user is required}" /usr/bin/pwsh \
    -NoProfile -File "${imap_root:?Working folder is required}/bin/imap.ps1" test
}
```

Çıktı protokol `2`, sürüm `0.9.1` ve seçilen kökü belirtip `OK` ile bitmelidir. Bu yerel ön koşulları kontrol eder; SAP kurulumu ve posta bağlantısı sonraki adımlardadır.

### Sertifika ve danışmana teslim

TLS sertifika doğrulamasını açık tutun. Basis kullanılan curl sürümünün güven deposunu veya `bin/policy.psd1` içindeki `CaCert` üzerinden onaylı CA dosyasını hazırlamalıdır. Windows Schannel ve diğer curl TLS altyapılarının güven mekanizması farklı olabilir.

Basis, danışmana kök klasörü, seçilen SAP sunucusunu ve öz testin başarılı olduğunu iletir. Bu teslim bilgisinde parola bulunmaz.

## SAP kurulum seçenekleri ve kontrolleri

**SE38** içinde `ZCHE_IMAP_INSTALL` girip **Execute / Çalıştır (F8)** seçin.


Geliştirme sistemindeki ilk kurulum için:

| Seçenek | Ne seçilir / ne yapar? |
|---|---|
| DDIC objects | Seçili. Projenin tablolarını, yapılarını, veri elemanlarını ve domain'lerini oluşturur. |
| Programs | Seçili. Ayar, işleme, izleme, include ve örnek handler programlarını oluşturur. |
| SM69 commands | Seçili. SAP'nin scripti başlatacağı komutları oluşturur. |
| Server check | Seçili ve zorunlu. SAP'nin beklenen script sürümünü ve kökü çalıştırabildiğini kontrol eder. |
| Overwrite programs | Yedekleme/inceleme sonrası planlı güncellemede kullanın; yerel değişiklikleri değiştirebilir. |
| Server folder | Basis'in verdiği kök; örneğin `C:\sapimap\` veya `/usr/sap/sapimap/`. |
| Code page / kod sayfası | Geliştirici başka seçim önermedikçe otomatik bırakın. Eski sistemlerin dosya okuma biçimini etkiler. |
| Uninstall | Seçmeyin. Mandantlar arası ortak nesneleri kaldırır; profil sıfırlama değildir. |

Çalıştırın ve sonuç listesinin tamamını okuyun. Seçili adımlar ve son sunucu kontrolü başarılıysa devam edin. Hata varsa çıktıyı Basis/geliştirme ekibine verin.

Yalnız SM69/sunucu adımları seçilse de geliştirme yetkileri kontrol edilir. Kurulum uygun durumlarda yedeklenen program/metin ve SM69 kayıtlarını geri alır; tam veritabanı işlemi veya sistem yedeği değildir. Başarısız güncellemede DDIC değişikliklerini ve yeni nesneleri gözden geçirin.

## 2b. Canlıya çıkmadan önce: paket ve transport

`$TMP` deneme için uygundur; nesneleri normal paket transport sürecine girmez. Kalıcı kullanım için geliştirme ve Basis ekibiyle kurumunuzun müşteri paketini ve taşıma sürecini kullanın.

1. **Geliştirme sisteminde**, **SE21** veya **SE80** üzerinden `ZCHE_IMAP` gibi bir paket oluşturun. Transport katmanını Basis belirlesin.
2. Burada kurup test edin. Mevcut installer ürettiği nesneleri `$TMP` içine koyar.
3. Proje nesnelerini listeleyin: installer, program/include'lar, tablo/yapılar, veri elemanları, domain'ler ve kendi handler'ınız. `ZCHE_IMAP*` ile eşleşen ilgisiz nesneleri körlemesine seçmeyin.
4. **SE03 → Change Object Directory Entries** veya uygun **SE80 → Reassign** işlemiyle projeye ait nesneleri pakete atayın ve transport talebinde toplayın. Talep yalnız installer'ı değil, tanımları ve bağımlılıkları da içermelidir.
5. **Test sistemine** aktarın, o sistemin sunucusunu ve yerel ayarlarını hazırlayın, ilk kullanım kontrollerini tekrarlayın. Ardından onaylı canlıya taşıma sürecini izleyin.

**Bu paket/transport yolu projeyle uçtan uca henüz denenmedi.** Güvenmeden önce kendi sistem zincirinizde doğrulayın.

ABAP nesnelerinin transport'u PowerShell'i, işletim sistemi dosyalarını, klasör izinlerini veya parolaları kurmaz. Basis her hedefte SM69 yollarını/yetkilerini incelemeli; profil ve parolaları ilgili sistem/mandant için hazırlamalıdır.

Yalnız sunucu modunun değişikliğe kapalı canlıda çalışacağını varsaymayın: mevcut installer geliştirme yetkisini ve kaynak tutarlılığını yine kontrol eder. Hedef sistem kurulumunu önceden kararlaştırıp test edin; rehber canlı değişiklik kontrollerinin gevşetilmesini gerektirmez.

SAP kaynakları: [Nesne dizini ve paket değiştirme](https://help.sap.com/docs/SAP_NETWEAVER_700/109ce05a6c531014b4e8fe6b0570a984/5738e06c4eb711d182bf0000e829fbfe.html), [harici komutların bakımı](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_752/b17bd20044a44edb9aa7830ee52ffac3/c43a607b505211d189550000e829fbbd.html?locale=en-US&state=PRODUCTION&version=7.52.latest).

## Profil alanları ve sunucuda parola yönetimi

| Alan | İlk deneme örneği | Açıklama |
|---|---|---|
| Profil / aktif | `INVOICE` / seçili | Ayarların adı; aktif profiller işlenebilir. |
| Sunucu / port | Kendi IMAP sunucunuz / portunuz | İkisini de posta ekibinden alın; örnek adresi kopyalamayın. |
| Güvenlik / sertifika doğrula | Posta ekibinin verdiği tür / seçili | `IMAPS` veya `STARTTLS` seçimi portla uyumlu olmalıdır. Doğrulamayı açık tutun. |
| Kullanıcı | Kendi posta giriş adınız | Posta ekibinin verdiği giriş adını yazın; örnek e-posta adresini kullanmayın. |
| Parola kaynağı | `S` veya `O` | `S`: SAP'de girilir. `O`: Basis sunucuda saklar. |
| Okunacak klasör | Varsayılan `INBOX` | Gelen Kutusu okunur. Başka bir klasörü okumak istiyorsanız aynı posta kutusundaki o klasörün gerçek IMAP adını/yolunu girin; yalnız seçilen klasör okunur. |
| İşlenmiş klasörü | Seçtiğiniz posta klasörünün adı | Mevcut bir klasörü kullanabilirsiniz. Başlangıçtaki `SAP-Processed` değerini seçtiğiniz klasörün gerçek IMAP adı/yoluyla değiştirin. |
| Taşıma yöntemi (Move method) | `MOVE` | UID MOVE desteği gerekir. |
| Handler programı | `ZCHE_IMAP_HANDLER_DEMO` | Hazır örnek; iş belgesi oluşturmaz. |
| Çalıştırma başına ileti (Mails per run) | `50` | Bir çalıştırmadaki örnek üst sınır. |
| Azami ileti boyutu, MB (Max mail size) | `20` | İleti başına örnek MiB sınırı; sunucu politikası daha düşük olabilir. |
| Zaman aşımı | `120` | Örnek ağ zaman aşımı, saniye. |
| Saklama süresi | `30` | Tamamlanmış yerel arşivler için gün; SAP logunu veya uzaktaki postayı silmez. |

### Parolayı SAP'de girin veya Basis'e bırakın

**`S` kaynağında** parolayı SAP'de girersiniz. SAP tablosuna değil, işletim sistemi izinleriyle korunan düz metin parola dosyasına yazılır. Bu giriş için normal varyant kaydetme ve yazdırma kapatılır. Gerekli SAP koruma API'si yoksa yeni parola girişi kapalıdır; `O` kullanın. Yeni parolayı arka plan varyantıyla girmeyin.

**`O` kaynağında** Basis'e tam **`SID_MANDANT_PROFIL`** anahtarını verin. Sistem `A4H`, mandant `001`, profil `INVOICE` ise anahtar **`A4H_001_INVOICE`** olur. SID ve mandantı **Sistem → Durum / System → Status** altında görebilirsiniz.

Basis sunucuda depo klasöründen işletim sistemine uygun bloğu çalıştırır: Windows'ta yönetici olarak açılmış PowerShell oturumunda, Linux'ta root olarak. Önce gerçek tam profil anahtarı, SAP işletim sistemi hesabı ve kurulumdaki tam klasör yolu sorulur. `A4H_001_INVOICE` değerini aynen kopyalamayın; kendi SID/mandant/profilinizden oluşturun. Parolayı kurulum aracı daha sonra ayrıca sorar; komuta yazmayın.

```powershell
& {
  $ProfileKey = (Read-Host 'Bu sistem ve mandant icin tam SID_CLIENT_PROFILE anahtari').Trim()
  $SapOsAccount = (Read-Host 'Basis tarafindan dogrulanan Windows SAP servis hesabi').Trim()
  $ImapRoot = (Read-Host 'Basis tarafindan onaylanan tam calisma klasoru yolu').Trim()
  if (@($ProfileKey, $SapOsAccount, $ImapRoot) -contains '') {
    throw 'Bilgiler bos birakilamaz. Ilgili ekipten alip tekrar calistirin.'
  }
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File server\setup-server.ps1 `
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

## Saklama ve yeniden deneme ayrıntıları

Log kayıtları dosyalardan daha uzun süre kalabilir. Saklama süresi tamamlanmış yerel arşivleri temizler; `ZCHE_IMAP_LOG` veya uzak işlenmiş klasörünü temizlemez. Bunların saklama süresini veri sahipleriyle ayrıca belirleyin.

### Hata ve yeniden deneme alıştırması

1. Konusunda `TEST-ERROR` bulunan ileti gönderip demo handler ile normal çalıştırın.
2. Bilerek oluşan hatayı monitörde inceleyin.
3. İlgili programdaki nedeni düzeltin veya bu iletiyi kabul eden onaylı deneme handler'ını seçin. Yeniden deneme işareti demonun kuralını değiştirmez.
4. Yetkili monitör kullanıcısı yeniden deneme işlemini seçer. Kayıt `R` olur; normal işleme çalıştırın.

Yeniden deneme log değiştirme yetkisi gerektirir. İşleme ekranındaki **retry errors** seçeneği de `E` iletilerini bilerek tekrar denemek içindir, ancak yalnızca `MAX_ATTEMPTS` (varsayılan 3) başarısız denemenin altında çalışır; sonrasında monitördeki yeniden denemeyi kullanın. `H`, taşıma kurtarmasıyla ele alınır. Tekrar çalıştırmak için log satırlarını veya sunucu dosyalarını silmeyin.

## 7. Teknik başvuru: SAP hangi komutları çalıştırır?

Bu isteğe bağlı bölüm Basis/geliştirme ekibinin teşhisi içindir; canlı postaya elle komut çalıştırma talimatı değildir.

| SM69 adı | Script işlemi ve sıralı parametreleri |
|---|---|
| `ZCHE_IMAP_TEST` | `test`; profil testi için isteğe bağlı `KEY REVISION`. |
| `ZCHE_IMAP_LIST` | `list KEY REVISION`; normal SAP çalışması tamamlanmış yerel arşiv temizliği için `PURGE` ekler. Diğer durumda listeleme salt okunurdur. |
| `ZCHE_IMAP_FETCH` | `fetch KEY UID UIDVALIDITY REVISION` |
| `ZCHE_IMAP_DONE` | `done KEY UID UIDVALIDITY REVISION` |

`KEY`, SID/mandant/profil içerir. Revizyonları SAP yönetir; elle değiştirmeyin. MIME testlerinin ayrı yerel giriş noktası vardır; üretim SM69 komutu değildir.

## 8. Mevcut kurulumu güncelleyin

0.9.0 script protokolünü, profil dosya adlarını ve revizyon saklamasını değiştirir. ZIMAP_ → ZCHE_IMAP_ geçişini iş açmadan önce inceleyin.

1. Zamanlanmış işlemeyi durdurun; ortak kurulumu kullanan mandantlarla koordine edin. SAP nesneleri/ayarları/logları, politika, parolalar ve posta klasörlerini onaylı yöntemle yedekleyin.
2. Bekleyen `H` kayıtlarını Basis/geliştirme ekibiyle inceleyin. Eski, sistem/mandant ayrımı olmayan klasörler korunur; **otomatik taşınmaz**. Devam etmeden kayıt/dosya eşleştirmesini planlayın; silerek veya tamamlanmış iş mantığını tekrar çalıştırarak geçmeyin.
3. Aynı sürümden **hem** `imap.ps1` **hem** `mime.ps1` yerleştirin; politikayı koruyup gözden geçirin. SAP nesne ve komutlarını test edilmiş paket/transport süreciyle güncelleyin. SAP ve script protokol `2` kullanmalıdır.
4. Sunucuyu, rolleri ve profilleri kontrol edin. Profilleri tekrar kaydedip `S` parolalarını yeniden girin. `O` parolalarını tam `SID_MANDANT_PROFIL` anahtarıyla oluşturun.
5. Sunucu, bağlantı, salt okunur liste, normal demo, hata/tekrar deneme ve bekleyen taşıma kurtarma kontrollerini yapın. Job kullanıcısı ve iş handler'ını doğrulayıp job'ları yeniden açın.

Posta geçmişi olan profil başka kutuya yönlendirilemez veya silinemez. Posta kimliği değişecekse profili pasifleştirip yenisini oluşturun.


## Arka plan işi planlama (Basis)

Basis'ten **SM36** ile `ZCHE_IMAP_INBOUND` job'ı oluşturmasını isteyin. Varyantta doğru profil seçili, **yalnız listeleme kapalı** olmalıdır. Sıklığı operasyon ekibiyle belirleyin.

Kurulumun uygulama sunucusunu kullanın. Gerçek, kısıtlı job kullanıcısıyla test edin; geliştirici hesabında önden çalışması yeterli değildir. Basis harici komut, dosya, tablo ve handler'a özel yetkileri kontrol eder. [Rol özeti](TECHNICAL-REFERENCE.md#yetkiler-ve-işletim-sınırları) teknik başvuru rehberindedir.

Gerçek iş postalarından önce iş kurallarınızı uygulayıp doğrulayın. Arayüz [geliştirici rehberinde](TECHNICAL-GUIDE.md) anlatılır. Hazır demoyu gösterim amacıyla kullanın.

## Eski profil ve parola dosyalarının bakımı

Profil ve parola revizyonları çalışan bir işlemin kullandığı dosyayı erken silmemek için otomatik temizlenmez. Profil silme işlemi yalnız etkin ayar/parola dosyalarını kaldırmayı dener; eski revizyonlar için yöneticiye bakım uyarısı verir.

1. İlgili profilin zamanlanmış işlerini durdurun ve bu profille çalışan ön plan işlemlerinin tamamlanmasını bekleyin. Ortak sunucuyu kullanan sistem/mandantlarla koordine edin.
2. Doğru sistem/mandanttaki `ZCHE_IMAP_PROFILE` kaydından `REVISION`, `CREDSRC` ve `CREDREV` değerlerini doğrulayın. Parolayı görüntülemeyin veya günlüğe yazmayın.
3. Etkin `conf/KEY_REVISION.conf` dosyasını ve onun referans verdiği parolayı koruyun: `S` için `secret/KEY_CREDREV.cred`, `O` için `secret/KEY.cred`. Başarısız kaydetmeden kalan bir dosyanın etkin olduğunu varsaymayın.
4. Artık kullanılmadığı ve geri dönüş planında gerekmediği doğrulanan eski revizyon dosyalarını kurumunuzun saklama politikasına göre, yalnız tam dosya adlarını seçerek kaldırın. `conf` veya `secret` klasörünün tamamını silmeyin. SAP geçmişi olan profilin adını yeniden kullanmayın.
5. İşleri yeniden açmadan bağlantı ve yalnız listeleme testini tekrarlayın. Sonlandırılmış işlemlerden kalan eski `tmp` dosyaları için de sahiplik ve kullanım kontrolüyle ayrı bakım yapın; bekleyen `in`/`done` verisini silmeyin.

Aynı klasörü kaynak ve hedef olarak kullanan eski bir profil varsa otomatik işlemeyi durdurun. Mevcut iş belgelerini ve bekleyen kayıtları incelemeden yeni profille tüm iletileri yeniden oynatmayın; daha önce oluşmuş mükerrer kayıtlar kod güncellemesiyle otomatik düzelmez.

## Release candidate security changes

[Current profile authorization, handler allowlist, credentials and retry/cache policy](../../SECURITY.md). Installer DDIC interface probing is retained where kernel APIs use different structure types; old runtime view/GUI probes were removed.
