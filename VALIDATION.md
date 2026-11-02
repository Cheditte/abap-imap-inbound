# Validation / Doğrulama

This record applies to v0.9.3. Version 0.9.3 is the first `ZCHE_IMAP_` release that was installed and run in SAP. Earlier 0.9.x releases could not be installed: the profile table name exceeded the ABAP Dictionary limit, an embedded line exceeded 72 columns, a parameter type did not match, and the Unix SM69 command quoted the script path. 0.9.3 fixes these, as found during the installation below.

| Check / Kontrol | System and version | Date | Result |
|---|---|---|---|
| SAP installation | SAP ABAP Platform 2025 Trial (A4H/001), SAP_BASIS 816, Linux (SLES), Unicode | 2026-11-03 | `Installation complete.`: DDIC objects, programs, syntax checks, SM69 commands and server check. Handler prefix and retry limit written to `ZCHE_IMAP_PARAM`. |
| Profile and connection test | Same system; GreenMail 2.1.14, IMAPS, password source `S` | 2026-11-03 | Profile saved; connection test passed. Optional `ZCHE_IMAP` object not defined, so standard authorizations applied. |
| One mail end to end in SAP | Same system and mailbox | 2026-11-03 | List only showed the messages; two test mails processed with status `S` and moved to the processed folder. Body (Turkish characters) and attachments (PDF, JPEG) opened from the monitor. |
| Host scripts | A4H host: PowerShell 7.4.6, curl 7.66.0 (SLES 15), GreenMail 2.1.14 | 2026-11-03 | IMAP test suite passed: list, nonconsecutive UIDs, size limit, bad MIME, cleanup, TLS policy. curl 7.66.0 is the minimum. |
| ABAP syntax and installer build | abaplint 2.120.92 v700; GitHub Actions; A4H compiler check | 2026-11-03 | Passed. |
| PowerShell 5.1 and 7 | Parser, codepage and retention regressions; Windows and Linux CI | 2026-11-03 | Passed. |
| Background job, restricted user | Target SAP | — | Not yet tested. |
| Windows host, ECC 6.0 / SAP_BASIS 7.0x, production mail servers | — | — | Not yet tested. |
| Old curl 7.55.1 | — | 2026-11-02 | Rejected by the version check. |

The DDIC fixtures under `.abaplint-deps` are development-only and must never be installed into SAP.

Bu kayıt v0.9.3 içindir. 0.9.3, SAP'de kurulup çalıştırılan ilk `ZCHE_IMAP_` sürümüdür. SAP ABAP Platform 2025 Trial (SAP_BASIS 816, Linux, Unicode) üzerinde GreenMail test kutusuyla kurulum, profil, bağlantı testi, List only, iki test mailinin işlenmesi ve taşınması, monitörde gövde ve eklerin (PDF, JPEG) açılması başarılı oldu. Sunucu betikleri curl 7.66.0 ile test edildi. Arka plan işi, kısıtlı kullanıcı, Windows sunucu, ECC 6.0 ve gerçek posta sunucuları henüz denenmedi.
