# abap-imap-inbound: baştan sona tasarım
> [English](../DESIGN.md) | **Türkçe**

> **Arka plan belgesi:** Aşağıdaki ayrıntılı örnekler 1.0 davranışını anlatabilir. 1.1.0 kurulumu, dosya kimliği ve handler işlem kuralları için güncel [kurulum rehberini](WALKTHROUGH.md) ve [geliştirici rehberini](TECHNICAL-GUIDE.md) kullanın.

Bu belge, kurulumdan kaldırmaya kadar tüm yaşam döngüsünü anlatır. Gerçekten nelerin test edildiği [README](../../README.tr.md) içinde listelenir.

**Arka plan.** Bu proje mevcut IMAP posta kutusunu düzenli kontrol eder. IMAP ve MIME işini SAP uygulama sunucusunun işletim sistemine denetimli bir SM69 komutuyla yaptırır; ayarlar, iş mantığı ve izleme SAP'de kalır. SAPconnect'in yerleşik SMTP gelen posta yolu ve diğer entegrasyon yöntemleri farklı ihtiyaçlara yöneliktir; posta düzeni ve sistem yapısına göre seçim yapılmalıdır. Düz dille anlatımı [README](../../README.tr.md) içindedir.

Her kararın önünde iki ilke durur:

1. **Kullanımı kolay olmalı.** Her rol işini tek bir yerde, mümkün olan en az adımla yapar. Hata mesajları ne yapılacağını söyler.
2. **Her sürümde çalışmalı.** ABAP 4.6C sözdizimi, en fazla 72 karakterlik satırlar, yalnızca ASCII. Sürüme bağlı her şey çalışma zamanında kontrol edilir.

---

## 1. Roller

| Rol | Ne yapar | Nerede | Emek |
|---|---|---|---|
| **Basis** | Betiği sunucuya kopyalar, kurulum betiğini çalıştırır, hangi mail sunucularına izin verileceğine karar verir | Sunucu: `setup-server.ps1` (Windows) / `setup-server.sh` (Linux) | ~10 dk, bir kez |
| **Geliştirici** | `ZIMAP_INSTALL`'u çalıştırır; iş mantığını (handler) yazar | SE38 | Kurulum ~2 dk; handler işe göre değişir |
| **Yönetici** (BT / fonksiyonel) | Posta kutusu profillerini tanımlar, şifreleri girer, bağlantıyı test eder, profilleri açar ya da kapatır | `ZIMAP_CONFIG` | Profil başına ~3 dk |
| **Operasyon** | İşlenen ve hata alan mailleri izler, hata alanları yeniden işletir | `ZIMAP_MONITOR` | Günlük kontrol |
| **Denetçi** | Kimin neyi ne zaman değiştirdiğini görür | `ZIMAP_PROFILE` değişiklik alanları, `ZIMAP_LOG` | — |

---

## 2. Mimari

```
                 SAP                                      Application server (Windows / Linux)
┌───────────────────────────────────┐          ┌──────────────────────────────────────────┐
│ ZIMAP_CONFIG  profile + password ─┼─writes─▶ │ conf/<PROFILE>.conf    (settings)        │
│                                   │          │ secret/<PROFILE>.cred  (user/password)   │
│ ZIMAP_INBOUND (job)               │          │                                          │
│   SM69: ZIMAP_LIST  <PROFILE>     │─SXPG───▶ │ bin/imap.ps1  ── curl ──▶ IMAP server    │
│         ZIMAP_FETCH <PROFILE> <UID>          │ bin/policy.psd1 (Basis: allowed servers) │
│         ZIMAP_DONE  <PROFILE> <UID>          │                                          │
│   reads files ◀───────────────────┼──────────│ in/<PROFILE>/<UID>/  header body att ... │
│   PERFORM handler IN PROGRAM      │          │ done/<PROFILE>/...   log/                │
│   ZIMAP_LOG                       │          └──────────────────────────────────────────┘
│ ZIMAP_MONITOR  monitor / reprocess│
└───────────────────────────────────┘
```

**Neden bu bölünme:**
- MIME çözümleme işletim sistemi tarafında yapılır, çünkü eski ABAP sürümlerinde bunun için araçlar yoktur.
- Ayarlar SAP'dedir; yönetici bunları Basis'e gitmeden değiştirir.
- Güvenlik sınırını Basis çizer: SAP hangi sunuculara bağlanacağına tek başına karar veremez.

