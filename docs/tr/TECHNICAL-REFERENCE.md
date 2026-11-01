# Teknik başvuru: bağlantı, işletim ve testler

> [English](../TECHNICAL-REFERENCE.md) | **Türkçe** · [Projeyi tanıyın](../../README.tr.md) · [Kurulum](WALKTHROUGH.md) · [Kod örnekleri](TECHNICAL-GUIDE.md)

Bu dosya, kurulumu hazırlayan Basis ve e-posta ekipleri ile ayrıntıları incelemek isteyen geliştiriciler içindir. **1.1.0 kaynaklarını ve betik protokolü 2'yi** anlatır. Sırayla kurulum yapmak için [adım adım rehberi](WALKTHROUGH.md), kendi iş mantığınızı eklemek için [geliştirici rehberini](TECHNICAL-GUIDE.md) kullanın.

## İlk kez karşılaşabileceğiniz terimler

| Terim | Bu projede anlamı |
|---|---|
| IMAP | Bir programın posta sunucusundaki iletileri ve klasörleri okumasını sağlayan bağlantı yöntemi. |
| Profil | Bir posta kutusunun sunucu, kullanıcı, klasör ve işleme ayarlarını SAP'de birlikte kaydettiğiniz tanım. |
| Handler | Her e-postayla ne yapılacağını belirleyen ABAP programı. İlk denemede hazır `ZIMAP_HANDLER_DEMO` örneği kullanılır. |
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

### `SAP-Processed` klasörü nerede oluşturulur?

**SAP'nin okuyacağı e-posta hesabının içinde**, Gelen Kutusu gibi bir **posta klasörü** olarak oluşturulur. SAP'de veya sunucunun diskinde oluşturulacak bir klasör değildir.

Örneğin deneme posta kutunuzda şu iki klasör bulunabilir:

```text
INBOX          → Okunacak iletiler (Gelen Kutusu)
SAP-Processed  → Başarıyla işlenen iletilerin taşınacağı klasör
```

E-posta yöneticinizden oluşturmasını isteyebilir veya yetkiniz varsa web posta ekranından oluşturabilirsiniz. Outlook'ta oluşturuyorsanız posta sunucusuyla eşitlenen hesabın altında olmalıdır; bilgisayarınızdaki yerel arşiv klasörü kullanılamaz.

`SAP-Processed` önerilen addır. Başka bir ad seçerseniz SAP profilindeki **İşlenmiş klasörü** alanına o klasörün gerçek IMAP adını/yolunu yazın. Klasörü önceden oluşturun. Bu projede klasör adları boşluk ve Türkçe karakter içeremez; İngilizce harfler, rakamlar ve `. _ / -` kullanılabilir.

## Kurulum: hangi sırayla ilerleyeceksiniz?

Aşağıdaki liste bir yol haritasıdır. Ekran adımları ve çalıştırılacak komutlar [adım adım kurulum rehberinde](WALKTHROUGH.md) yer alır.

