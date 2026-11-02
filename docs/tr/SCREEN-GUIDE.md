# Ekran rehberi — hangi alanı nasıl dolduracaksınız?

> [English](../SCREEN-GUIDE.md) | **Türkçe** · [Kullanım yolları](WALKTHROUGH.md) · [Proje özeti](../../README.tr.md)

Önce [kurulum ve ilk kullanım yolunu](WALKTHROUGH.md) izleyin. Bu dosyayı ekrandaki bir alanın ne işe yaradığını öğrenmek için açın. SAP sürümüne ve oturum diline göre menü adları değişebilir; proje alanlarının İngilizce adları aşağıda eşleştirilmiştir.

<a id="profil"></a>
## Posta ayarları — ZCHE_IMAP_CONFIG

**Profil**, hangi hesabın ve klasörlerin kullanılacağını saklayan ayar grubudur. Örnek profil adı `MAIL_DEMO`; zorunlu veya hazır oluşturulan bir profil değildir.

| Alan / grup | Ne işe yarar? | Nasıl doldurulur? |
|---|---|---|
| Profile | Bu ayar grubunun adı. | 1–20 karakter; A–Z, rakam ve alt çizgi. Sonraki ekranlarda aynı adı kullanın. |
| Description | Profili listede tanımanızı sağlar. | Örneğin “Deneme posta kutusu”; gerçek hesap/parola yazmayın. |
| Active | Profilin işlemeye dahil edilmesini sağlar. | İlk denemede işaretli. Kapatmak geçmişi silmez. |
| Server | Bağlanılacak posta sunucusu. | Posta yöneticisinin verdiği gerçek IMAP adı; e-posta adresiniz veya SAP sunucusu değil. |
| Port | Posta hizmetinin bağlantı noktası. | `993` yaygın IMAPS örneğidir; verilen gerçek portu kullanın. |
| Security | Bağlantının şifreleme yöntemi. | Verilen porta uygun `IMAPS` veya `STARTTLS`. Şifrelenmemiş bağlantıyı ilk çözüm olarak seçmeyin. |
| Verify certificate | Doğru, güvenilir sunucuyla bağlantıyı kontrol eder. | **İşaretli kalsın.** Hata varsa sunucu adı/sertifika güveni düzeltilir. |
| User | Posta hesabının giriş adı. | Yöneticinin verdiği kullanıcı; her zaman e-posta adresiyle aynı olmayabilir. |
| Password source | Parolanın nereden sağlanacağı. | Varsayılan `O`: yönetici sunucuda hazırlar. SAP ekranından girmek için `S` yazıp Enter'a basın; parola alanı görünür. |
| Password | `S` için yeni parola girişi. | `O` seçiliyken boş/pasif kalır. Kayıtlı parola geri okunmaz; değeri görüntülere veya varyanta koymayın. |
| Folder to read | Okunacak posta klasörü. | Varsayılan `INBOX`. Başka klasör istiyorsanız onun gerçek IMAP adını yazın. |
| Processed folder | Başarılı iletilerin taşınacağı yer. | Aynı hesapta **farklı, mevcut klasör**. `SAP-Processed` yalnız başlangıç örneği. |
| Move method | Başarılı mail için yapılacak işlem. | `MOVE`. Sunucunun UID MOVE desteği olmalı; COPY desteklenmez. |
| Handler program | Her mail için çalışan ABAP iş programı. | İlk denemede `ZCHE_IMAP_HANDLER_DEMO`. Özel kod için [geliştirici rehberi](TECHNICAL-GUIDE.md). |
| Handler FORM | İş programının çağrılan giriş noktası. | Demo için `HANDLE_MAIL`. |
| Mails per run | Bir çalıştırmada işlenecek üst sınır. | Başlangıç değeri `50`; küçük bir deneme kutusuyla başlayın. |
| Max mail size (MB) | Bir iletinin boyut sınırı. | Başlangıç `20` MiB; sunucu politikası daha düşük sınır koyabilir. |
| Timeout | Ağ çağrısının bekleme sınırı. | Başlangıç `120` saniye. Bütün job'ın süresi değildir. |
| Retention | Tamamlanmış yerel mail arşivlerinin saklanma süresi. | Başlangıç `30` gün. SAP loglarını veya posta kutusundaki hedef klasörü silmez. |

Klasör adları İngilizce harf, rakam ve `. _ / -` karakterlerini kabul eder; boşluk/Türkçe karakter desteklenmez. Ekranda görünen çevrilmiş Outlook adı yerine gerçek IMAP adını kullanın.

### Düğmeler

