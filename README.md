# Read emails and attachments in SAP

> **English** | [Türkçe](README.tr.md)

**Set up the SAP objects with one installer, then manage emails and attachments from SAP.**

Use this project to read messages from a mail server in SAP, retrieve attachments, and connect them to your own ABAP process. The supplied example demonstrates mail and attachment retrieval. You add business actions such as creating a document or linking an attachment to an existing record.

![From the mailbox to SAP: read mail, open attachments and add your business action](docs/assets/diagrams/usage-en.svg)

## What would you like to do?

| Your goal | Start here |
|---|---|
| Install for the first time | [Three preparations and SAP setup](docs/WALKTHROUGH.md#prepare) |
| Check connectivity and the message list | [Path A — List only](docs/WALKTHROUGH.md#list-only) |
| Open the first email and attachment in SAP | [Path B — First email](docs/WALKTHROUGH.md#first-mail) |
| Process attachments with my own ABAP code | [Developer guide](docs/TECHNICAL-GUIDE.md) |
| Run automatically at agreed intervals | [Path C — Variant and job](docs/WALKTHROUGH.md#daily-use) |
| Understand a field on the screen | [Field guide](docs/SCREEN-GUIDE.md) |

## Three parts to prepare

![Preparation map: mailbox, SAP application host and SAP programs](docs/assets/diagrams/setup-en.svg)

1. **Mailbox:** prepare the account SAP will read, its sign-in method, and the mail folders.
2. **Machine running SAP:** prepare PowerShell, curl, the project files, and a protected working folder. Your SAP GUI computer may be a different machine.
3. **SAP ERP:** create and execute `ZCHE_IMAP_INSTALL` in SE38, then prepare authorizations and mailbox settings.

You do not need three new servers. You can use an existing mail service and SAP host. **One installer file creates the SAP objects**; mailbox and host preparation are separate steps. No PI/PO or separate integration server is required.

We assume you can create and activate programs in SE38. Prepare the host and mailbox yourself if you administer them; otherwise the guide explains what to request from their administrators. [Start step by step](docs/WALKTHROUGH.md#prepare).

## Is your mailbox suitable?

**A correct email address and password may not be enough.** The account must allow IMAP and the password/app-password sign-in implemented here. Microsoft 365 / Exchange Online and OAuth-only accounts are unsupported in this version. [Mailbox requirements](docs/TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable).

The default source is **the inbox (`INBOX`)**; you can select another folder. Successful messages move to a different folder in the same account. **`SAP-Processed` is an example name, not a required new folder.** The destination you select must exist in the mailbox.

## What happens on the first run?

Start with **List only** to see message identifiers; it does not download message content or attachments. Then process a separate test message normally with the supplied example. Successful mail moves to the destination folder; open its body and attachments in `ZCHE_IMAP_MONITOR`.

Normal processing may mark mail as read and move it. Start with **a test SAP system and a dedicated test mailbox**.

## Status and details

**Current version: [v0.9.1 — release candidate](https://github.com/Cheditte/abap-imap-inbound/releases/tag/v0.9.1).** The earlier `ZIMAP_` edition opened mail and attachments on A4H. SAP runtime acceptance of the current `ZCHE_IMAP_` edition is still pending. Classic ABAP 7.00 compatibility is a target, not an ECC runtime certification. [Validation record](VALIDATION.md).

- [Setup and usage](docs/WALKTHROUGH.md) · [Field guide](docs/SCREEN-GUIDE.md)
- [Preparing the host yourself](docs/SELF-MANAGED-SETUP.md)
- [Technical reference](docs/TECHNICAL-REFERENCE.md) · [Authorization and credentials](SECURITY.md)
- [Updating an existing installation](docs/WALKTHROUGH.md#upgrade) · [Optional abapGit](ABAPGIT.md)

[MIT license](LICENSE) · [Changes](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Report an issue](https://github.com/Cheditte/abap-imap-inbound/issues)