---

## 3. Sunucu tarafı

### 3.1 Klasörler ve izinler
| Klasör | İçerik | SAP servis hesabı |
|---|---|---|
| `bin` | `imap.ps1`, `policy.psd1` | okuma + çalıştırma (değiştiremez) |
| `conf` | profil ayarları (SAP yazar) | değiştirme |
| `secret` | profil kimlik bilgileri (SAP yazar) | değiştirme; Windows'ta diğer kullanıcılar okuyamaz |
| `in`, `done`, `tmp`, `log` | çalışma dosyaları | değiştirme |

`setup-server.ps1` / `setup-server.sh` bu klasörleri oluşturur, izinleri ayarlar, curl'ü kontrol eder ve `policy.psd1` dosyasını yazar. Basis'in `icacls` komutlarını elle yazması gerekmez.

### 3.2 `policy.psd1`: Basis sınırı
```powershell
@{
    AllowedHosts     = @('mail.example.com')   # only these servers can be reached
    AllowInsecure    = $false                  # certificate checks cannot be turned off
    AllowPlainImap   = $false                  # no unencrypted IMAP on 143
    MaxMailBytes     = 52428800                # profiles cannot exceed this
    RetentionDaysMax = 365
}
```
SAP'deki bir profil bu sınırların ötesine geçemez. Denerse betik `ERR POLICY ...` döndürür ve yapılandırma ekranı okunabilir bir mesaj gösterir.

### 3.3 Betik protokolü
| Komut | Parametreler | Çıktı |
|---|---|---|
| `list` | `<PROFILE>` | `UIDVALIDITY n`, `UID n`..., `OK` |
| `fetch` | `<PROFILE> <UID>` | `OK` (dosyalar `in/<PROFILE>/<UID>/` içinde) |
| `done` | `<PROFILE> <UID> <UIDVALIDITY>` | `OK` |
| `test` | `<PROFILE>` | adım adım tanı (DNS, port, TLS, giriş, klasörler), `OK` |

- Profil adları `^[A-Z0-9_]{1,20}$`, UID'ler `^\d{1,10}$` desenine uymalıdır; başka her şey reddedilir.
- Şifre hiçbir zaman curl'ün komut satırında bulunmaz; betik onu curl'ün standart girdisinden (stdin) verir. Süreç listesinde görünmez.
- Ayar ve kimlik dosyaları yalnızca `KEY=VALUE` olarak okunur; curl'e hiçbir zaman seçenek olarak verilmez. Bir dosyaya yazılan değer, curl'e fazladan bir seçenek enjekte edemez.
- Hata kodları sabittir ve belgelidir: `ARG`, `CFG`, `POLICY`, `CONNECT`, `TLS`, `AUTH`, `MAILBOX`, `NOMAIL`, `SIZE`, `EXC`. SAP tarafı bunları ipucuyla birlikte okunabilir metne çevirir.

---

## 4. SAP tarafı

