# abap-imap-inbound

> **English** | [Türkçe](README.tr.md)

Read e-mails and attachments from an IMAP mailbox into SAP with ABAP, PowerShell and curl. No PI/PO or separate integration server is required; the scripts run on the SAP application host.

**For IMAP servers supporting a password or app password and UID MOVE. Microsoft 365 / Exchange Online is not supported:** this project does not implement OAuth. A separate Microsoft Graph project, abap-graph, is being prepared for that case. [Microsoft authentication guidance](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/deprecation-of-basic-authentication-exchange-online).

## Start with three preparations

1. **Mailbox:** a dedicated test account, IMAP hostname, TLS port and separate source/processed folders.
2. **SAP host:** PowerShell, curl and protected working folders. Follow [host setup](docs/SELF-MANAGED-SETUP.md). A browser connection from your PC is not sufficient.
3. **SAP:** paste [ZCHE_IMAP_INSTALL.abap](ZCHE_IMAP_INSTALL.abap) into SE38. Create the authorization object and roles in [security setup](SECURITY.md) before using the generated programs.

Use `ZCHE_IMAP_CONFIG` to define a profile with certificate verification enabled. Basis-managed credentials (source `O`) are the production default. Run `ZCHE_IMAP_INBOUND` in list-only mode, then process a synthetic mail with the demo handler. Inspect its body and attachments in `ZCHE_IMAP_MONITOR`. The processor commits the handler result before moving mail; it never issues EXPUNGE.

Installation is **copy/paste from one installer**. [abapGit](ABAPGIT.md) is an optional way to transport the installer source; execute the installer to create DDIC/program objects. Existing `ZIMAP_` installations require a reviewed migration; old data is not renamed or deleted automatically.

![Flow from the mailbox through the SAP host to the monitor](docs/assets/diagrams/usage-en.svg)

## Why not SAPconnect / SO50?

| Approach | Where it fits |
|---|---|
| SAPconnect / SO50 | Inbound SMTP routed to SAP; requires mail routing/relay and the SAP SMTP endpoint. |
| PI/PO or Integration Suite mail adapter | A managed integration layer when that infrastructure already exists. |
| Google ABAP SDK | Gmail API integration for Google mailboxes. |
| This project | Pull from a password-enabled IMAP mailbox using scripts on the SAP host. |

## Compatibility

| Component | Baseline / evidence |
|---|---|
| ABAP | Classic 7.00 syntax target; Unicode and system-codepage text I/O. |
| Windows host | Windows PowerShell 5.1 or PowerShell 7; curl 8.0.0+. |
| Linux host | PowerShell 7.4+; curl 8.0.0+. |
| Mail server | IMAP with TLS and UID MOVE; password/app-password authentication. |
| Verification | The earlier `ZIMAP_` edition read mail and opened attachments on SAP A4H. 0.9.0 has not yet run in SAP; feedback welcome. [Validation record](VALIDATION.md). |

curl 7.55.1 is deliberately rejected, not certified. Downloads must match the UID's declared RFC822.SIZE; size equality alone cannot prove identity. GreenMail tests exercise nonconsecutive UIDs and message contents.

## FAQ

### How do I read e-mail attachments in SAP ABAP?
The demo handler receives headers, body lines and attachment metadata. Use the helper to read binary content; add business logic in an allowlisted `ZCHE_IMAP_HANDLER_*` program. Follow the [handler contract](docs/TECHNICAL-GUIDE.md); only the processor commits.

### Does it work with Microsoft 365 / Gmail?
Microsoft 365 is unsupported. Gmail is usable only where the account permits IMAP and app-password authentication; OAuth-only accounts are unsupported.

### Which authorizations are needed?
Per-profile `ZCHE_IMAP`, table group `ZCHI`, scoped `S_LOG_COM` and file permissions. [Exact role and credential setup](SECURITY.md).

### What happens to unsupported characters or failed mail?
Display text substitutes `?` for characters outside the SAP codepage; `mail.eml` preserves the original bytes. Display headers and attachment names are bounded. Failed business processing remains visible, with a default three-failure cap and explicit monitor reprocessing. Failed local caches expire after 30 days; pending committed moves are protected. [Recovery details](SECURITY.md).

[Walkthrough](docs/WALKTHROUGH.md) · [Technical reference](docs/TECHNICAL-REFERENCE.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
