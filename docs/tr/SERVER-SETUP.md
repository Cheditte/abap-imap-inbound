# Sunucu hazırlığı

> [English](../SERVER-SETUP.md) | **Türkçe** · [Kurulum rehberi](WALKTHROUGH.md)

Sunucu hazırlığı SAP'nin çalıştığı Windows/Linux makinede yapılır. Bunu sunucu yöneticisi veya gerekli yönetim yetkisi sizdeyse siz yapabilirsiniz.

1. PowerShell ve şifreli IMAP destekli curl bulunduğunu kontrol edin.
2. Aynı sürümdeki `server` ve `script` klasörlerini birlikte aktarın.
3. Korumalı çalışma klasörünü ve SAP servis hesabının izinlerini kurulum scriptiyle hazırlayın.
4. Sunucu testini çalıştırın; SAP'de kullanılacak sunucu ve klasör yolunu kaydedin.

Komutlar ve kontroller [güncel sunucu kurulum bölümünde](TECHNICAL-REFERENCE.md#sunucu-kurulumu-komutlar-ve-kontroller) bulunur. RDP/SSH ile kendiniz bağlanacaksanız [kendi sistemini yönetenler rehberini](SELF-MANAGED-SETUP.md) izleyin.

Profil dosyaları SID, mandant ve profil adına göre ayrılır. Kurulum, ayar, işleme ve izleme aynı uygulama sunucusuna bağlıdır. Parola dosyaları işletim sistemi izinleriyle korunur; SAP hesabı ve ayrıcalıklı yöneticiler erişebilir.

Önceki 1.0 kurulum örneklerinin yerini bağlantı verilen güncel komutlar alır.
