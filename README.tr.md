# abap-imap-inbound

> [English](README.md) | **Türkçe**

E-postayla gelen belgeleri SAP içinden toplamak ve işlem sonuçlarını takip etmek için açık kaynak bir proje.

![E-postayla gelen belgeleri toplama ihtiyacı, SAP içinden izleme ve hazır örnekle ilk deneme](docs/assets/business-need-tr.jpg)

## Ne işe yarar?

Tedarikçilerinizin faturaları veya sevkiyat belgelerini ortak bir e-posta adresine gönderdiğini düşünün. Bir kişi her iletiyi açıyor, ekleri indiriyor ve SAP'deki işleme hazırlıyor. Bu proje, e-postaların ve eklerinin alınmasını otomatikleştirmek için bir başlangıç sağlar.

- Belirlediğiniz posta kutusundaki iletileri ve ekleri alır.
- Hangi iletilerin başarıyla işlendiğini, hangilerinde hata olduğunu SAP'de gösterir.
- Başarıyla işlenen iletileri posta kutusunda ayrı bir klasöre taşır.

Hazır örnekle bu akışı deneyebilirsiniz. Fatura oluşturma, PDF içinden tutar okuma veya belgeyi bir siparişe bağlama gibi iş adımlarını kendi ihtiyacınıza göre ekleyebilirsiniz.

## Bu rehber kimler için?

Bu rehber, **SAP geliştiricileri ve en azından SE38 üzerinden program oluşturabilen, kaydedip etkinleştirebilen ve çalıştırabilen kişiler** içindir. Bu işlemler için SAP geliştirme yetkinizin olması gerekir. SAP programlarının kurulmasını, posta ayarlarını ve hazır örneğin çalıştırılmasını siz yapacaksınız.

Sunucu ve posta yönetimi yetkileri ayrı olabilir. Kendi sisteminizi yönetiyorsanız bu hazırlıkları da siz yapabilirsiniz; başka ekipler yönetiyorsa ilgili adımları onlardan isteyin.

| Hazırlık | Yetki sizdeyse | Başka ekip yönetiyorsa |
|---|---|---|
| SAP'nin çalıştığı makine | RDP/SSH ile bağlanıp gerekli araçları ve proje dosyalarını hazırlayın. | Basis veya sunucu yöneticisinden hazırlığı isteyin. |
| Posta hesabı | Sağlayıcı panelinden bağlantı bilgilerini ve erişim izinlerini kontrol edin. | E-posta yöneticisinden veya sağlayıcı desteğinden bilgileri alın. |

Sunucuya bağlantı ve posta hazırlığı [kendi sistemini yönetenler için rehberde](docs/tr/SELF-MANAGED-SETUP.md) anlatılıyor.

## Başlamadan önce ne bilmelisiniz?

İlk denemeyi bu iş için ayrılmış bir **deneme posta kutusunda** yapın. İşlem sırasında iletiler okundu işaretlenebilir ve başka klasöre taşınabilir.

**E-posta adresiniz ve doğru parolanız bağlantı için tek başına yeterli olmayabilir.** Hesabın IMAP erişimine, yani başka bir programın posta kutusunu okumasına izin verilmelidir. Outlook'a veya web postaya giriş yapabiliyor olmanız bu iznin bulunduğunu göstermez. Hesabı yönetiyorsanız sağlayıcının bağlantı koşullarını kontrol edin; başka bir ekip yönetiyorsa onlardan doğrulama alın. Bazı hesapların giriş koşulları mevcut sürümle uyumlu değildir; [ayrıntılı bağlantı koşulları](docs/tr/TECHNICAL-REFERENCE.md#başlamadan-önce-posta-kutunuz-uygun-mu) ayrı rehberdedir.

### E-postalar nereden okunur, nereye taşınır?

- **Okunacak klasör:** Varsayılan olarak **Gelen Kutusu (`INBOX`)** okunur. Yalnız belirli bir klasördeki e-postaların alınmasını istiyorsanız, ayarlarda o klasörün adını belirtebilirsiniz. Örneğin posta kutunuzdaki `Faturalar` klasörünü seçerseniz yalnız oradaki iletiler okunur.
- **İşlenmiş klasörü:** Başarıyla işlenen e-postaların taşınacağı posta klasörünü ayarlarda siz seçersiniz. Okunacak klasörden farklı, mevcut bir klasörünüzü kullanabilirsiniz. `SAP-Processed` yalnızca başlangıçta gösterilen örnek addır; bu adla yeni bir klasör açmanız gerekmez.

Her iki klasör de **aynı e-posta hesabının içinde** bulunur. SAP'de veya bilgisayarınızın diskinde klasör açmanız gerekmez.

## Nasıl başlayabilirsiniz?

1. **[Kurulum rehberini açıp dosyaları indirin](docs/tr/WALKTHROUGH.md).** Sunucu ve posta hazırlığını yetkileriniz doğrultusunda kendiniz yapın veya ilgili ekiplerden isteyin.
2. **SAP kurulumunu yapın.** SE38'de kurulum programını oluşturup etkinleştirin ve çalıştırın. Ardından posta kutusu ayarlarını kaydedip bağlantıyı test edin.
3. **Hazır örneği deneyin.** Küçük bir ek içeren deneme e-postası gönderin; SAP'deki sonucu, eki ve iletinin taşındığı klasörü kontrol edin.
4. **Kendi iş adımınızı ekleyin.** Örneğin gelen belgenin hangi siparişe bağlanacağını süreç sorumlusuyla belirleyip [geliştirici rehberindeki örneklerle](docs/tr/TECHNICAL-GUIDE.md) uygulayın.

## Daha fazla bilgi

| Aradığınız bilgi | Rehber |
|---|---|
| Kurulum ve ilk kullanım | [Adım adım rehber](docs/tr/WALKTHROUGH.md) |
| Ayrı Basis/e-posta ekibi olmadan kendi deneme sisteminizi hazırlamak | [Kendi sistemini yönetenler için rehber](docs/tr/SELF-MANAGED-SETUP.md) |
| Bağlantı koşulları, yetkiler, teknik sınırlar ve test durumu | [Teknik başvuru rehberi](docs/tr/TECHNICAL-REFERENCE.md) |
| Kendi iş adımınızı eklemek için kod örnekleri | [Geliştirici rehberi](docs/tr/TECHNICAL-GUIDE.md) |

**Güncel kaynak sürümü: 1.1.0.** Bu sürümün gerçek SAP sistemindeki kurulum ve çalışma testleri henüz tamamlanmadı. Önce deneme sisteminde değerlendirin; [nelerin test edildiğini](docs/tr/TECHNICAL-REFERENCE.md#neler-doğrulandı) teknik rehberde bulabilirsiniz.

## Lisans

[MIT](LICENSE) — lisans koşulları kapsamında kullanabilir, değiştirebilir ve paylaşabilirsiniz.
