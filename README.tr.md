# SAP’de IMAP posta kutusundan mail ve ek okuma

> [English](README.md) | **Türkçe**

ABAP, PowerShell ve curl ile IMAP posta kutusundaki mail ve ekleri SAP’ye alın. PI/PO veya ayrı bir entegrasyon sunucusu gerekmez; betikler SAP uygulama sunucusunda çalışır.

**IMAP, parola/uygulama şifresi ve UID MOVE destekleyen sunucular içindir. Microsoft 365 / Exchange Online desteklenmez:** bu proje OAuth kullanmaz. Bu durum için ayrı bir Microsoft Graph projesi (abap-graph) hazırlanıyor. [Microsoft’un kimlik doğrulama açıklaması](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/deprecation-of-basic-authentication-exchange-online).

## Üç hazırlıkla başlayın

1. **Posta kutusu:** ayrı bir test hesabı, IMAP sunucusu/TLS portu ve birbirinden farklı kaynak/işlenen klasörleri.
2. **SAP sunucusu:** PowerShell, curl ve korumalı çalışma klasörleri. [Sunucu hazırlığını](docs/tr/SELF-MANAGED-SETUP.md) izleyin. Kendi bilgisayarınızın internete çıkması yeterli değildir.
3. **SAP:** [ZCHE_IMAP_INSTALL.abap](ZCHE_IMAP_INSTALL.abap) dosyasını SE38’e yapıştırın. Oluşturulan programlardan önce [yetki nesnesini ve rolleri](SECURITY.md) hazırlayın.

`ZCHE_IMAP_CONFIG` ile profil oluşturun; sertifika doğrulaması açık kalsın. Üretim için varsayılan, Basis’in yönettiği parola kaynağıdır (`O`). Önce `ZCHE_IMAP_INBOUND` ile yalnız listeleyin; ardından yapay bir maili demo handler ile işleyin. Gövde ve ekleri `ZCHE_IMAP_MONITOR` üzerinden inceleyin. Handler sonucu commit edildikten sonra mail taşınır; EXPUNGE kullanılmaz.

Ana kurulum yolu **tek installer’ı kopyala/yapıştır** yöntemidir. [abapGit](ABAPGIT.md) alternatif olarak installer kaynağını taşır; DDIC ve programları oluşturmak için installer çalıştırılır. Eski `ZIMAP_` kurulumları için kontrollü geçiş gerekir; eski nesne/veriler otomatik taşınmaz veya silinmez.

![Posta kutusundan SAP sunucusuna ve monitöre akış](docs/assets/diagrams/usage-tr.svg)

## Neden SAPconnect / SO50 değil?

| Yaklaşım | Kullanım alanı |
|---|---|
| SAPconnect / SO50 | SAP’ye SMTP ile yönlendirilen posta; relay/yönlendirme ve SAP SMTP uç noktası gerekir. |
| PI/PO veya Integration Suite mail adaptörü | Kurumda mevcut bir entegrasyon katmanı varsa yönetilen yol. |
| Google ABAP SDK | Google posta kutuları için Gmail API entegrasyonu. |
| Bu proje | SAP sunucusundaki küçük betiklerle, parola destekleyen IMAP kutusundan çekme. |

## Uyumluluk

| Bileşen | Hedef / kanıt |
|---|---|
| ABAP | Klasik 7.00 söz dizimi; Unicode ve sistem kod sayfasıyla metin okuma/yazma. |
| Windows | Windows PowerShell 5.1 veya PowerShell 7; curl 8.0.0+. |
| Linux | PowerShell 7.4+; curl 8.0.0+. |
| Posta sunucusu | TLS, UID MOVE ve parola/uygulama şifresi. |
| Doğrulama | Önceki `ZIMAP_` sürümü SAP A4H'de mailleri okudu ve ekleri açtı. 0.9.2 henüz SAP'de çalıştırılmadı; geri bildirime açık. [Doğrulama kaydı](VALIDATION.md). |

curl 7.55.1 kabul edilmez. İndirilen dosyanın boyutu UID için bildirilen RFC822.SIZE ile aynı olmalıdır; aynı boyut tek başına kimliği kanıtlamaz. GreenMail testlerinde ardışık olmayan UID’ler ve içerik kontrol edilir.

## Sık sorulan sorular

### SAP’de gelen maildeki ek nasıl okunur?
Demo handler başlık, gövde satırları ve ek bilgilerini alır. İkili dosya okuma yardımcısını kullanarak iş mantığınızı izinli `ZCHE_IMAP_HANDLER_*` programına ekleyin. [Handler sözleşmesini](docs/tr/TECHNICAL-GUIDE.md) izleyin; commit’i yalnız işlemci yapar.

### Microsoft 365 veya Gmail ile çalışır mı?
Microsoft 365 desteklenmez. Gmail, hesapta IMAP ve uygulama şifresine izin veriliyorsa kullanılabilir; yalnız OAuth kabul eden hesaplar desteklenmez.

### Hangi yetkiler gerekiyor?
Profil bazlı `ZCHE_IMAP`, `ZCHI` tablo grubu, sınırlı `S_LOG_COM` ve dosya yetkileri gerekir. [Rol ve parola kurulumu](SECURITY.md).

### Desteklenmeyen karakterler ve hatalı mailler ne olur?
SAP kod sayfasına sığmayan gösterim karakterleri `?` olur; özgün baytlar `mail.eml` içinde korunur. Başlıklar ve gösterim ek adları sınırlandırılır. Hatalı işlemler görünür kalır; varsayılan üç hata sınırı ve monitörden açıkça yeniden işleme vardır. Hatalı yerel önbellekler 30 gün sonra temizlenir; commit edilmiş bekleyen taşımalar korunur. [Kurtarma ayrıntıları](SECURITY.md).

[Adım adım rehber](docs/tr/WALKTHROUGH.md) · [Teknik başvuru](docs/tr/TECHNICAL-REFERENCE.md) · [Katkı](CONTRIBUTING.md) · [MIT lisansı](LICENSE)