1. **Proje dosyalarını indirin.** Deponun ana sayfasındaki **Code → Download ZIP** ile indirip arşivin tamamını açın. Git kurmanız gerekmez. Sunucu ve SAP dosyalarını aynı indirmeden kullanın.
2. **Deneme posta kutusunu hazırlatın.** Yukarıdaki bağlantı bilgilerini alın ve işlenmiş klasörünü oluşturun.
3. **Basis sunucuyu hazırlasın.** İşlem SAP uygulama sunucusunda çalışır. PowerShell ve `curl` adlı yardımcı araçlar burada e-postayı alır; ayrı bir entegrasyon sunucusu gerekmez. Basis ağ erişimini ve korumalı çalışma klasörünü hazırlar, klasörün tam yolunu size verir. [Sunucu hazırlığı](WALKTHROUGH.md#0-sunucuyu-hazırlayın-basis).
4. **SAP programlarını kurun.** SAP geliştirme yetkisi olan kişi, **SE38** program editöründe `ZIMAP_INSTALL` programını oluşturup projedeki aynı adlı kaynağı yükler ve çalıştırır. Bu program gerekli SAP programlarını ve tablolarını oluşturur. [SAP kurulum adımları](WALKTHROUGH.md#1-kurulum-programını-oluşturun).
5. **Bir posta profili kaydedin.** `ZIMAP_CONFIG` içinde bir ad seçip gerçek sunucu, kullanıcı ve klasör bilgilerinizi girin. İlk denemede handler olarak `ZIMAP_HANDLER_DEMO`, taşıma yöntemi olarak `MOVE` seçin. Parola kaynağı `S`, parolayı SAP ekranından girmeniz; `O`, Basis'in sunucuda kaydetmesi anlamına gelir. **F8** ayarları kaydeder ve bağlantıyı test eder; yalnız kaydın oluşması başarılı bağlantı demek değildir. [Profil tanımlama](WALKTHROUGH.md#3-posta-kutusu-profilini-tanımlayın).

Kalıcı kullanım için geliştirme ekibiniz `ZIMAP` gibi bir **paket**, yani SAP geliştirme nesnelerini birlikte yöneteceğiniz bir grup oluşturmalıdır. Installer şu anda ürettiği nesneleri `$TMP` adlı yerel deneme alanına koyar; installer'ı pakete kaydetmek tek başına bunu değiştirmez. Test ve canlı sisteme taşıma için [paket ve transport adımlarını](WALKTHROUGH.md#2b-canlıya-çıkmadan-önce-paket-ve-transport) Basis ve geliştiriciyle planlayın.

## İlk denemede ne yapacaksınız?

1. Deneme posta kutusuna küçük bir PDF veya metin eki bulunan e-posta gönderin.
2. SAP'de **SE38** üzerinden `ZIMAP_INBOUND` programını açın. Kaydettiğiniz profil adını girin. **List only (no downloads/changes)** seçeneğini işaretleyip çalıştırın. Bu adım uygun iletilerin numaralarını (`UID`) listeler; içerik ve ekleri göstermez, e-postaları taşımaz.
3. Listeleme başarılıysa aynı deneme profilini `ZIMAP_HANDLER_DEMO` ile, bu kez **List only seçeneği kapalı** çalıştırın. Artık ileti ve ekleri gerçekten alınır; örnek programın sonucu kaydedilir ve başarılı ileti işlenmiş klasörüne taşınır.
4. `ZIMAP_MONITOR` programında sonucu ve ekleri inceleyin. Başarıyla tamamlanan ileti `S` durumunda görünür; posta kutusunda da seçtiğiniz işlenmiş klasöründe bulunmalıdır.
5. Deneme tamamlandıktan sonra kendi iş kurallarınızı geliştiriciyle ekleyin. Düzenli çalışmayı Basis, kurulum yapılan **aynı SAP uygulama sunucusunda** bir arka plan işi olarak planlasın.

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

Kaynaklar klasik ABAP sistemleri için **4.6C–7.5x** uyumluluğunu hedefler. Bu bir uyumluluk sertifikası değildir; hedef SAP sürümünüzde derleme ve çalışma testi gerekir.

## Yetkiler ve işletim sınırları

Basis, yetkileri ilgili kullanıcılara ve tablo yetki gruplarına göre tanımlar. Uygulama tablo erişimini `VIEW_AUTHORITY_CHECK` ile denetler; dosya ve komut yetkileri ayrıca kontrol edilir.

| Rol | Gerekli erişim |
|---|---|
| Job kullanıcısı | `ZIMAP_PROFILE` görüntüleme; `ZIMAP_LOG` değiştirme; `S_LOG_COM` üzerinden `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE`; `S_DATASET` üzerinden gelen mail dosyalarını okuma; handler'ın ihtiyaç duyduğu yetkiler. |
| Profil yöneticisi | `ZIMAP_PROFILE` görüntüleme/değiştirme; `ZIMAP_TEST` çalıştırma; `ZIMAP_CONFIG` için profil ve kimlik bilgisi dosyalarına `S_DATASET` yazma erişimi. |
| İzleme kullanıcısı | `ZIMAP_LOG` görüntüleme; `ZIMAP_MONITOR` için gelen/arşiv dosyalarını okuma. Yeniden işleme ayrıca `ZIMAP_LOG` değiştirme yetkisi gerektirir. |
| Kurulumu yapan | Proje nesneleri için geliştirme yetkileri ve SM69 komutlarını yönetip test etme yetkileri. Kaldırmada ek client kontrolleri vardır. |

- Proje şifreleri **kendi SAP tablolarına yazmaz**. Kimlik bilgileri işletim sistemi izinleriyle korunan düz metin dosyalardır; SAP servis hesabı ve ayrıcalıklı yöneticiler erişebilir. Uygulama kaydedilmiş şifreyi göstermez.
- SAP'den şifre girişinde normal varyant kaydetme ve yazdırma kapatılır. Gerekli koruma API'si yoksa yeni şifre girişi kapanır; Basis'in yönettiği `O` kaynağını kullanın.
- İzinli mail sunucuları, TLS istisnaları, boyut sınırları ve zaman aşımı `bin/policy.psd1` içinde Basis tarafından belirlenir. SAP servis hesabının `bin` erişimi okuma/çalıştırmayla sınırlıdır.
- Profil dosyaları sistem, client ve profil adına göre ayrılır; revizyon olarak yayımlanır. Mail geçmişi olan profil başka posta kutusuna yönlendirilemez veya silinemez; devre dışı bırakıp yeni profil oluşturun.
- Kurulum tek bir uygulama sunucusuna bağlıdır. Yerel dosyalar uygulama sunucuları arasında otomatik paylaşılmaz.
- Saklama süresi dolan uygun, tamamlanmış **yerel arşivler** normal çalışma sırasında temizlenir. Salt okunur test modu bu temizliği yapmaz. Bu işlem `ZIMAP_LOG` kayıtlarını veya uzaktaki işlenenler klasörünü silmez.

## Bilinen sınırlar

- Klasör adlarında ASCII harf, rakam ve `. _ / -` kullanılır; boşluk olmaz. Eski mail sunucularıyla uyum için ASCII şifre tercih edin.
- İlk `text/plain` bölüm metin olarak alınır; yoksa HTML düz metne çevrilir. S/MIME çözme ve `winmail.dat` açma desteği yoktur.
- Bozuk veya desteklenmeyen MIME, aşırı iç içe yapı/parça sayısı ve SAP dosya biçimine sığmayan metadata, tamamlanmış gibi gösterilmek yerine reddedilir.
- Monitör sorgu başına en fazla 1.000 satır gösterir. Gerektiğinde tarih, profil veya durum seçimini daraltın.

## Neler doğrulandı?

Aşağıdaki ayrım **1.1.0 kaynakları** için geçerlidir:

| Alan | Kanıt |
|---|---|
| Ayrıştırıcı ve IMAP akışı | Windows PowerShell 5.1/7 ve Linux PowerShell 7.4 üzerinde GreenMail 2.1.14 ile yerel regresyon koşuları. Kimlik/revizyon, yeniden deneme, yarım kalan taşıma, retention, bozuk MIME ve boyut sınırlarını kapsar. |
| Linux kurulumu | SAP'yi temsil eden ayrı bir işletim sistemi hesabıyla izole konteynerde kurulum, self-test ve izin denetimleri. |
| Kaynak ve build | ABAP ASCII/72 sütun kontrolü, 7.02 hedefli sekiz dosyalık abaplint ayrıştırması, PowerShell ayrıştırması, Windows native yardımcı kodunun derlenmesi, Bash denetimleri ve tekrarlanabilir installer üretimi. |
| Gerçek SAP çalışma zamanı | Güncellenmiş 1.1.0 installer, ekran ve transaction akışları SAP üzerinde doğrulanmayı bekliyor. Mevcut ekran görüntüleri SAP ABAP Platform Trial 2025 üzerindeki 1.0 demosundan. |
| Eski/Unicode olmayan SAP | Uyumluluk hedefi; 4.6C–7.0 üzerinde doğrulanmadı. |
| Windows sunucu kurulumu | Güncellenmiş kurulum mantığı gerçek bir SAP Windows sunucusunda çalıştırılmadı. |

Kontroller elle çalıştırılır; depoda otomatik CI iş akışı bulunmaz. Ayrıştırma kontrolü SAP derleyicisinin veya çalışma zamanı testinin yerini tutmaz.

## Mevcut kurulumu güncelleme

Dosyaları değiştirmeden önce [güncelleme adımlarını](WALKTHROUGH.md#8-mevcut-kurulumu-güncelleyin) okuyun. 1.1.0; betik protokolünü, profil adlandırmasını ve revizyonlu dosya yapısını değiştirir.

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
