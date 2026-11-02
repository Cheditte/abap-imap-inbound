# Kurulum rehberi: üç bölümü hazırlayın, ilk e-postayı SAP'de görün

> [English](../WALKTHROUGH.md) | **Türkçe** · [Genel bakış](../../README.tr.md) · [Teknik ayrıntılar](TECHNICAL-REFERENCE.md)

Bu rehberle, posta sunucusundaki e-postaları ve eklerini SAP'ye alacak kurulumu yapacaksınız. Önce üç hazırlık alanını göreceğiz; sonra her birini sırayla tamamlayıp bir deneme e-postasını SAP'de açacağız.

## Önce bütün resmi görün

Kurulumun tamamlanması için **üç bölüm** hazır olmalı:

![Üç parçalı kurulum: posta sunucusu, SAP makinesi ve SAP ERP](../assets/diagrams/setup-tr.svg)

Bu üç ayrı makine kurmak anlamına gelmez. **2. bölüm**, SAP sunucusundaki Windows/Linux hazırlığı; **3. bölüm**, SAP GUI içinden yaptığınız program ve ayar işlemleridir. Posta hizmetiniz zaten mevcut olabilir.

Önce 1. bölümde bağlantı bilgilerini hazırlayacağız, sonra 2. bölümde bu bağlantıyı SAP makinesinden kuracağız. 3. bölümde SAP programlarını kurup bu bilgileri kullanacağız. Son olarak hepsini tek bir deneme e-postasıyla kontrol edeceğiz.

## Başlamadan önce

SE38'de program oluşturma, etkinleştirme ve çalıştırma bilgi ve yetkinizin bulunduğunu varsayıyoruz. SAP adımlarını siz yapacaksınız. Posta ve sunucu yönetim yetkisi sizdeyse o hazırlıkları da yapabilirsiniz; başka ekipteyse ilgili bölümdeki bilgileri onlardan isteyin. Bu rehberde Basis, sunucu yönetim sorumluluğunu üstlenen kişi veya ekibi ifade eder.

RDP/SSH ile kendiniz bağlanacaksanız [kendi sistemini yönetenler için rehber](SELF-MANAGED-SETUP.md) bağlantı ve dosya aktarımını anlatır.

**Deneme SAP sistemi ve deneme posta kutusu kullanın.** Normal işlem iletileri okundu işaretleyebilir ve başka klasöre taşıyabilir. Hazır örnek fatura oluşturmaz.

Bu rehber 0.9.2 kaynakları içindir; güncel sürümün gerçek SAP kabul testleri henüz tamamlanmadı. [Test durumu](../../VALIDATION.md).

### Dosyaları indirin