### 4.1 DDIC (hepsi `ZIMAP_INSTALL` tarafından oluşturulur)
| Nesne | Tür | Amaç |
|---|---|---|
| `ZIMAP_PARAM` | tablo | kurulum ayarları (sunucu ana klasörü, dosya kod sayfası) |
| `ZIMAP_PROFILE` | tablo | posta kutusu profilleri |
| `ZIMAP_LOG` | tablo | mail başına durum (anahtar: client, profil, UIDVALIDITY, UID) |
| `ZIMAP_S_MAIL`, `ZIMAP_S_ATT`, `ZIMAP_S_LINE` | yapılar | handler arayüzü (DDIC'te durur, böylece başka programlar da kullanabilir) |
| `ZIMAP_*` | domain / veri elemanları | yalnızca kendi tipleri; tek istisna `MANDT` |

**`ZIMAP_PROFILE` alanları:**
- **Kimlik:** profil kimliği, açıklama, etkin bayrağı
- **Bağlantı:** sunucu, port, güvenlik (`IMAPS` / `STARTTLS` / `NONE`), sertifika kontrolü
- **Kimlik bilgileri:** kullanıcı adı; şifre kaynağı (`S` = SAP'de girilir, `O` = Basis tarafından sunucuda tutulur); son şifre değişikliğinin tarihi ve kullanıcısı. **Şifrenin kendisi tabloda yoktur.**
- **Posta kutusu:** gelen kutusu klasörü, işlenenler klasörü, taşıma yöntemi (`MOVE` / `COPY+DELETE`)
- **İşleme:** handler programı ve form'u, çalıştırma başına en fazla mail sayısı, en büyük mail boyutu, zaman aşımı, saklama süresi
- **Değişiklikler:** kim ne zaman oluşturdu / değiştirdi (denetim için)

### 4.2 Programlar
| Program | Ne yapar |
|---|---|
| `ZIMAP_INSTALL` | Her şeyi kuran ve güncelleyen tek program. Bir sürüm numarası taşır; yeniden çalıştırılırsa tablolara eksik alanları ekler. Programların üzerine yalnızca "overwrite" seçiliyse yazar. |
| `ZIMAP_CONFIG` | Profil bakımı: yükleme, kaydetme, silme, listeleme. **Şifre** (yazarken gizli; tabloya değil, sunucudaki dosyaya yazılır). Adım adım sonuç ve ipucu veren **bağlantı testi**. |
| `ZIMAP_INBOUND` | İşleyici program; job olarak çalışır. Tek bir profil ya da tüm etkin profiller. Test modu. Bir mail iki kez işlenmez (durum `H` → `S`). |
| `ZIMAP_MONITOR` | Log kayıtlarını profile, duruma ve tarihe göre listeler. Mail ayrıntılarını (başlıklar, gövde, ekler) gösterir ve ekleri bilgisayarda açar. Hata alan mailleri yeniden işlemeye gönderir. |
| `ZIMAP_HANDLER_DEMO` | Örnek handler (subroutine pool). Yeni handler'lar bundan kopyalanır. |

### 4.3 Handler arayüzü
Her profil kendi handler'ını belirtir; işleyici program onu `PERFORM (form) IN PROGRAM (prog)` ile çağırır:
```abap
FORM handle_mail USING    is_mail TYPE zimap_s_mail
                          it_body TYPE STANDARD TABLE   " ZIMAP_S_LINE
                          it_att  TYPE STANDARD TABLE   " ZIMAP_S_ATT
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
```
- Handler `COMMIT WORK` yapmaz. İşleyici program başarıda commit eder, hatada rollback yapar.
- Yardımcı bir form, ekleri ikili (binary) veri olarak okur.

### 4.4 Yetkiler
| Rol | Nesne | Değer |
|---|---|---|
| İşleyici (job kullanıcısı) | `S_LOG_COM` | `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE` |
| İşleyici (job kullanıcısı) | `S_DATASET` | `ZIMAP_INBOUND`, okuma, `…/in/*` |
| Yönetici | `S_DATASET` | `ZIMAP_CONFIG`, **yalnızca yazma**, `…/conf/*`, `…/secret/*` |
| Yönetici | `S_LOG_COM` | `ZIMAP_TEST` (bağlantı testi) |
| Yönetici | `S_TABU_DIS` / program yetki grubu | `ZIMAP_PROFILE` bakımı |

Yönetici şifreyi yazabilir ama SAP'den geri okuyamaz.

---

## 5. Kullanıcı senaryoları

### 5.1 İlk kurulum (yaklaşık 15 dakika)
1. **Basis:** sürümü sunucuda açar ve `setup-server.ps1 -AllowedHosts mail.example.com` komutunu çalıştırır. Betik klasörleri, izinleri ve politika dosyasını hazırlar, curl'ü kontrol eder.
2. **Geliştirici:** SE38'de `ZIMAP_INSTALL`'u oluşturur, yapıştırır, F8. Program DDIC nesnelerini, programları ve SM69 komutlarını kurar, sonra kendini sınar.
3. **Yönetici:** `ZIMAP_CONFIG`: sunucu, kullanıcı, klasörler ve şifreyi girer, F8 → bağlantı testi geçer.
4. **Basis / geliştirici:** `ZIMAP_INBOUND`'u SM36'da periyodik job olarak planlar.

### 5.2 Şifre değişti
Yönetici → `ZIMAP_CONFIG` → profil → yeni şifre → F8. Basis gerekmez.

### 5.3 Yeni posta kutusu
Yönetici → var olan bir profili yükler, yeni bir adla kaydeder, sunucuyu, kullanıcıyı, klasörü ve handler'ı değiştirir → test.

### 5.4 Bir mail hata aldı
1. Operasyon `ZIMAP_MONITOR`'da kırmızı satırı görür ve maili açar.
2. Hata metni ne yapılacağını söyler, örneğin *"Handler error: vendor not found (4500012345)"*.
3. Nedeni düzeltir ve **reprocess** (yeniden işle) seçeneğini seçer.

### 5.5 Güncelleme
- Yeni `ZIMAP_INSTALL`'u "overwrite" ile çalıştırın.
- Tablolara yalnızca eksik alanlar eklenir; veri korunur.
- Basis, `bin` içindeki betiği yeni sürümle değiştirir.
- İkisi de aynı sürüm numarasını taşır; bağlantı testi uyuşmazlığı bildirir.

### 5.6 Kaldırma
`ZIMAP_INSTALL` → kaldırma seçeneği, kendi oluşturduğu nesneleri siler. Sunucu klasörlerini Basis siler.

---

## 6. Hata mesajları: teknik koddan sonraki adıma

| Kod | Anlamı | Sonraki adım |
|---|---|---|
| `AUTH` (curl 67) | Kullanıcı adı ya da şifre yanlış | `ZIMAP_CONFIG` → şifreyi girin |
| `CONNECT` (curl 6/7/28) | Mail sunucusuna ulaşılamıyor | Sunucu adı/port; firewall (Basis) |
| `TLS` (curl 35/60) | Sertifika doğrulanamadı | Şirket CA'sını sunucuya kurun (Basis) |
| `POLICY` | Bu sunucuya bağlanmaya izin yok | Basis: `policy.psd1` → `AllowedHosts` |
| `MAILBOX` | Klasör bulunamadı | Profildeki klasör adlarını kontrol edin |
| `CFG` | Profil dosyası yok ya da bozuk | `ZIMAP_CONFIG` → profili kaydedin |
| SXPG kodu 2 | SM69 komutu bulunamadı | `ZIMAP_INSTALL`'u yeniden çalıştırın |
| SXPG kodu 1 | Yetki yok (`S_LOG_COM`) | Rol yetkileri |

---

## 7. Güvenlik özeti
- **Şifre SAP veritabanında saklanmaz.** Sunucuda, yalnızca SAP servis hesabının okuyabildiği bir dosyadadır. SAP'den geri okunamaz.
- **Ulaşılabilir sunucular Basis'in listesiyle sınırlıdır.** SAP yetkileri, verinin rastgele sunuculara gönderilmesi için kullanılamaz.
- **Betikler SAP servis hesabı tarafından değiştirilemez.**
- **Gelen her değer doğrulanır.** SAP'de yazılan hiçbir değer curl'e seçenek olarak ulaşmaz.
- **Mail içeriği güvenilmeyen veridir.** Ekler hiçbir zaman çalıştırılmaz. Boyut ve sayı sınırları uygulanır.
- **Kişisel verinin saklama süresi** profil başına ayarlanır (KVKK, GDPR ve benzeri düzenlemeler).

---

## 8. Uyumluluk

| Konu | Yaklaşım |
|---|---|
| ABAP 4.6C – 7.5x | Eski sözdizimi, 72 sütun, ASCII; yeni özellikler çalışma zamanında kontrol edilir |
| Unicode / Unicode olmayan | Kurulum programı bunu tespit eder ve uygun dosya okuma include'unu kurar |
| Windows / Linux | Aynı betik: Windows PowerShell 5.1 ya da PowerShell 7 |
| Eksik SAP fonksiyon modülü | Kurulum programı durmaz; elle yapılacak adımı açıklar |

---

## 9. Test stratejisi
| Katman | Nasıl | Durum |
|---|---|---|
| Çözümleyici (parser) | `test/run-tests.ps1` (Windows 5.1 + Linux 7) | tamam |
| IMAP akışı, politika ve doğrulama | GreenMail'e karşı `test/run-imap-tests.ps1`: izin verilmeyen sunucu, hatalı profil adı, seçenek enjeksiyonu, yanlış şifre, eksik klasör | tamam |
| ABAP sözdizimi | Deneme sisteminde ADT kontrolü | tamam |
| SAP ile uçtan uca | Deneme sistemi: kurulum, profil, bağlantı testi, job, izleme, ekler | tamam (Linux, Unicode) |
| Eski sürümler | Gerçek bir 4.6C / 6.x / 7.0 sistemi | **doğrulanmadı**; topluluktan geri bildirim beklenir |
