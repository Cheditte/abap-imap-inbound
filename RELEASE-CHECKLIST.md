# 0.9.0 publication handoff / Yayın devri

PR approval and publication are separate steps. Do not publish or tag the candidate as accepted SAP runtime software.

- Review and merge the release-preparation PR into main with the owner's approval; no direct main push or force push.
- Review the full-history redacted scan. The initial 11-commit scan flagged two examples: a disposable localhost GreenMail login in cloud setup and a profile-key documentation example. Both are fixtures, not live credentials. A separate history scan also found DNS-answer IP examples in the old mailbox setup pages; review these before public visibility. No history was rewritten. Repeat the scan at the approved publication commit; do not rewrite history automatically.
- SAP acceptance and new SAP screenshots were explicitly excluded by the owner. No current screenshot has been fabricated. Capture the real profile screen with certificate verification checked when SAP acceptance is later authorized.
- With explicit publication approval, make the repository public and tag `v0.9.0`; attach `ZCHE_IMAP_INSTALL.abap` from the tagged commit to the release.
- Description: “Read e-mails and attachments from an IMAP mailbox into SAP with ABAP. No PI/PO or integration server; PowerShell + curl on the SAP host. SAP'de IMAP ile mail ve ek okuma.”
- Topics: `sap`, `abap`, `imap`, `email`, `email-attachments`, `sap-erp`, `s4hana`, `ecc`, `inbound`, `powershell`, `curl`, `mime`, `turkce`.
- Disable the wiki at publication. Upload the prepared social-preview PNG through GitHub Settings → Social preview.
- Publish the TCMB Community article first. The owner writes the IMAP article in their voice, explaining the need, IMAP choice, host scripts, authorization/TLS/stdin credentials, handler contract and actual validation. Apply the platform's AI assistance disclosure where applicable.
- Set homepage to the Community article once its real URL exists. Then submit to dotabap.org, publish the Turkish article and LinkedIn post. These are owner actions; no external posts or submissions have been sent.

Türkçe: PR, herkese açma, release ve dış paylaşımlar ayrı onaylı adımlardır. SAP testleri ve yeni ekran görüntüleri kullanıcının isteğiyle bu çalışmanın dışında bırakılmıştır. Eski `ZIMAP_` verileri otomatik taşınmaz; üretim geçişi ayrıca planlanır.
