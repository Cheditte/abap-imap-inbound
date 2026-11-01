# Posta kutusu kurulumu (mail ekibi için)
> [English](../MAILBOX-SETUP.md) | **Türkçe**

abap-imap-inbound bir ya da birden fazla posta kutusunu IMAP ile okur ve işlediği her maili ayrı bir klasöre taşır. Bunun için IMAP erişimi açık, sıradan bir mail hesabı yeterlidir. Bu sayfa, mail ekibinden ne isteneceğini ve yaygın sunucularda bunun nasıl kurulacağını anlatır.

## 1. Nasıl bir hesap

Sade bir dille: **gelen mailleri SAP'nin okuyup işlemesini istediğiniz mail hesabı.** Tedarikçiler faturalarını `invoices@example.com` adresine gönderiyorsa, burada kurulacak hesap odur. Bir kişinin posta kutusunu değil, **süreç için ayrılmış bir posta kutusu** kullanın. Örneğin tedarikçi faturaları için `invoices@example.com`, sipariş onayları için `orders@example.com`. Bir posta kutusu `ZIMAP_CONFIG` içinde bir profil olur; her profil kendi iş mantığını çalıştırabilir.

Neden ayrılmış bir hesap:
- SAP, okuduğu klasördeki **her** maili işler. Kişisel mailler de oraya düşerdi.
- Şifre bir kişiye değil sürece aittir; kişi işten ayrılabilir.
- İzinler ve saklama süresi tam olarak bu amaca göre ayarlanabilir.

Göndericiler adrese doğrudan yazabilir; ya da mail sunucusundaki bir yönlendirme / transport kuralı belirli mailleri bu hesaba kopyalayabilir.

## 2. Hesabın ihtiyaçları

| İhtiyaç | Ayrıntı |
|---|---|
| **IMAP açık** | TLS üzerinden: 993 portunda IMAPS (tercih edilen) ya da 143 portunda STARTTLS. |
| **Kullanıcı adı ve şifreyle giriş** | Bu sürüm OAuth'u desteklemez. Kullanıcı adı genelde mail adresi ya da sunucunun beklediği giriş adıdır. |
| **ASCII şifre** | Harf, rakam ve yaygın semboller. ASCII dışı karakterler (örneğin `ş`, `ä`) IMAP `LOGIN` komutunda standart değildir ve girişin başarısız olmasına yol açabilir. |
| **Şifre politikası** | Ya süresiz geçerli olmalı ya da süresi dolmadan önce `ZIMAP_CONFIG` içinde güncellenmesi için kararlaştırılmış bir düzen olmalı. Süresi dolan şifre, işlemeyi `AUTH` hatasıyla durdurur. |
| **İki klasör** | Okunacak klasör (genelde `INBOX`) ve işlenenler klasörü (varsayılan adı `SAP-Processed`). **İşlenenler klasörünü** posta kutusunda oluşturun; bağlantı testi bu klasörün var olup olmadığına bakar. |
| **Haklar** | Mail okuma, bayrak (flag) koyma, maili işlenenler klasörüne taşıma ya da kopyalama, gelen kutusundan silme. Normal bir sahip girişi bunların hepsine sahiptir. |
| **Boyut sınırı** | Beklediğiniz en büyük eki düşünün. Profillerin kendi azami mail boyutu da vardır (varsayılan 20 MB). |

Ağ tarafında: SAP'nin kurulu olduğu makine (SAP uygulama sunucusu) mail sunucusuna IMAP portundan erişebilmeli ve sunucunun sertifikasına güvenmeli (bkz. [SERVER-SETUP.md](SERVER-SETUP.md#4-policypsd1-sınırlarınız), `CaCert`).

## 3. Talep şablonu

Bunu mail ekibine gönderebilirsiniz:

> SAP'de otomatik işlenmek üzere bir posta kutusuna ihtiyacımız var.
>
> - Adres: `invoices@example.com` (ortak / işlevsel posta kutusu, kişisel değil)
> - Erişim: TLS üzerinden IMAP (IMAPS 993 ya da STARTTLS 143), kullanıcı adı ve şifreyle giriş
> - Şifre: yalnızca ASCII karakterler; süresiz geçerli olsun ya da son kullanma tarihini önceden bildirin
> - Klasörler: `INBOX` ve yeni bir `SAP-Processed` klasörü
> - Erişim kaynağı: SAP'nin kurulu olduğu makine(ler) `<sunucu adları / IP adresleri>`
> - Lütfen bize bildirin: sunucu adı, port, giriş adı biçimi ve sunucu sertifikasını hangi CA'nın imzaladığı
>
> SAP birkaç dakikada bir yeni mailleri okur, işler ve `SAP-Processed` klasörüne taşır. Bu posta kutusundan hiçbir şey gönderilmez.

## 4. Yaygın sunucular için notlar

Bunlar genel ipuçlarıdır; kendi sunucunuzun dokümanıyla karşılaştırarak kontrol edin.

**Microsoft Exchange Server (şirket içi, on-premise)**
- IMAP4 servisleri varsayılan olarak başlatılmaz. *Microsoft Exchange IMAP4* ve *Microsoft Exchange IMAP4 Backend* servislerini başlatın ve otomatik olarak ayarlayın.
- Posta kutusu için IMAP'e izin verilmelidir, örneğin `Set-CASMailbox invoices -ImapEnabled $true`.
- IMAP sertifikasını ve giriş türünü (TLS üzerinden düz metin) `Set-ImapSettings` ile yapılandırın.
- Sunucu IMAP `MOVE` komutunu desteklemiyorsa profilde **Move method = COPY** seçin (önce kopyala, sonra sil). Gerçek Exchange sunucuları henüz denenmedi.

**Microsoft 365 / Exchange Online**
- IMAP için şifreyle giriş Microsoft tarafından kapatılmıştır; yalnızca OAuth çalışır. Bu sürüm **OAuth'u desteklemez**, bu yüzden Microsoft 365 posta kutularını okuyamaz. Onlar için Microsoft Graph kullanın.

**Gmail / Google Workspace**
- Google, IMAP için OAuth ya da uygulamaya özel şifre ister. Bu projeyle denenmedi; Gmail API daha uygun bir yoldur.

**Dovecot, Zimbra, hosting firmaları ve diğer IMAP sunucuları**
- Genelde normal bir mail hesabıyla çalışır: TLS üzerinden IMAP, kullanıcı adı ve şifre. Bu projenin test ortamı GreenMail kullanır.

## 5. Kontrol

Hesap hazır olduğunda SAP yöneticisi onu `ZIMAP_CONFIG` içine girer ve F8'e basar. Başarılı bir test şöyle görünür:

```
OK  PROFILE    mail.example.com:993 IMAPS user invoices@example.com
OK  DNS        10.0.0.25
OK  PORT       993
OK  LOGIN
OK  INBOX      INBOX: 3 mails
OK  PROCESSED  SAP-Processed
Connection successful. Profile is ready to use.
```

Bir adım başarısız olursa ekran nedenini ve sonraki adımı gösterir (örneğin yanlış şifre, eksik klasör, güvenilmeyen sertifika).
