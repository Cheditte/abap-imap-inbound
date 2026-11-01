# Kurulum rehberi: ilk e-postayı SAP'de görün

> [English](../WALKTHROUGH.md) | **Türkçe** · [Projeyi tanıyın](../../README.tr.md) · [Teknik ayrıntılar](TECHNICAL-REFERENCE.md)

Bu rehberin sonunda bir deneme e-postasını ve ekini SAP içinden görebileceksiniz. Hazır örneği kullanacağız; kendi iş sürecinizi daha sonra ekleyebilirsiniz.

Bir modül danışmanı veya süreç sorumlusu kurulumu koordine edebilir. **Basis** (SAP sistem yönetimi) sunucu hazırlığında, **e-posta yöneticisi** posta hesabında, **ABAP geliştiricisi** SAP programlarının kurulmasında yardımcı olur.

**Bu ekipler yoksa:** Kendi deneme sisteminizi yönetiyorsanız ilgili hazırlıkları siz de yapabilirsiniz. SAP'nin çalıştığı makineye Windows'ta **Uzak Masaüstü (RDP)**, Linux'ta **SSH** ile bağlanmanız gerekebilir. Posta hesabı için de sağlayıcınızın yönetim panelini kullanabilirsiniz. Bunun için ilgili sunucuya veya hesaba erişim ve yönetim yetkiniz olmalı. [Ekip desteği olmadan kurulum rehberi](SELF-MANAGED-SETUP.md), hangi durumda hangi yolu izleyeceğinizi anlatır.

**Önce bir deneme SAP sistemi ve deneme posta kutusu kullanın.** İşlem sırasında e-postalar okundu işaretlenebilir ve başka klasöre taşınabilir. Hazır örnek fatura veya sipariş oluşturmaz.

