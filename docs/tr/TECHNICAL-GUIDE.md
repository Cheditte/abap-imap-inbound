# Geliştirici rehberi: kendi ABAP iş mantığınızı bağlayın

> [English](../TECHNICAL-GUIDE.md) | **Türkçe** · [README](../../README.tr.md) · [Kurulum rehberi](WALKTHROUGH.md)

Hazır örnekle posta akışını doğruladıktan sonra kendi iş mantığınızı bu rehberdeki arayüzle ekleyebilirsiniz. SE38 üzerinden program oluşturup etkinleştirebildiğiniz ve ABAP geliştirme yetkinizin olduğu varsayılır. Kurulum ve ilk deneme adımları kurulum rehberindedir.

Mevcut bağlantı noktası dışarıya açılmış bir sınıf değil, **`FORM` içeren handler programıdır**. Aşağıdaki işlem sözleşmesine uymak şartıyla handler içinden kendi sınıflarınızı çağırabilirsiniz.

## 1. Hazır handler'dan başlayın

1. Deneme kutusunda `ZCHE_IMAP_HANDLER_DEMO` ile başarılı bir çalıştırma yapın.
2. **SE38** içinde kurulu programı `ZCHE_IMAP_HANDLER_CUSTOM` gibi müşteri adına kopyalayın. Türü **subroutine pool** olarak koruyun ve transport edilebilir müşteri paketinizi atayın.
3. `INCLUDE zche_imap_common` satırını ve `HANDLE_MAIL` arayüzünü koruyun. `ZCHE_IMAP_COMMON` dosya yardımcılarını (`ZCHE_IMAP_IO`) zaten içerir; ikinci kez eklemeyin.
4. `ZCHE_IMAP_CONFIG` içindeki **Handler program** alanına programınızı, **Handler FORM** alanına `HANDLE_MAIL` girin. Kaydedip bağlantı sonucunu kontrol edin.
5. İşlemeyi zamanlamadan önce yetkilendirilmiş job kullanıcısıyla test edip monitörü inceleyin.

