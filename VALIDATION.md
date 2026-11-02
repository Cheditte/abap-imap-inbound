# Validation / Doğrulama

This record covers the published 0.9.2 release candidate and the subsequent local repair attempt. On 3 November 2026, installation in A4H/001 stopped at `ZCHE_IMAP_PROFILE`: the database table name is 17 characters, exceeding the ABAP Dictionary limit of 16. The earlier owner-reported mail and attachment result cannot be attributed to v0.9.2; those screenshots show the older `ZIMAP_` edition. The corrected installer has not yet been run in SAP.

Earlier code reviews found two defects: in 0.9.0 the installer never wrote the handler prefix, so no profile could be saved (fixed in 0.9.1), and a failed profile save could be reported as successful (fixed in 0.9.2). Screenshots of earlier editions were removed because they do not show this version. The current [preparation screenshots](docs/screenshots/README.md) illustrate SE38 and SM36 steps, not the reported runtime results.

| Check / Kontrol | System and version | Date | Result |
|---|---|---|---|
| SAP installation of v0.9.2 | A4H/001; SAP release not reconfirmed in this session | 2026-11-03 | Stopped at `ZCHE_IMAP_PROFILE`, `DDIF_TABL_PUT` exception 5. `ZCHE_IMAP_PARAM` and preceding DDIC definitions were created. No successful v0.9.2 mail run was established. |
| ABAP Unit | Classic test classes included in COMMON | — | Test result not recorded; not inferred from the manual confirmation. |
| One mail end to end in SAP | Target SAP and test mailbox | — | Separate outcomes for listing, body/attachment access and movement not recorded. |
| Restricted-user background job | Target SAP | — | Result not recorded. |
| ABAP syntax and installer build | abaplint 2.120.92 v700; limited DDIC stand-ins; GitHub Actions | 2026-11-02 | Passed for 0.9.2. Does not validate SAP API signatures or runtime. |
| Windows PowerShell 5.1 and 7 | Parser, codepage and retention regressions; Windows CI | 2026-11-02 | Passed for 0.9.2. |
| Linux helper | Linux CI + disposable GreenMail 2.1.14 | 2026-11-02 | Passed for 0.9.2. |
| Earlier edition in SAP | A4H (SAP_BASIS 7.58), `ZIMAP_` objects before the rename | before 2026-11-02 | Owner processed mail, viewed it in the monitor and opened attachments. Does not cover the 0.9.x changes. |
| curl 7.66.0 on SLES 15 | A4H host (PowerShell 7.4.6) + GreenMail 2.1.14 | 2026-11-03 | IMAP test suite passed: list, nonconsecutive UIDs, size limit, bad MIME, cleanup, TLS policy. 7.66.0 is the minimum. |
| Old curl 7.55.1 | Unsupported | 2026-11-02 | Rejected by the version check. |

The DDIC fixtures are development-only and must never be installed into SAP. Real authorization enforcement, database LUWs, installer APIs and file permissions still require SAP acceptance before production use.

Bu kayıt yayımlanmış 0.9.2 sürüm adayını ve yerel düzeltme girişimini kapsar. 3 Kasım 2026'da A4H/001'de kurulum `ZCHE_IMAP_PROFILE` tablosunda durdu: ad 17 karakterdir ve ABAP Dictionary sınırı 16 karakterdir. Önceki mail/ek sonucu 0.9.2'ye bağlanamaz; görüntüler eski `ZIMAP_` sürümündendir. Düzeltilmiş kurucu SAP'de henüz çalıştırılmadı. ABAP Unit ve kısıtlı yetkili job sonucu çıkarılamaz. Rehberdeki SE38/SM36 görselleri hazırlık adımlarını gösterir. Önceki yerel ve CI kontrolleri bu hatayı yakalamadı; bu düzeltme için testler yeniden çalıştırılmadı.
