# Validation / Doğrulama

This record applies to the 0.9.2 release candidate. On 3 November 2026, the project owner confirmed running v0.9.2 in SAP and seeing results. This is an owner-reported manual result; the exact SAP release and individual scenario outcomes were not supplied with that confirmation. The date records the confirmation, not necessarily the execution date.

Earlier code reviews found two defects: in 0.9.0 the installer never wrote the handler prefix, so no profile could be saved (fixed in 0.9.1), and a failed profile save could be reported as successful (fixed in 0.9.2). Screenshots of earlier editions were removed because they do not show this version. The current [preparation screenshots](docs/screenshots/README.md) illustrate SE38 and SM36 steps, not the reported runtime results.

| Check / Kontrol | System and version | Date | Result |
|---|---|---|---|
| SAP execution of v0.9.2 | Owner's SAP system; exact SAP release not recorded | 2026-11-03 (confirmation) | Owner confirmed running this version and seeing results. |
| ABAP Unit | Classic test classes included in COMMON | — | Test result not recorded; not inferred from the manual confirmation. |
| One mail end to end in SAP | Target SAP and test mailbox | — | Separate outcomes for listing, body/attachment access and movement not recorded. |
| Restricted-user background job | Target SAP | — | Result not recorded. |
| ABAP syntax and installer build | abaplint 2.120.92 v700; limited DDIC stand-ins; GitHub Actions | 2026-11-02 | Passed for 0.9.2. Does not validate SAP API signatures or runtime. |
| Windows PowerShell 5.1 and 7 | Parser, codepage and retention regressions; Windows CI | 2026-11-02 | Passed for 0.9.2. |
| Linux helper | Linux CI + disposable GreenMail 2.1.14 | 2026-11-02 | Passed for 0.9.2. |
| Earlier edition in SAP | A4H (SAP_BASIS 7.58), `ZIMAP_` objects before the rename | before 2026-11-02 | Owner processed mail, viewed it in the monitor and opened attachments. Does not cover the 0.9.x changes. |
| Old curl 7.55.1 | Unsupported | 2026-11-02 | Rejected by the version check; setup requires curl 8.0.0 or newer. |

The DDIC fixtures are development-only and must never be installed into SAP. Real authorization enforcement, database LUWs, installer APIs and file permissions still require SAP acceptance before production use.

Bu kayıt 0.9.2 sürüm adayı içindir. Proje sahibi, 3 Kasım 2026'da v0.9.2'yi SAP'de çalıştırıp sonuç aldığını doğruladı. Bu tarih bildirimin tarihidir; çalıştırmanın tarihi ayrıca kaydedilmedi. Bildirimde SAP sürümü ve listeleme, gövde/ek açma, taşıma gibi adımların ayrı ayrı sonuçları belirtilmedi. ABAP Unit ve kısıtlı yetkili job sonuçları da bu manuel doğrulamadan çıkarılmadı. Rehberdeki SE38/SM36 görselleri hazırlık adımlarını gösterir; bu çalıştırmanın sonuç görüntüleri değildir. Yerel ve CI kontrolleri (abaplint v700, PowerShell testleri, GreenMail ile IMAP testleri) 0.9.2 için daha önce geçti; bu belge güncellemesi için yeniden çalıştırılmadı.
