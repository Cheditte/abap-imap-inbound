# SAP Community article outline

> **English** | [Türkçe](tr/COMMUNITY-OUTLINE.md) · [Project](../README.md)

This is an editing outline for the author, rather than a finished article. Write the motivation, design reasoning and observed results in your own words; use the repository guides for installation detail.

**Suggested title:** Reading Emails and Attachments in SAP with ABAP and IMAP – Open Source, No PI/PO

## 1. What it does

- Explain your actual reason for building the project and how you used it.
- Show the outcome first: read messages, retrieve attachments and connect them to an ABAP action.
- Describe successful mail as moving from the source folder to the selected destination folder.
- Use the [usage diagram](assets/diagrams/usage-en.svg) and [real mail detail screen](screenshots/monitor-detail.png).

## 2. Three preparation areas

- Mailbox: IMAP and supported password/app-password access; existing source and destination folders; UID MOVE support.
- SAP application host: PowerShell, curl, project files, host allowlist and certificate trust.
- SAP: one installer creates the SAP objects; CONFIG stores the mailbox profile; INBOUND processes; MONITOR shows results.
- Use the [three-part map](assets/diagrams/setup-en.svg) and [v0.9.3 installer result](screenshots/install-complete.png); link to the [walkthrough](WALKTHROUGH.md) for the steps.

## 3. Design decisions to explain

- **Why this approach?** Compare reading an existing IMAP mailbox with SAPconnect inbound SMTP routing; discuss when a landscape already has PI/PO or another integration solution.
- **Why host scripts?** Explain the classic ABAP IMAP-client gap and the choice of fixed SM69 commands calling PowerShell and curl.
- **Recovery:** explain the committed-handler / pending-move state, and why the handler still needs its own business duplicate checks.
- **Security:** password passed to curl over stdin; `policy.psd1` host allowlist; certificate verification; standard grants and optional per-profile `ZCHE_IMAP`; default retry limit of three failures.
- In the GreenMail demonstration, verification was disabled for the self-signed test certificate; real mailboxes need certificate trust configured on the host.

## 4. Status: facts to include

v0.9.3 was installed and run on **ABAP Cloud Developer Trial 2025, A4H/001, SAP_BASIS 816, S4FND 109, Linux (SLES), Unicode**. GreenMail 2.1.14 was used to list and process test messages, move successful messages and open the body and PDF/JPEG attachments in the monitor. The host used PowerShell 7.4.6 and curl 7.66.0.

Background jobs with restricted users, Windows SAP hosts, ECC 6.0 / SAP_BASIS 7.0x and real mail providers have not been tested. Keep this concise and invite feedback. This trial does not have S4CORE installed; avoid presenting it as a full S/4HANA system.

The [validation record](../VALIDATION.md) identifies the runtime and screenshot evidence; the List only picture is the selection screen, rather than a UID result list.

## 5. Links, images and publishing fields

- [Repository](https://github.com/Cheditte/abap-imap-inbound), [v0.9.3 release](https://github.com/Cheditte/abap-imap-inbound/releases/tag/v0.9.3), [English walkthrough](WALKTHROUGH.md), [Turkish walkthrough](tr/WALKTHROUGH.md), [security](../SECURITY.md).
- Suggested image order: usage diagram → three-part map → installer complete → mail detail; [connection result](screenshots/config-test.png) is optional.
- PNG exports for the Community image editor: [usage](assets/diagrams/usage-en.png), [three-part map](assets/diagrams/setup-en.png).
- SAP Managed Tag: **ABAP Development**.
- Blog labels: **GenAI Assisted Content**, **Learning**.
- User tags: **IMAP**, **email attachments**, **ABAP**, **SM69**, **open source**.

Before publication, remove editing placeholders, verify the links and captions, and ensure the final article reflects the author's own account. Avoid whole-source code dumps, production-readiness claims, ECC runtime claims or guarantees against duplicate business processing.