- **Load profile:** kayıtlı profili ekrana getirir. Parolayı göstermez.
- **Save:** alanları doğrulayıp ayarları kaydeder. Kaydetmek, bağlantının çalıştığını tek başına kanıtlamaz.
- **F8:** önce kaydeder, sonra bağlantıyı kontrol eder.
- **Profiles:** kayıtlı profil seçmeye yarar.
- **Delete:** profili silme işlemidir; deneme veya tekrar işleme düğmesi değildir. Mail geçmişi olan profiller silinmez; pasifleştirilir.

Parolalar şifreli kasa yerine erişim izinleriyle korunan düz metin dosyalarındadır. [Parola kaynağı ve dosya izinleri](../../SECURITY.md).

<a id="isleme"></a>
## Listeleme ve işleme — ZCHE_IMAP_INBOUND

| Alan | Karar |
|---|---|
| Profile seçimi | Yalnız kendi deneme profilinizi girin. Boş seçim bütün aktif profilleri kapsar. |
| List only (no downloads/changes) | **İşaretli:** yalnız uygun ileti numaraları listelenir. **İşaretsiz:** içerik indirilir, handler çalışır ve başarılı mail taşınır. Başlangıçta işaretli olduğunu varsaymayın. |
| Retry failed mails | İlk çalışmada boş bırakın. Daha önce `E` olanları, hata giderildikten sonra bilinçli yeniden denemeye dahil eder; varsayılan üç hata sınırına tabidir. |

**List only, mail gövdesinin ön izlemesi değildir.** İçeriği görmek için ayrı deneme mailiyle [normal işleme yolunu](WALKTHROUGH.md#ilk-mail) tamamlayın.

<a id="monitor"></a>
## Sonucu görme — ZCHE_IMAP_MONITOR

| Alan / işlem | Ne yapmalısınız? |
|---|---|
| Profile | Çalıştırdığınız profili seçin. |
| Status | İlk kontrolde boş bırakarak bütün durumları görün. |
| Date | Çalıştırma gününü kapsasın. Başlangıçta son 30 gün seçilir. |
| Display limit | En fazla `1000` satır. Eski maili bulmak için profil/tarih seçimini daraltın. |
| Mail satırına çift tıklama | Başlık, gövde ve ek bilgilerini açar. |
| Ek satırına çift tıklama | Dosyayı bilgisayarınıza indirir; izinli PDF/metin/görsel türleri uygun görüntüleyicide açılabilir. |
| Original mail | Özgün `mail.eml` dosyasını indirir; otomatik açmaz. |

Gösterim için dönüştürülen metin, SAP kod sayfasında bulunmayan karakterleri `?` gösterebilir. Özgün EML baytları korunur. Yerel dosyalar saklama süresi nedeniyle silinmişse log kaydı hâlâ görünebilir.

<a id="hatalar"></a>
## Hata olduğunda hangi yolu izlemelisiniz?

| Gördüğünüz durum | Sonraki adım |
|---|---|
| Oturum açma hatası | Giriş adı, giriş yöntemi ve IMAP iznini posta yöneticisiyle kontrol edin. Parolayı destek mesajına yazmayın. |
| Bağlantı/sertifika hatası | SAP sunucusundan erişimi, gerçek host adını ve sertifika güvenini kontrol edin; doğrulamayı kapatmayın. |
| Yetki / SXPG1 | [Rol tablosunu](../../SECURITY.md) kontrol edin. Örneğin bağlantı kontrolü `S_LOG_COM → ZCHE_IMAP_TEST` gerektirir. |
| `E` — Error | Kayıttaki hatayı giderin; sonra izinli retry yolunu seçin. |
| `H` — To move | İş sonucu kaydedilmiş. Normal çalıştırma yalnız taşımayı dener; handler'ı tekrar çağırarak çözmeye çalışmayın. |
| `R` — Retry | Yetkili kullanıcı yeniden işleme istedi. Sonraki normal çalıştırma yeniden deneyebilir. |

Monitördeki **Reprocess**, `E` kaydını `R` yapar ve deneme sınırı aşılmış olsa bile yeni denemeye izin verir. İş kodunuzun belgeyi ikinci kez oluşturmamasını kontrol edin. Hazır demo, konuda `TEST-ERROR` varsa bilerek başarısız olur; yalnız retry seçmek bu kuralı değiştirmez.

<a id="job"></a>
## Varyant ve job — SM36 / SM37

Varyantta profil, List only ve retry seçimleri saklanır. İlk job için **List only işaretli** varyant kullanın. Günlük normal işleme için ayrı varyantta işareti kaldırın.

SM36'da **Job Name** işin adı, **Target** kurulum yapılan SAP sunucusu, **Step** program/varyant/kullanıcı, **Start condition** zamanlama seçimidir. SM37'de kendi işinizi bulup **Job log** ve **Spool** okuyun. Finished tek başına başarılı mail işleme kanıtı değildir.

[Adım adım job yolu](WALKTHROUGH.md#otomatik).
