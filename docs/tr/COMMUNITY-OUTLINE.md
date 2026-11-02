# SAP Community yazısı için çalışma iskeleti

> [English](../COMMUNITY-OUTLINE.md) | **Türkçe** · [Proje](../../README.tr.md)

Bu dosya yayımlanacak hazır metin değil, yazarın dolduracağı bir iskelettir. İhtiyacı, tasarım kararlarını ve gördüğünüz sonucu kendi cümlelerinizle anlatın; ayrıntılı kurulum için GitHub rehberine yönlendirin.

**Başlık önerisi:** Reading Emails and Attachments in SAP with ABAP and IMAP – Open Source, No PI/PO

## 1. Ne yapıyor?

- Projeyi neden geliştirdiğinizi ve nasıl kullandığınızı kendi deneyiminizle anlatın.
- Önce sonucu gösterin: mailleri okuma, ekleri alma ve bir ABAP iş adımına bağlama.
- Başarılı mailin kaynak klasörden seçilen hedef klasöre taşındığını söyleyin.
- [Kullanım diyagramı](../assets/diagrams/usage-en.svg) ve [gerçek mail ayrıntısı](../screenshots/monitor-detail.png) ile destekleyin.

## 2. Üç hazırlık alanı

- Posta hesabı: IMAP ve desteklenen parola/uygulama şifresiyle giriş; mevcut kaynak/hedef klasör; UID MOVE desteği.
- SAP uygulama sunucusu: PowerShell, curl, proje dosyaları, izinli sunucu listesi ve sertifika güveni.
- SAP: tek installer SAP nesnelerini oluşturur; CONFIG profili saklar, INBOUND işler, MONITOR sonucu gösterir.
- [Üç parçalı harita](../assets/diagrams/setup-en.svg) ve [v0.9.3 kurulum sonucu](../screenshots/install-complete.png) kullanın; ayrıntılı adımları [rehbere](WALKTHROUGH.md) bırakın.

## 3. Açıklanacak tasarım kararları

- **Neden bu yol?** Mevcut bir IMAP kutusunu okumayı SAPconnect'in gelen SMTP yönlendirmesiyle karşılaştırın; PI/PO veya başka entegrasyon çözümü olan ortamlardaki seçimi açıklayın.
- **Neden sunucu betikleri?** Klasik ABAP'ta hazır IMAP istemcisi bulunmamasını ve sabit SM69 komutlarıyla PowerShell/curl kullanma kararını anlatın.
- **Kurtarma:** iş adımı kaydedilmiş, taşıma bekleyen durumu açıklayın; handler'ın ayrıca iş anahtarıyla tekrar kontrolü yapması gerektiğini belirtin.
- **Güvenlik:** parolanın curl'e stdin ile verilmesi; `policy.psd1` izin listesi; sertifika doğrulaması; standart yetkiler ve isteğe bağlı profil bazlı `ZCHE_IMAP`; varsayılan üç hata sınırı.
- GreenMail denemesinde kendinden imzalı sertifika için doğrulama kapatıldı; gerçek posta hesabında sunucu üzerinde sertifika güveni hazırlanmalı.

## 4. Durum bölümüne girecek bilgiler

v0.9.3, **ABAP Cloud Developer Trial 2025, A4H/001, SAP_BASIS 816, S4FND 109, Linux (SLES), Unicode** üzerinde kuruldu ve çalıştırıldı. GreenMail 2.1.14 ile test mailleri listelendi, işlendi, başarılı mailler taşındı; monitörde gövde ile PDF/JPEG ekleri açıldı. Sunucuda PowerShell 7.4.6 ve curl 7.66.0 kullanıldı.

Kısıtlı kullanıcıyla arka plan işi, Windows SAP sunucusu, ECC 6.0 / SAP_BASIS 7.0x ve gerçek posta sağlayıcıları henüz denenmedi. Bunu kısa tutup geri bildirim isteyin. Bu deneme sisteminde S4CORE yok; tam S/4HANA sistemi olarak tanıtmayın.

[Doğrulama kaydı](../../VALIDATION.md) çalışma ve görsel bilgilerini içerir; List only görseli UID sonuç listesi değil, seçim ekranıdır.

## 5. Bağlantılar, görseller ve yayın alanları

- [Depo](https://github.com/Cheditte/abap-imap-inbound), [v0.9.3 release](https://github.com/Cheditte/abap-imap-inbound/releases/tag/v0.9.3), [İngilizce rehber](../WALKTHROUGH.md), [Türkçe rehber](WALKTHROUGH.md), [güvenlik](../../SECURITY.md).
- Görsel sırası: kullanım diyagramı → üç parçalı harita → kurulum sonucu → mail ayrıntısı; [bağlantı sonucu](../screenshots/config-test.png) isteğe bağlı.
- Community editörü için PNG: [kullanım](../assets/diagrams/usage-en.png), [üç parçalı harita](../assets/diagrams/setup-en.png).
- SAP Managed Tag: **ABAP Development**.
- Blog etiketleri: **GenAI Assisted Content**, **Learning**.
- Kullanıcı etiketleri: **IMAP**, **email attachments**, **ABAP**, **SM69**, **open source**.

Yayımlamadan önce yer tutucuları kaldırın, bağlantı/görsel açıklamalarını kontrol edin ve metni kendi deneyiminizle sonlandırın. Kodun tamamını, üretime hazır olduğu iddiasını, ECC'de çalıştığı iddiasını veya iş belgesinin asla iki kez oluşmayacağı garantisini kullanmayın.