Installer kendi demo handler'ını içerir; özel kopyanızı içermez. İş kodunuzu ayrı program/pakette tutup transport'a ekleyin. [Paket ve transport adımına](TECHNICAL-REFERENCE.md#2b-canlıya-çıkmadan-önce-paket-ve-transport) bakın.

## 2. Girdileri ve sonucu tanıyın

`ZCHE_IMAP_HANDLER_CUSTOM` oluşturacağınız program için örnek addır. Başka ad seçerseniz ad `ZCHE_IMAP_HANDLER_` ile başlamalıdır: işlemci yalnızca kurulumun belirlediği bu önekle başlayan programları çalıştırır, diğerlerini reddeder. SE38'de, örneğin `PROGRAM` satırında ve profilin handler alanında aynı adı kullanın. Kurulu include adlarını ve `HANDLE_MAIL` arayüzünü gösterildiği gibi koruyun.

İş mantığı gereken her uygun ileti için işlemci şu arayüzü dinamik olarak çağırır:

```abap
FORM handle_mail USING    is_mail TYPE zche_imap_s_mail
                          it_body TYPE STANDARD TABLE
                          it_att  TYPE STANDARD TABLE
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
```

| Parametre | İçerik / sorumluluk |
|---|---|
| `is_mail` | `ZCHE_IMAP_S_MAIL`: profil, UIDVALIDITY, UID, gönderen, alıcı, bilgi alıcıları, konu, tarih, Message-ID, çalışma klasörü ve ek sayısı. Girdi olarak değerlendirin. |
| `it_body` | `ZCHE_IMAP_S_LINE` satırları, metin `TEXT` alanında. Düz metin gövde; yoksa metne çevrilmiş HTML. |
| `it_att` | `ZCHE_IMAP_S_ATT` satırları: yerel `PATH`, güvenli `NAME`, özgün ad `ORIG`, bayt boyutu `ATTSIZE`, MIME türü ve `DISP`. |
| `cv_ok` | İşiniz gerçekten başarılıysa tam olarak `'X'` atayın. Diğer değerler hatadır. |
| `cv_msg` | Hata durumunda anlamlı mesaj; çağıranın 255 karakterlik alanı kadar. Parola ve gereksiz kişisel veri eklemeyin. |

Ek yolu olarak işlemcinin verdiği `PATH` kullanın; gönderenin özgün dosya adından yol türetmeyin. `inline` genellikle imza görselidir; hangi ekleri kabul edeceğinizi açıkça belirleyin. Gönderen, konu, MIME ve dosya adı güvenilmeyen posta içeriğidir; kimlik veya dosya güvenliği kanıtı değildir.

## 3. Küçük bir ek okuma örneği

Bu tam subroutine pool en az bir boş olmayan, inline dışı PDF'nin okunabildiğini kontrol eder. **Öğrenme örneğidir**; fatura doğrulama, zararlı yazılım tarama veya belge oluşturma yapmaz. İletinin bildirdiği MIME türü dosyanın geçerli PDF olduğunu kanıtlamaz.

```abap
PROGRAM zche_imap_handler_custom.

INCLUDE zche_imap_common.

FORM handle_mail USING    is_mail TYPE zche_imap_s_mail
                          it_body TYPE STANDARD TABLE
                          it_att  TYPE STANDARD TABLE
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
  DATA: ls_att   TYPE zche_imap_s_att,
        lt_bin   TYPE ty_t_bin,
        lv_len   TYPE i,
        lv_ok(1) TYPE c,
        lv_count TYPE i.

  CLEAR: cv_ok, cv_msg, lv_count.
  LOOP AT it_att INTO ls_att.
    IF ls_att-disp = 'inline'.
      CONTINUE.
    ENDIF.
    IF ls_att-mime <> 'application/pdf'.
      CONTINUE.
    ENDIF.
    PERFORM read_binary_file USING ls_att-path
      CHANGING lt_bin lv_len lv_ok.
    IF lv_ok IS INITIAL OR lv_len = 0.
      cv_msg = 'PDF attachment could not be read or is empty'.
      EXIT.
    ENDIF.
*   Add validated business processing here. Do not commit.
    lv_count = lv_count + 1.
  ENDLOOP.
  IF NOT cv_msg IS INITIAL.
    EXIT.
  ENDIF.
  IF lv_count = 0.
    cv_msg = 'No readable non-inline PDF attachment found'.
    EXIT.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.
```

`READ_BINARY_FILE`, **1.024 baytlık** `ty_t_bin` satırlarıyla gerçek bayt uzunluğu `lv_len` döndürür. Son satır dolgulu olabilir. Dönüştürme/kaydetme/ekleme sırasında gerçek uzunluğu kullanın ve satır biçimini hedef API'ye uyarlayın. Farklı yapı bekleyen API'ye 1.024 baytlık satırları doğrudan vermeyin. Başarılı okuma sıfır bayt döndürebilir; örnek bunu ayrıca kontrol eder.

Gerçek handler'da `cv_ok = 'X'` atamadan gönderen/iş bağlamını ve belgeyi doğrulayın, mükerrerlik kontrolü yapın, onaylı iş API'sini çağırın ve dönüşlerini inceleyin. Demonun tamamlanması bu iş kurallarını doğrulamaz.

## 4. İşlem sözleşmesi: commit işlemciye aittir

`ZCHE_IMAP_INBOUND`, handler çağrısından önce **yerel V1 update** etkinleştirir. Başarıda `H` durumunu yazıp `COMMIT WORK AND WAIT` çalıştırır; uyumlu iş veritabanı değişiklikleri ve yerel V1 update'ler aynı veritabanı LUW'suna aittir. Handler hata döndürürse hata durumunu yazmadan önce iş değişikliklerini geri alır.

Handler ve çağırdığı bütün API'ler bu sözleşmeye uymalıdır:

- `COMMIT WORK`, `ROLLBACK WORK`, `BAPI_TRANSACTION_COMMIT` veya `BAPI_TRANSACTION_ROLLBACK` çalıştırmayın.
- LUW'yu örtük olarak bitiren RFC, transaction, rapor veya API çağırmayın. Seçtiğiniz API'nin davranışını hedef SAP sürümünde kontrol edin.
- V2, arka plan veya asenkron işi `H` ile atomik biçimde tamamlanmış saymayın. İş sonucu buna bağlıysa ayrı doğrulama/mutabakat akışı tasarlayın.
- Harici veya veritabanı işlemine dahil olmayan etkileri bağımsız olarak tekrar çalıştırılabilir tasarlayın. Gönderilmiş HTTP isteği, e-posta veya dış dosya SAP veritabanı rollback'iyle geri alınamaz.
- Hataları `cv_ok` ve `cv_msg` ile döndürün; arka planda etkileşimli ekran açmayın. Dump/update hatalarını normal SAP işletim araçlarıyla da inceleyin.

Bu koşulsuz bir “tam olarak bir kere çalışır” garantisi değildir. Koruma handler'a, API'lerine ve hedef sistem davranışına bağlıdır. İş belgelerinden önce SAP'de gerçekten başarısız olan yerel update senaryosunu test edin.

## 5. Yeniden deneme ve mükerrerlik

| Durum / olay | İşlemcinin davranışı |
|---|---|
| Yeni uygun ileti | İndirir/ayrıştırır ve seçilen handler'ı çağırır. |
| Handler hata döndürür | İş LUW'sunu geri alıp `E` kaydeder. Tekrar deneme istenmedikçe normal çalışma atlar. `MAX_ATTEMPTS` (varsayılan 3) başarısız denemeden sonra retry seçeneği de atlar. |
| Monitörden yeniden deneme | `E`, `R` olur; normal çalıştırma handler'ı deneme sınırı aşılmış olsa bile tekrar çağırabilir. İşlemcinin retry seçeneği `E` kayıtlarını yalnızca `MAX_ATTEMPTS` sınırının altındayken içerir. |
| Handler başarısı kaydedildi | Uzak taşıma öncesi `H` kaydeder. |
| `H` sonrası taşıma hatası / kesinti | Taşımayı bekletir; özgün UID gelen kutusunda bulunmasa da normal işlemci kurtarmayı sürdürür. Tamamlanmış handler'ı bilerek tekrar çağırmaz. |
| Taşıma/arşiv tamamlandı | `S` kaydeder. |

SAP log kimliği, mevcut sistem/mandantın **profil + UIDVALIDITY + UID** birleşimidir. Sunucu dosyaları ayrıca SID/mandant/profil ile ayrılır ve tanımlı posta kimliğine bağlanır. Tek UID'yi genel mükerrerlik anahtarı kullanmayın. İletilmiş veya yeniden gönderilmiş bir iş belgesinin posta kimliği değişebilir; kendi sürecinizde doğrulanmış tedarikçi/belge referansı gibi iş anahtarı kullanın. Tek `Message-ID` yeterli bir iş benzersizliği kuralı değildir.

Yeniden çalıştırmak için log veya önbellek dosyalarını değiştirmeyin/silmeyin. Geçmişi olan profili başka kutuya bağlayamaz veya silemezsiniz; pasifleştirip yeni profil oluşturun.

## 6. Başka programdan işlemeyi başlatın

Normal giriş noktası ayrı zamanlanmış `ZCHE_IMAP_INBOUND` job'ıdır. **Bekleyen iş değişikliği olmayan temiz işlem bağlamında** bir ön plan denemesi için:

Aşağıdaki rapor `P_PROF` alanında profil sorar. `ZCHE_IMAP_CONFIG` içinde gerçekten kaydettiğiniz adı girin; sabit bir `INVOICE` profili yoktur. `ZCHE_IMAP_START_DEMO` önerilen rapor adıdır; başka ad seçerseniz SE38 adıyla `REPORT` satırını eşleştirin.

```abap
REPORT zche_imap_start_demo.

PARAMETERS p_prof LIKE zche_imap_profile-profile OBLIGATORY.

START-OF-SELECTION.
SUBMIT zche_imap_inbound
  WITH s_prof EQ p_prof
  WITH p_test EQ 'X'
  AND RETURN.
```

Bu örnek yalnız uygun UID'leri listeler. Bilerek normal işleme için `p_test` kapatılır. **`AND RETURN` bağımsız veritabanı LUW'su oluşturmaz.** Normal işlemci commit/rollback yapar; kaydedilmemiş değişiklikleri olan açık iş işleminden çağırmayın. Başka uygulamaya bağlarken bağımsız job/oturum kullanın.

## 7. Dosyalar, roller ve dağıtım

- Profil anahtarı örneği: `A4H_001_INVOICE`. SAP `conf/KEY_REVISION.conf` yayımlar. `S` kaynağı `secret/KEY_CREDREV.cred`, `O` kaynağı `secret/KEY.cred` kullanır. Revizyon ve parola işaretçilerini elle değiştirmeyin.
- `bin`, `imap.ps1`, `mime.ps1` ve Basis'in yönettiği `policy.psd1` içerir. SAP'nin çalıştırılabilir/politika dosyalarına yazma erişimi olmamalıdır. Parola dosyaları OS izinleriyle korunan düz metindir.
- Girdi/arşiv verisi seçilen kökün altında ayrılmış posta klasörlerindedir. Handler'a sabit kök yazmayın; verilen yolları ve ortak yardımcıları kullanın.
- SAP nesneleri ve iki sunucu modülünü uyumlu protokol-2 bütünü olarak kurun. Eski arşivler ve güncellemeler için [geçiş adımlarını](TECHNICAL-REFERENCE.md#8-mevcut-kurulumu-güncelleyin) izleyin.
- Ayar, işleme ve izleme tek sunucuya bağlıdır. Yeni handler'ı uygun `S_DATASET` ve iş yetkisi tasarımına dahil edin. [Rol özetine](TECHNICAL-REFERENCE.md#yetkiler-ve-işletim-sınırları) bakın.

Kaynak modern ABAP sözdiziminden kaçınır, ASCII kullanır ve ABAP satırlarını 72 sütunda sınırlar. Eski SAP uyumluluğu hedeftir; doğrulanmış sürüm sertifikası değildir. Eklemeleri uyumlu tutup gerçek hedef sistemde derleyin.

## 8. Handler kabul kontrolleri

Ayrılmış deneme kutusu ve hedef SAP sisteminde normal başarıyı, eksik/geçersiz eki, rollback gerektiren iş hatasını, başarısız yerel V1 update'i, yetkili tekrar denemeyi ve handler başarısından sonraki taşıma hatasını deneyin. Kurtarmanın iş belgesini çoğaltmadığını doğrulayın. Zamanlanacak varyantı gerçek kısıtlı job kullanıcısıyla seçili sunucuda çalıştırın.

Kaynak/ayrıştırıcı/IMAP testleri elle çalıştırılır; [CONTRIBUTING.md](../../CONTRIBUTING.md) komutları içerir. Bunlar iş API'nizi çalıştırmaz, SAP derleyicisi ve çalışma zamanı kabul testinin yerini almaz. Güncel doğrulama sınırları [doğrulama kaydındadır](../../VALIDATION.md).
