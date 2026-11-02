# Validation / Doğrulama

This record applies to the 0.9.1 release candidate. 0.9.1 fixes an installer defect found by code review after the 0.9.0 release: the handler prefix was never written, so no profile could be saved. SAP acceptance tests have not been executed for this candidate. The walkthrough now includes real standard SE38 and SM36 preparation screens, captured on 2 November 2026 without saving programs or jobs. They do not validate installation, mail processing or background execution. Current IMAP program screenshots remain pending; historical screenshots were removed. See [screenshot scope](docs/screenshots/README.md).

| Check / Kontrol | System and version | Date | Result |
|---|---|---|---|
| SAP activation | A4H / target SAP | 2026-11-02 | Not executed, operator request. |
| ABAP Unit | Classic test classes included in COMMON | 2026-11-02 | Added; not executed, operator request. |
| One mail end to end in SAP | A4H + GreenMail | 2026-11-02 | Not executed, operator request. |
| Restricted-user background job | Target SAP | 2026-11-02 | Not executed, operator request. |
| ABAP syntax and installer build | abaplint 2.120.92 v700; limited DDIC stand-ins | 2026-11-02 | Local check passed; does not validate SAP API signatures/runtime. |
| Windows parser and IMAP helper | Local PowerShell 7 + disposable GreenMail 2.1.14 | 2026-11-02 | Passed locally. |
| Windows PowerShell 5.1 | Local Windows parser, codepage and retention regressions | 2026-11-02 | Passed locally and on Windows CI. |
| Linux helper | Linux CI + disposable GreenMail 2.1.14 | 2026-11-02 | Passed on Linux CI with GreenMail 2.1.14. |
| Earlier edition in SAP | A4H (SAP_BASIS 7.58), `ZIMAP_` objects before the rename | before 2026-11-02 | Owner processed mail, viewed it in the monitor and opened attachments. Does not cover the 0.9.0 changes. |
| Old curl 7.55.1 | Unsupported | 2026-11-02 | Rejected by version guard; no compatibility claim. |

The DDIC fixtures are development-only and must never be installed into SAP. Real authorization enforcement, database LUWs, installer APIs and file permissions still require SAP acceptance before production use.