Bu rehber 1.1.0 kaynakları içindir. Bu sürümün gerçek SAP sistemindeki kurulum ve çalışma testleri henüz tamamlanmadı. Görseller önceki 1.0 demosundandır; ekranlarda farklılık olabilir. [Test durumu](TECHNICAL-REFERENCE.md#neler-doğrulandı).

## Başlamadan önce: neyi, nerede hazırlıyoruz?

Kurulumun iki parçası var:

| Nerede? | Ne yapıyoruz? | Neden gerekiyor? |
|---|---|---|
| **SAP'nin çalıştığı makinede** | Gerekli yardımcı araçları kontrol edip eksik olanları kuruyor, projenin sunucu dosyalarını yerleştiriyoruz. | Posta hesabına bağlanıp iletileri ve eklerini almak için. |
| **SAP içinde** | Projenin programlarını kuruyor ve posta kutusu bilgilerini giriyoruz. | İşlemi SAP'den başlatmak ve sonuçları SAP ekranında görmek için. |

SAP GUI'yi açtığınız bilgisayarla SAP'nin çalıştığı makine farklı olabilir. Sunucu hazırlığını Basis yapmalıdır. Ayrıca bir entegrasyon sunucusu kurmanız gerekmez.

### Dosyaları indirin ve ekiple paylaşın

[GitHub deposunu](https://github.com/Cheditte/abap-imap-inbound) açın, **Code → Download ZIP** seçin ve arşivin tamamını bir klasöre çıkartın. Git kurmanız gerekmez.

Aynı paketi Basis ve geliştiriciyle paylaşın. Klasör yapısını koruyun; farklı sürümlerden dosyaları karıştırmayın. Basis sunucu dosyalarını, geliştirici ana klasördeki `ZIMAP_INSTALL.abap` dosyasını kullanacak.

### Deneme posta kutusunu hazırlayın

E-posta yöneticinizden sunucu adını, bağlantı portunu, güvenlik türünü ve giriş bilgilerini alın. **Doğru e-posta adresi ve parola tek başına yeterli olmayabilir.** Başka bir programın kutuyu okumasına, yani **IMAP erişimine**, izin verilmelidir. Posta ekibi hesabın bu projeyle bağlantı kurmaya uygun olduğunu doğrulasın. [Ayrıntılı bağlantı koşulları](TECHNICAL-REFERENCE.md#başlamadan-önce-posta-kutunuz-uygun-mu).

E-posta ekibiniz yoksa bu bilgileri, yönettiğiniz hesabın sağlayıcı panelinden veya sağlayıcının desteğinden alın. Yalnız kendi posta kutunuzu açabiliyor olmanız, posta sunucusunun ayarlarını değiştirebildiğiniz anlamına gelmez. [Posta hesabını kendiniz hazırlama](SELF-MANAGED-SETUP.md).

Varsayılan olarak **Gelen Kutusu (`INBOX`)** okunur. Yalnız belirli bir klasördeki iletileri almak isterseniz o klasörü seçebilirsiniz. İşlenen iletiler için de aynı posta hesabındaki mevcut bir klasörü kullanabilirsiniz. `SAP-Processed` başlangıç adıdır; bu adla yeni klasör açmak zorunda değilsiniz. Seçtiğiniz klasörlerin gerçek adlarını posta ekibinden doğrulayın.

## 1. Sunucuyu hazırlayın (Basis)

**Ne yapıyoruz?** SAP'nin kurulu olduğu Windows veya Linux makinede e-postaları alacak araçları ve proje dosyalarını hazırlıyoruz. Bu, genellikle ilk kurulumda bir kez yapılır.

| Hazırlanacak parça | Ne işe yarar? |
|---|---|
| **PowerShell** | Projenin e-posta alma komutlarını çalıştırır. Windows'ta 5.1 veya üzeri, Linux'ta 7 gerekir. |
| **curl** | Posta sunucusuyla bağlantıyı kurar. Şifreli IMAP bağlantısını desteklemelidir. |
| **Projenin sunucu dosyaları** | İletileri ve ekleri SAP'nin okuyabileceği dosyalara hazırlar. İndirdiğiniz paketin içindedir. |
| **Korumalı çalışma klasörü** | E-postaların, eklerin ve bağlantı ayarlarının sunucuda tutulacağı yerdir. Basis yolunu ve erişim izinlerini belirler. |

PowerShell veya curl zaten uygunsa tekrar kurulmaz. Basis eksikleri kurumunuzun kurulum yöntemiyle tamamlar; ardından paketteki sunucu kurulumunu çalıştırır. Kullanılacak Windows/Linux komutları [Basis için sunucu kurulum bölümündedir](TECHNICAL-REFERENCE.md#sunucu-kurulumu-komutlar-ve-kontroller).

Basis ayrıca **SAP'nin çalıştığı makineden posta sunucusuna bağlantı kurulabildiğini** kontrol eder. Kendi bilgisayarınızdan posta hesabına erişmeniz bu kontrolün yerini tutmaz.

Basis ekibiniz yoksa bu adımı, yönetim yetkiniz bulunan kendi deneme sunucunuzda siz uygulayabilirsiniz. Sunucuya nasıl bağlanacağınız, dosyaları nereye aktaracağınız ve komutları nerede çalıştıracağınız [ayrı rehberde](SELF-MANAGED-SETUP.md) açıklanıyor.

**Ne zaman devam edebilirsiniz?** Basis sunucu testinin başarılı olduğunu doğruladığında. Basis'ten kullanılacak SAP sunucusunu ve hazırlanan çalışma klasörünün **tam yolunu** alın. Sonraki adımlarda aynı sunucuyu ve klasörü kullanacağız.

## 2. Kurulum programını oluşturun

**Ne yapıyoruz?** SAP'nin gerekli programlarını ve tablolarını oluşturacak kurulum programını hazırlıyoruz. Bu adım SAP geliştirme yetkisi gerektirir; geliştirici desteği alın.

SAP GUI'nin üstteki komut alanına `SE38` yazın. Bu, program editörünü açar. Başka bir ekranın içindeyseniz `/nSE38` kullanabilirsiniz.

1. Program adı olarak **`ZIMAP_INSTALL`** yazıp **Create / Oluştur** seçin.
2. Açıklama girin; tür olarak **Executable program / Çalıştırılabilir program** seçin.
3. Kaydederken geliştiricinizin oluşturduğu müşteri paketini kullanın; örneğin `ZIMAP`. Yalnız geçici denemede **Local Object / Yerel Nesne** seçilebilir.
4. İndirdiğiniz [ZIMAP_INSTALL.abap](../../ZIMAP_INSTALL.abap) dosyasının **tamamını** açıp SAP editörüne yapıştırın.
5. Kaydedin, sözdizimi kontrolünü yapın ve **Activate / Etkinleştir** seçin.

![SE38'de kurulum programını oluşturma — önceki demo](../screenshots/01-se38-create.png)

**Ne zaman devam edebilirsiniz?** Program hata vermeden etkinleştiğinde. Hata varsa geliştirici çözmeden sonraki adıma geçmeyin. Program adını aynen kullanın.

## 3. Kurulum programını çalıştırın

**Ne yapıyoruz?** Kurulum programı gerekli SAP ekranlarını, tablolarını ve sunucuyla bağlantı için gereken tanımları oluşturacak.

SE38'de **`ZIMAP_INSTALL`** açıp **Execute / Çalıştır (F8)** seçin.

![Kurulum seçenekleri — önceki demo](../screenshots/02-install-screen.png)

- İlk kurulumda **DDIC objects**, **Programs**, **SM69 commands** ve **Server check** seçili kalsın. Bunlar tabloları, programları, sunucu komutlarını ve son kontrolü kapsar.
- **Server folder** alanına Basis'in verdiği **tam klasör yolunu** girin. Ekrandaki örnek yolun size uygun olduğunu varsaymayın.
- **Uninstall / Kaldır** seçilmesin. Diğer seçenekleri geliştiriciyle kontrol edin.
- **F8** ile çalıştırın ve sonuç listesini okuyun.

**Ne zaman devam edebilirsiniz?** Seçilen kurulum adımları ve son sunucu kontrolü başarılı olduğunda. Bir adım hata verirse çıktıyı Basis/geliştiriciyle paylaşın.

**Kalıcı kullanım için:** Kurulum programı ürettiği nesneleri şu anda `$TMP` adlı yerel alana koyar. Programın kendisini pakete kaydetmek bunu değiştirmez. Geliştirici, nesneleri müşteri paketine almalı ve test/canlı sisteme taşıma sürecini planlamalıdır. [Paket ve taşıma ayrıntıları](TECHNICAL-REFERENCE.md#2b-canlıya-çıkmadan-önce-paket-ve-transport).

## 4. Posta kutusu profilini tanımlayın

**Ne yapıyoruz?** Hangi posta hesabına bağlanacağımızı ve hangi klasördeki iletileri okuyacağımızı SAP'ye söylüyoruz. Bu ayarların birlikte kaydedilmiş haline **profil** denir.

SE38'de **`ZIMAP_CONFIG`** açıp **F8** ile çalıştırın. Basis'in hazırladığı sunucuya bağlı SAP oturumunu kullanın; emin değilseniz Basis kontrol etsin.

![Posta ayarları — önceki demo; görseldeki bağlantı bilgilerini kopyalamayın](../screenshots/04-config-profile.png)

| Alan | Ne yazacaksınız / seçeceksiniz? |
|---|---|
| Profil | Ayarlarınıza vereceğiniz bir ad. Örneğin `INVOICE`; kendi adınızı seçebilirsiniz. Sonraki adımlarda aynı adı kullanın. |
| Aktif | Seçili olsun; bu profilin işlenmesine izin verir. |
| Sunucu, port ve güvenlik | E-posta ekibinizin verdiği gerçek bilgiler. Sunucu alanına e-posta adresinizi yazmayın. Sertifika doğrulaması açık kalsın. |
| Kullanıcı ve parola | E-posta ekibinizin doğruladığı bilgiler. Parola kaynağı `S` ise parolayı SAP ekranından girersiniz; `O` ise Basis sunucuda kaydeder. Yöntemi Basis ile belirleyin. |
| Okunacak klasör | Varsayılan `INBOX`, Gelen Kutusu'nu okur. Başka klasör için onun gerçek adını/yolunu girin. |
| İşlenmiş klasörü | Başarılı iletilerin taşınacağı, aynı posta hesabındaki, okunacak klasörden farklı seçtiğiniz klasörün gerçek adı/yolu. `SAP-Processed` adı zorunlu değildir. |
| Taşıma yöntemi | İlk denemede `MOVE` seçin. |
| Handler programı | **`ZIMAP_HANDLER_DEMO`** kalsın. Bu, her e-posta için çalışacak hazır örnek programdır. |

İlk denemede ileti sayısı, boyut ve zaman aşımı gibi diğer sınırları Basis ile kontrol edip başlangıç değerlerinde bırakabilirsiniz. Ayrıntılı alanlar ve sunucuda parola kaydetme işlemi [teknik rehberde](TECHNICAL-REFERENCE.md#profil-alanları-ve-sunucuda-parola-yönetimi).

**F8** ile kaydedip bağlantıyı test edin. Parolayı ekran görüntüsüne veya destek kaydına eklemeyin.

**Ne zaman devam edebilirsiniz?** Doğru posta hesabına bağlantı testi başarılı olduğunda. Ayarların kaydedilmesi tek başına bağlantının kurulduğu anlamına gelmez.

## 5. E-postayı işleyin

**Ne yapıyoruz?** Önce posta kutusunun okunabildiğini kontrol ediyor, sonra deneme iletisini gerçekten alıyoruz.

Deneme posta kutusuna küçük bir PDF veya metin eki bulunan e-posta gönderin. Gelen Kutusu yerine başka klasör seçtiyseniz iletiyi o klasöre koyun.

1. SE38'de **`ZIMAP_INBOUND`** açıp çalıştırın.
2. Önceki adımda kaydettiğiniz **profil adını** girin.
3. **List only (no downloads/changes)**, yani **yalnız listele** seçeneğini işaretleyip **F8** basın. Uygun iletilerin numaraları listelenir; içerik ve ekler henüz alınmaz, iletiler taşınmaz.
4. Listeleme başarılıysa geri dönün, **yalnız listele işaretini kaldırın** ve tekrar çalıştırın. Bu kez e-posta ve ekleri alınır, hazır örnek çalışır ve başarılı ileti seçtiğiniz işlenmiş klasörüne taşınır.

![İşleme ekranı — önceki demo; güncel listeleme modu içerik göstermez](../screenshots/06-inbound-screen.png)

**Ne zaman devam edebilirsiniz?** Çalıştırma tamamlandığında. Şimdi sonucu SAP'de ve posta kutusunda kontrol edeceğiz.

## 6. E-postaları ve ekleri izleyin

**Ne yapıyoruz?** İşlemin sonucunu görüyor ve ekin SAP'den erişilebilir olduğunu kontrol ediyoruz.

1. SE38'de **`ZIMAP_MONITOR`** açıp çalıştırın.
2. Profilinizi ve deneme gününü kapsayan tarih aralığını seçip **F8** basın.
3. Deneme iletinizin kaydını açın; metnini ve eklerini inceleyin.
4. Posta hesabınızı da açın. Başarılı ileti seçtiğiniz işlenmiş klasöründe bulunmalı.

![Sonuçları izleme ekranı — önceki demo](../screenshots/08-monitor-list.png)

| Durum | Kısaca anlamı |
|---|---|
| `S` | İşlem ve posta taşıması tamamlandı. |
| `E` | Hata oluştu; kayıttaki açıklamayı inceleyin. |
| `R` | Hatalı ileti yeniden denenmek üzere işaretlendi. |
| `H` | SAP'deki iş adımı tamamlandı, postanın taşınması bekliyor. |

PDF ve yaygın görseller uygun uygulamayla açılabilir. Excel gibi diğer ekleri indirip bilgisayarınızdaki uygulamayla inceleyebilirsiniz.

**İlk deneme başarılıysa:** SAP'de `S` durumunu, erişilebilir eki ve posta hesabında taşınan iletiyi görmüş olmalısınız. Hazır örnekte ayrıca fatura veya sipariş oluşması beklenmez.

### Bir adımda hata alırsanız

- **Giriş veya klasör hatası:** E-posta ekibine bağlantı bilgilerini, IMAP iznini ve seçilen klasör adlarını kontrol ettirin.
- **Bağlantı, sertifika veya SAP yetki hatası:** Basis'ten destek alın; sertifika doğrulamasını kapatarak geçmeyin.
- **Örnek veya kendi iş programınız hata veriyorsa:** Geliştiriciyle hata açıklamasını inceleyin. Hazır örnek, konusu `TEST-ERROR` içeren iletilerde bilerek hata verir.

Hata metnini ve kaldığınız adımı paylaşın; parola paylaşmayın. Yetkili kullanıcı hatalı iletileri yeniden denemeye alabilir. Log veya sunucu dosyalarını silerek tekrar işlemeyi denemeyin. [Yeniden deneme ayrıntıları](TECHNICAL-REFERENCE.md#saklama-ve-yeniden-deneme-ayrıntıları).

## 7. Düzenli çalışmayı zamanlayın

**Ne yapıyoruz?** Başarılı denemeden sonra posta kontrolünün elle başlatılmadan, belirlenen aralıklarla çalışmasını sağlıyoruz.

Basis, `ZIMAP_INBOUND` için bir **arka plan işi** oluşturur. Doğru profil kullanılmalı, yalnız listeleme kapalı olmalı ve iş hazırladığımız **aynı SAP makinesinde** çalışmalıdır. Basis bu işi çalıştıracak kullanıcıyla da deneme yapar.

Gerçek iş adımını danışman ve geliştiriciyle belirleyin. Örneğin eki bir siparişe bağlama işlemi [geliştirici rehberindeki](TECHNICAL-GUIDE.md) bağlantı noktasıyla eklenir. Canlı kullanımdan önce iş kurallarını, yetkileri ve paketle taşıma sürecini test sisteminizde doğrulayın.

**Mevcut kurulumu güncelliyorsanız** ilk kurulum adımlarını doğrudan tekrarlamak yerine [güncelleme yolunu](TECHNICAL-REFERENCE.md#8-mevcut-kurulumu-güncelleyin) izleyin. Sunucu komutları ve ayrıntılı kontroller [teknik başvuru rehberindedir](TECHNICAL-REFERENCE.md).
