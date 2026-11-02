# SAP screenshot reference / SAP ekran görüntüleri

These SAP GUI images include preparation screens captured on 2 November 2026 and owner-supplied A4H/001 results received on 3 November 2026. Labels are English; both walkthroughs explain them in their own language. Current release validation is recorded in [VALIDATION.md](../../VALIDATION.md). The diagrams are SVG in GitHub; the [setup-map PNG export](../assets/diagrams/setup-en.png) is provided for the SAP Community article.

| File | Screen and point in the workflow |
|---|---|
| [sap-se38-installer-entry.png](sap-se38-installer-entry.png) | SE38: the installer name has been entered, before Create. |
| [sap-program-attributes.png](sap-program-attributes.png) | Program attributes: Title and Type still need to be entered. |
| [sap-sm36-job-definition.png](sap-sm36-job-definition.png) | SM36: an unsaved job definition with an example name; target, step and timing still need to be set. |
| [sap-install-options.png](sap-install-options.png) | First-install options and the demo host folder `/usr/sap/sapimap/`. |
| [sap-install-complete.png](sap-install-complete.png) | Four main program syntax checks and host check passed; installation complete. |
| [sap-profile-demo.png](sap-profile-demo.png) | `DEMO` settings before the first connection attempt. `greenmail:3993` and `sap@demo.local` are test values. The password is masked. |
| [sap-connection-tls-error.png](sap-connection-tls-error.png) | First connection rejected the self-signed test certificate. |
| [sap-connection-success.png](sap-connection-success.png) | Login and both folders passed after certificate verification was disabled for the local test. INBOX was empty at that point. |
| [sap-inbound-selection.png](sap-inbound-selection.png) | `DEMO` selected for normal processing. List only and Retry are cleared; this is not the list-only route. |
| [sap-process-one-mail.png](sap-process-one-mail.png) | UID 2 completed, PDF and JPG listed, Processed 1 / Failed 0. |
| [sap-monitor-selection.png](sap-monitor-selection.png) | Initial monitor filters, before entering a profile. Use the run date shown in SAP. |
| [sap-monitor-list.png](sap-monitor-list.png) | Two Done records, no errors; includes the UID 2 run above and an earlier message. |
| [sap-monitor-details.png](sap-monitor-details.png) | UID 2 headers, mail body and attachment links. |
| [sap-monitor-image-open.png](sap-monitor-image-open.png) | JPG opened in the desktop viewer alongside its SAP details. The PDF is listed but not shown open. |

Images are kept as supplied; SAP labels and values have not been redrawn. No plaintext password is shown. Preparation images do not establish an executed installer or job; the later result images do establish the reported local installation and processing results.

The result images use the unreleased source at commit [`9447cbd`](https://github.com/Cheditte/abap-imap-inbound/commit/9447cbde1ceb56b829243ab6cc092c40abdb83be) in PR #9. The owner's file `ZCHE_IMAP_INSTALL-72fix.abap` matches that commit's installer after normalizing CRLF to LF (SHA-256 `2f35ddf2f2b4fa622815c734f4cc17e138d3051641ac698eda5b6f23904a7e86`). The on-screen version is still 0.9.2; these are not results from the published v0.9.2 asset. The host reports protocol 2, script version 0.9.2 and curl 7.66.0. The owner confirmed clearing Verify certificate only for the GreenMail trial. Certificate trust and restricted-user execution are not established by these images.

Türkçe: İlk üç görsel hazırlık ekranlarıdır; SM36 görseli tamamlanmış job kanıtı değildir. Sonraki on bir görsel A4H/001'de `9447cbd` kaynağıyla yapılan kurulum, profil bağlantısı, mail işleme, gövde görüntüleme ve JPG açmayı gösterir. Ekranda 0.9.2 yazsa da kaynak, yayımdaki release dosyasından farklıdır. Başarılı GreenMail bağlantısı yalnız test ortamında sertifika doğrulaması kapatılarak alınmıştır. Posta hesabında hedef klasör kontrolü ve PDF'nin açılması bu görüntülerde henüz yoktur. Görsellerin alındığı tarih ayrıca kaydedilmedi; 3 Kasım teslim tarihidir. SAP listesi 2 Kasım tarihini, mail başlığı ise +0300 saat diliminde 3 Kasım tarihini gösterir.
