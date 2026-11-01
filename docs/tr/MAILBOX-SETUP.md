# Posta hesabını hazırlayın

> [English](../MAILBOX-SETUP.md) | **Türkçe** · [Kurulum rehberi](WALKTHROUGH.md)

Posta hesabını siz yönetiyorsanız aşağıdakileri doğrulayın; başka bir ekip yönetiyorsa bu bilgileri onlardan isteyin. İlk deneme için ayrı bir test posta kutusu kullanın.

## Gerekli bilgiler ve izinler

- Gerçek IMAP sunucu adı, port ve bağlantı güvenliği.
- Kullanıcı adı, onaylı parola yöntemi ve o posta kutusuna IMAP erişim izni.
- İleti okuma ve taşıma izni; sunucuda **UID MOVE** desteği. COPY alternatifi desteklenmez.
- SAP'nin çalıştığı makineden posta sunucusuna ağ erişimi ve geçerli sertifika güveni.
- Okunacak klasör ile başarıyla işlenen iletilerin taşınacağı, ondan farklı hedef klasörün gerçek adları/yolları. Yalnız büyük/küçük harfle ayrılan adlar da kabul edilmez.

Okunacak klasör varsayılan olarak `INBOX`'tır. İşlenmiş iletiler için mevcut bir posta klasörü seçebilirsiniz; `SAP-Processed` adı zorunlu değildir. İki klasör de aynı posta hesabında bulunmalıdır.

## Bağlantı yöntemi

Doğru e-posta adresi ve parola yeterli olmayabilir. Hesabın IMAP erişimi açık olmalı ve sağlayıcınız projenin kullandığı kullanıcı adı/parola girişini kabul etmelidir. Yalnız OAuth isteyen hesaplar bu sürümle çalışmaz. İki adımlı doğrulamada uygulama parolasının kullanılabilirliği sağlayıcıya ve kurum politikasına bağlıdır; güvenlik ayarlarını kapatmayın.

Sağlayıcı paneli ve yetki ayrımları [kendi sistemini yönetenler rehberinde](SELF-MANAGED-SETUP.md#5-e-posta-ekibi-yoksa-hesabı-nasıl-hazırlarsınız), ayrıntılı koşullar [teknik başvuru rehberinde](TECHNICAL-REFERENCE.md#başlamadan-önce-posta-kutunuz-uygun-mu) açıklanır.

## Posta yöneticisine iletebileceğiniz talep

> SAP denemesi için ayrılmış posta hesabının IMAP bağlantı bilgilerini, desteklenen giriş yöntemini ve okunacak/hedef klasörlerin gerçek adlarını paylaşabilir misiniz? Hesabın okuma ve taşıma yetkisini, sunucunun UID MOVE desteğini ve SAP sunucusundan erişimi doğrulayalım. Parolayı onaylı gizli bilgi paylaşım yöntemiyle iletin.

## Son kontrol

`ZIMAP_CONFIG` içinde gerçek bilgileri kaydedip F8 ile bağlantı testini çalıştırın. Ayarın kaydedilmesi tek başına yeterli değildir; bağlantı testinin de başarılı olması gerekir. Bir adım başarısızsa hata metnini inceleyin. Parolaları destek kaydına veya ekran görüntüsüne eklemeyin.