[GitHub deposunu](https://github.com/Cheditte/abap-imap-inbound) açın, **Code → Download ZIP** seçin ve arşivin tamamını bir klasöre çıkartın. Git kurmanız gerekmez.

Klasör yapısını koruyun; farklı sürümlerden dosyaları karıştırmayın. SAP adımlarında ana klasördeki `ZCHE_IMAP_INSTALL.abap` dosyasını kullanacaksınız. Sunucu hazırlığını başka biri yapacaksa aynı paketi onunla paylaşın; `server` ve `script` klasörleri birlikte gerekir.

## 1. Posta sunucusunu hazırlayın

**Hedef:** SAP'nin okuyacağı posta hesabını, erişim yöntemini ve klasörleri belirlemek. Yeni bir posta sunucusu kurmanız gerekmez; mevcut bir hizmette uygun bir hesap kullanabilirsiniz.

E-posta yöneticinizden sunucu adını, bağlantı portunu, güvenlik türünü ve giriş bilgilerini alın. **Doğru e-posta adresi ve parola tek başına yeterli olmayabilir.** Başka bir programın kutuyu okumasına, yani **IMAP erişimine**, izin verilmelidir. Posta ekibi hesabın bu projeyle bağlantı kurmaya uygun olduğunu doğrulasın. [Ayrıntılı bağlantı koşulları](TECHNICAL-REFERENCE.md#başlamadan-önce-posta-kutunuz-uygun-mu).

E-posta ekibiniz yoksa bu bilgileri, yönettiğiniz hesabın sağlayıcı panelinden veya sağlayıcının desteğinden alın. Yalnız kendi posta kutunuzu açabiliyor olmanız, posta sunucusunun ayarlarını değiştirebildiğiniz anlamına gelmez. [Posta hesabını kendiniz hazırlama](SELF-MANAGED-SETUP.md).

Varsayılan olarak **Gelen Kutusu (`INBOX`)** okunur. Yalnız belirli bir klasördeki iletileri almak isterseniz o klasörü seçebilirsiniz. İşlenen iletiler için de aynı posta hesabındaki mevcut bir klasörü kullanabilirsiniz. `SAP-Processed` başlangıç adıdır; bu adla yeni klasör açmak zorunda değilsiniz. Seçtiğiniz klasörlerin gerçek adlarını posta ekibinden doğrulayın.

![Okunacak klasörden SAP işlemeye ve farklı hedef klasöre giden ileti yolu](../assets/diagrams/mail-flow-tr.svg)

**Bu bölümün çıktısı:** Posta sunucusu adı, port, güvenlik türü, giriş bilgileri, okunacak klasör ve ondan farklı hedef klasörün gerçek adları. Parolayı destek kaydına veya ekran görüntüsüne koymayın.

## 2. SAP'nin kurulu olduğu makineyi hazırlayın

**Ne yapıyoruz?** SAP'nin kurulu olduğu Windows veya Linux makinede e-postaları alacak araçları ve proje dosyalarını hazırlıyoruz. Bu, genellikle ilk kurulumda bir kez yapılır.

![SAP makinesinde hazırlanacaklar: araçlar, proje dosyaları ve korumalı klasör](../assets/diagrams/host-prep-tr.svg)

| Hazırlanacak parça | Ne işe yarar? |
|---|---|
| **PowerShell** | Projenin e-posta alma komutlarını çalıştırır. Windows'ta 5.1 veya üzeri, Linux'ta 7 gerekir. |
| **curl** | Posta sunucusuyla bağlantıyı kurar. **8.0.0 veya üzeri** olmalı ve şifreli IMAP (`imaps`) desteklemelidir. |
| **Projenin sunucu dosyaları** | İletileri ve ekleri SAP'nin okuyabileceği dosyalara hazırlar. İndirdiğiniz paketin içindedir. |
| **Korumalı çalışma klasörü** | E-postaların, eklerin ve bağlantı ayarlarının sunucuda tutulacağı yerdir. Basis yolunu ve erişim izinlerini belirler. |

PowerShell veya curl zaten uygunsa tekrar kurulmaz. Basis eksikleri kurumunuzun kurulum yöntemiyle tamamlar; ardından paketteki sunucu kurulumunu çalıştırır. Kullanılacak Windows/Linux komutları [Basis için sunucu kurulum bölümündedir](TECHNICAL-REFERENCE.md#sunucu-kurulumu-komutlar-ve-kontroller).

Basis ayrıca **SAP'nin çalıştığı makineden posta sunucusuna bağlantı kurulabildiğini** kontrol eder. Kendi bilgisayarınızdan posta hesabına erişmeniz bu kontrolün yerini tutmaz.

Basis ekibiniz yoksa bu adımı, yönetim yetkiniz bulunan kendi deneme sunucunuzda siz uygulayabilirsiniz. Sunucuya nasıl bağlanacağınız, dosyaları nereye aktaracağınız ve komutları nerede çalıştıracağınız [ayrı rehberde](SELF-MANAGED-SETUP.md) açıklanıyor.

**Ne zaman devam edebilirsiniz?** Sunucuyu siz hazırladıysanız testin başarılı olduğunu kontrol edin; başka ekip hazırladıysa bu sonucu onlardan alın. Kullanılacak SAP sunucusunu ve çalışma klasörünün **tam yolunu** not edin. Sonraki adımlarda aynı sunucuyu ve klasörü kullanacağız.

## 3. SAP ERP içindeki kurulumu yapın

Posta bilgileri ve sunucu hazırlığı tamamlandı. Şimdi SAP GUI içinde programları kuracak ve bu iki bölümden gelen bilgileri SAP'ye tanıtacağız. Bu bölümde üç işlem var: kurulum programını oluşturma, çalıştırma ve posta profilini kaydetme.

![SAP ERP kurulum sırası: programı oluşturun, kurulumu çalıştırın ve postayı tanımlayın](../assets/diagrams/sap-steps-tr.svg)

### 3.1. Kurulum programını oluşturun

**Ne yapıyoruz?** SAP'nin gerekli programlarını ve tablolarını oluşturacak kurulum programını hazırlıyoruz. Bu adımı kendi SAP geliştirme yetkinizle uygulayın.

SE38 üzerinden aşağıdaki programı oluşturun.

1. Program adı olarak **`ZCHE_IMAP_INSTALL`** yazıp **Create / Oluştur** seçin.
2. Açıklama girin; tür olarak **Executable program / Çalıştırılabilir program** seçin.
3. Kaydederken kendi oluşturduğunuz veya projeye ayrılmış müşteri paketini kullanın; örneğin `ZCHE_IMAP`. Yalnız geçici denemede **Local Object / Yerel Nesne** seçilebilir.
4. İndirdiğiniz [ZCHE_IMAP_INSTALL.abap](../../ZCHE_IMAP_INSTALL.abap) dosyasının **tamamını** açıp SAP editörüne yapıştırın.
5. Kaydedin, sözdizimi kontrolünü yapın ve **Activate / Etkinleştir** seçin.

**Ne zaman devam edebilirsiniz?** Program hata vermeden etkinleştiğinde. Sözdizimi veya etkinleştirme hatası varsa çözmeden sonraki adıma geçmeyin. Program adını aynen kullanın.

### 3.2. Kurulum programını çalıştırın

**Ne yapıyoruz?** Kurulum programı gerekli SAP ekranlarını, tablolarını ve sunucuyla bağlantı için gereken tanımları oluşturacak.

SE38'de **`ZCHE_IMAP_INSTALL`** açıp **Execute / Çalıştır (F8)** seçin.

- İlk kurulumda **DDIC objects**, **Programs**, **SM69 commands** ve **Server check** seçili kalsın. Bunlar tabloları, programları, sunucu komutlarını ve son kontrolü kapsar.
- **Server folder** alanına Basis'in verdiği **tam klasör yolunu** girin. Ekrandaki örnek yolun size uygun olduğunu varsaymayın.
- **Uninstall / Kaldır** seçilmesin. Diğer seçenekleri kontrol edin.
- **F8** ile çalıştırın ve sonuç listesini okuyun.

**Ne zaman devam edebilirsiniz?** Seçilen kurulum adımları ve son sunucu kontrolü başarılı olduğunda. Hata veren adımın çıktısını inceleyin; sunucu erişimi veya yetki sorunu başka bir ekibin sorumluluğundaysa onlara iletin.

**Kalıcı kullanım için:** Kurulum programı ürettiği nesneleri şu anda `$TMP` adlı yerel alana koyar. Programın kendisini pakete kaydetmek bunu değiştirmez. Nesneleri müşteri paketinize alıp test/canlı sisteme taşıma sürecini planlayın; transport ayarları başka ekipteyse onlarla koordine edin. [Paket ve taşıma ayrıntıları](TECHNICAL-REFERENCE.md#2b-canlıya-çıkmadan-önce-paket-ve-transport).

### 3.3. Yetki nesnesini ve rolü oluşturun

**Ne yapıyoruz?** Kullanıcınızın programları çalıştırabilmesini sağlıyoruz. Her program, profil bazında `ZCHE_IMAP` yetki nesnesini kontrol eder; bu yetki yoksa deneme için bile yetki mesajıyla durur.

1. **SU20:** `ZCHE_IMAP_PROFID` veri elemanıyla `ZCHE_PROF` yetki alanını oluşturun. Bu veri elemanını kurulum programı 3.2. adımda oluşturdu.
2. **SU21:** `ZCHE_PROF` ve `ACTVT` alanlarıyla `ZCHE_IMAP` yetki nesnesini oluşturun. `02`, `03` ve `16` aktivitelerine izin verin.
3. **PFCG:** Bir role `ZCHE_IMAP` nesnesini profil adınızla (örneğin `INVOICE`) ve gereken aktivitelerle ekleyin: görüntüleme için `03`, profil bakımı ve yeniden işleme için `02`, işlemeyi çalıştırmak için `16`. Ayrıca şunları ekleyin:
   - `ZCHI` tablo grubu için `S_TABU_DIS`: görüntüleme için `03`, değiştirme için `02`.
   - SM69 komutları için `S_LOG_COM`: bağlantı testi için `ZCHE_IMAP_TEST`; işleme için `ZCHE_IMAP_LIST`, `ZCHE_IMAP_FETCH` ve `ZCHE_IMAP_DONE`.
   - 2. adımdaki çalışma klasörü için `S_DATASET`; ayrıntısı [yetki rehberinde](../../SECURITY.md#file-access--dosya-erişimi).

   Rolü kendi kullanıcınıza ve arka plan işini çalıştıran kullanıcıya atayın. Geniş geliştirici rolleri bunları zaten içerebilir; eksik olan yetki programı yetki mesajıyla durdurur.

Bu nesneleri yetki ekibiniz de oluşturabilir. Aktivitelerin, dosya izinlerinin ve işlem kodlarının ayrıntısı [yetki rehberinde](../../SECURITY.md).

**Ne zaman devam edebilirsiniz?** Rol kullanıcınıza atandığında. Yeni yetki görünmüyorsa oturumu kapatıp yeniden açın.

### 3.4. Posta kutusu profilini tanımlayın

**Ne yapıyoruz?** Hangi posta hesabına bağlanacağımızı ve hangi klasördeki iletileri okuyacağımızı SAP'ye söylüyoruz. Bu ayarların birlikte kaydedilmiş haline **profil** denir.

SE38'de **`ZCHE_IMAP_CONFIG`** açıp **F8** ile çalıştırın. Basis'in hazırladığı sunucuya bağlı SAP oturumunu kullanın; emin değilseniz Basis kontrol etsin.

| Alan | Ne yazacaksınız / seçeceksiniz? |
|---|---|
| Profil | Ayarlarınıza vereceğiniz bir ad. Örneğin `INVOICE`; kendi adınızı seçebilirsiniz. Sonraki adımlarda aynı adı kullanın. |
| Aktif | Seçili olsun; bu profilin işlenmesine izin verir. |
| Sunucu, port ve güvenlik | E-posta ekibinizin verdiği gerçek bilgiler. Sunucu alanına e-posta adresinizi yazmayın. Sertifika doğrulaması açık kalsın. |
| Kullanıcı ve parola | E-posta ekibinizin doğruladığı bilgiler. Parola kaynağı `S` ise parolayı SAP ekranından girersiniz; `O` ise Basis sunucuda kaydeder. Yöntemi Basis ile belirleyin. |
| Okunacak klasör | Varsayılan `INBOX`, Gelen Kutusu'nu okur. Başka klasör için onun gerçek adını/yolunu girin. |
| İşlenmiş klasörü | Başarılı iletilerin taşınacağı, aynı posta hesabındaki, okunacak klasörden farklı seçtiğiniz klasörün gerçek adı/yolu. `SAP-Processed` adı zorunlu değildir. |
| Taşıma yöntemi | İlk denemede `MOVE` seçin. |
| Handler programı | **`ZCHE_IMAP_HANDLER_DEMO`** kalsın. Bu, her e-posta için çalışacak hazır örnek programdır. |

İlk denemede ileti sayısı, boyut ve zaman aşımı gibi diğer sınırları Basis ile kontrol edip başlangıç değerlerinde bırakabilirsiniz. Ayrıntılı alanlar ve sunucuda parola kaydetme işlemi [teknik rehberde](TECHNICAL-REFERENCE.md#profil-alanları-ve-sunucuda-parola-yönetimi).

**F8** ile kaydedip bağlantıyı test edin. Parolayı ekran görüntüsüne veya destek kaydına eklemeyin.

**Ne zaman devam edebilirsiniz?** Doğru posta hesabına bağlantı testi başarılı olduğunda. Ayarların kaydedilmesi tek başına bağlantının kurulduğu anlamına gelmez.

## 4. Üç bölümü birlikte deneyin

Üç bölümün de ayrı ayrı hazır görünmesi yeterli değildir. Bir e-postanın seçtiğiniz posta klasöründen alınıp SAP'de görünmesini ve hedef klasöre taşınmasını kontrol edeceğiz.

### 4.1. E-postayı işleyin

**Ne yapıyoruz?** Önce posta kutusunun okunabildiğini kontrol ediyor, sonra deneme iletisini gerçekten alıyoruz.

Deneme posta kutusuna küçük bir PDF veya metin eki bulunan e-posta gönderin. Gelen Kutusu yerine başka klasör seçtiyseniz iletiyi o klasöre koyun.

1. SE38'de **`ZCHE_IMAP_INBOUND`** açıp çalıştırın.
2. Önceki adımda kaydettiğiniz **profil adını** girin.
3. **List only (no downloads/changes)**, yani **yalnız listele** seçeneğini işaretleyip **F8** basın. Uygun iletilerin numaraları listelenir; içerik ve ekler henüz alınmaz, iletiler taşınmaz.
4. Listeleme başarılıysa geri dönün, **yalnız listele işaretini kaldırın** ve tekrar çalıştırın. Bu kez e-posta ve ekleri alınır, hazır örnek çalışır ve başarılı ileti seçtiğiniz işlenmiş klasörüne taşınır.

**Ne zaman devam edebilirsiniz?** Çalıştırma tamamlandığında. Şimdi sonucu SAP'de ve posta kutusunda kontrol edeceğiz.

### 4.2. E-postaları ve ekleri izleyin

**Ne yapıyoruz?** İşlemin sonucunu görüyor ve ekin SAP'den erişilebilir olduğunu kontrol ediyoruz.

1. SE38'de **`ZCHE_IMAP_MONITOR`** açıp çalıştırın.
2. Profilinizi ve deneme gününü kapsayan tarih aralığını seçip **F8** basın.
3. Deneme iletinizin kaydını açın; metnini ve eklerini inceleyin.
4. Posta hesabınızı da açın. Başarılı ileti seçtiğiniz işlenmiş klasöründe bulunmalı.

| Durum | Kısaca anlamı |
|---|---|
| `S` | İşlem ve posta taşıması tamamlandı. |
| `E` | Hata oluştu; kayıttaki açıklamayı inceleyin. |
| `R` | Hatalı ileti yeniden denenmek üzere işaretlendi. |
| `H` | SAP'deki iş adımı tamamlandı, postanın taşınması bekliyor. |

PDF ve yaygın görseller uygun uygulamayla açılabilir. Excel gibi diğer ekleri indirip bilgisayarınızdaki uygulamayla inceleyebilirsiniz.

**İlk deneme başarılıysa:** SAP'de `S` durumunu, erişilebilir eki ve posta hesabında taşınan iletiyi görmüş olmalısınız. Hazır örnekte ayrıca fatura veya sipariş oluşması beklenmez.

#### Bir adımda hata alırsanız

- **Giriş veya klasör hatası:** E-posta ekibine bağlantı bilgilerini, IMAP iznini ve seçilen klasör adlarını kontrol ettirin.
- **Bağlantı, sertifika veya SAP yetki hatası:** Basis'ten destek alın; sertifika doğrulamasını kapatarak geçmeyin.
- **Örnek veya kendi iş programınız hata veriyorsa:** Hata açıklamasını ve ilgili programı inceleyin. Hazır örnek, konusu `TEST-ERROR` içeren iletilerde bilerek hata verir.

Hata metnini ve kaldığınız adımı paylaşın; parola paylaşmayın. Yetkili kullanıcı hatalı iletileri yeniden denemeye alabilir. Log veya sunucu dosyalarını silerek tekrar işlemeyi denemeyin. [Yeniden deneme ayrıntıları](TECHNICAL-REFERENCE.md#saklama-ve-yeniden-deneme-ayrıntıları).

## 5. Düzenli çalışmayı zamanlayın

**Ne yapıyoruz?** Başarılı denemeden sonra posta kontrolünün elle başlatılmadan, belirlenen aralıklarla çalışmasını sağlıyoruz.

SM36 yetkiniz varsa `ZCHE_IMAP_INBOUND` için bir **arka plan işi** oluşturun; bu yetki başka ekipteyse Basis'ten planlamasını isteyin. Doğru profil kullanılmalı, yalnız listeleme kapalı olmalı ve iş hazırladığımız **aynı SAP makinesinde** çalışmalıdır. İşi çalıştıracak kullanıcıyla da deneme yapın veya ilgili ekibe yaptırın.

Gerçek iş adımını süreç sorumlusuyla belirleyip uygulayın. Örneğin eki bir siparişe bağlama işlemi [geliştirici rehberindeki](TECHNICAL-GUIDE.md) bağlantı noktasıyla eklenir. Canlı kullanımdan önce iş kurallarını, yetkileri ve paketle taşıma sürecini test sisteminizde doğrulayın.

**Mevcut kurulumu güncelliyorsanız** ilk kurulum adımlarını doğrudan tekrarlamak yerine [güncelleme yolunu](TECHNICAL-REFERENCE.md#8-mevcut-kurulumu-güncelleyin) izleyin. Sunucu komutları ve ayrıntılı kontroller [teknik başvuru rehberindedir](TECHNICAL-REFERENCE.md).
