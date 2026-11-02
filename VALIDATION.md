# Validation / Doğrulama

This record applies to the 0.9.2 release candidate. Code reviews after release found two defects: in 0.9.0 the installer never wrote the handler prefix, so no profile could be saved (fixed in 0.9.1), and a failed profile save could be reported as successful (fixed in 0.9.2). Version 0.9.x has not yet run in SAP; the SAP rows below are still open. Screenshots of earlier editions were removed because they do not show this version.

| Check / Kontrol | System and version | Date | Result |
|---|---|---|---|
| SAP activation | A4H / target SAP | — | Not yet executed. |
| ABAP Unit | Classic test classes included in COMMON | — | Added; not yet executed in SAP. |
| One mail end to end in SAP | A4H + GreenMail | — | Not yet executed. |
| Restricted-user background job | Target SAP | — | Not yet executed. |
| ABAP syntax and installer build | abaplint 2.120.92 v700; limited DDIC stand-ins; GitHub Actions | 2026-11-02 | Passed for 0.9.2. Does not validate SAP API signatures or runtime. |
| Windows PowerShell 5.1 and 7 | Parser, codepage and retention regressions; Windows CI | 2026-11-02 | Passed for 0.9.2. |
| Linux helper | Linux CI + disposable GreenMail 2.1.14 | 2026-11-02 | Passed for 0.9.2. |
| Earlier edition in SAP | A4H (SAP_BASIS 7.58), `ZIMAP_` objects before the rename | before 2026-11-02 | Owner processed mail, viewed it in the monitor and opened attachments. Does not cover the 0.9.x changes. |
| Old curl 7.55.1 | Unsupported | 2026-11-02 | Rejected by the version check; setup requires curl 8.0.0 or newer. |

The DDIC fixtures are development-only and must never be installed into SAP. Real authorization enforcement, database LUWs, installer APIs and file permissions still require SAP acceptance before production use.

The walkthrough includes real standard SE38 and SM36 preparation screens, captured on 2 November 2026 without saving programs or jobs. They do not validate IMAP installation, mail processing or background execution. Current IMAP program screenshots remain pending. See [screenshot scope](docs/screenshots/README.md).

Bu kayıt 0.9.2 sürüm adayı içindir. 0.9.x henüz SAP'de çalıştırılmadı; tablodaki SAP satırları açıktır. Önceki `ZIMAP_` sürümü A4H'de mailleri işledi ve ekleri açtı. Yerel ve CI kontrolleri (abaplint v700, PowerShell testleri, GreenMail ile IMAP testleri) 0.9.2 için geçti.
