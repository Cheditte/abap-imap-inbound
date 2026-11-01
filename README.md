# abap-imap-inbound

> **English** | [Türkçe](README.tr.md)

An open-source project for collecting documents sent by email and tracking processing results inside SAP.

![Why email documents need collecting, viewing results in SAP, and a first trial with the supplied example](docs/assets/business-need-en.jpg)

## What does it help with?

Imagine suppliers sending invoices or delivery documents to a shared email address. Someone opens each message, downloads its attachments and prepares them for use in SAP. This project provides a starting point for automating the collection of those messages and attachments.

- Retrieves messages and attachments from the mailbox you select.
- Shows which messages were processed successfully and which encountered errors in SAP.
- Moves successfully processed messages to a separate folder in the mailbox.

You can try this flow with the supplied example. Add business actions such as creating invoices, reading amounts from PDFs or attaching documents to purchase orders according to your needs.

## Who is this guide for?

This guide is for **SAP developers and people who can at least create, save, activate and run programs through SE38**. You need SAP development permissions for these steps. You will install the SAP programs, enter the mailbox settings and run the supplied example yourself.

Server and email administration may require separate permissions. If you administer your own system, you can prepare those parts too; otherwise, ask the teams that manage them.

| Preparation | If you have permission | If another team manages it |
|---|---|---|
| Machine running SAP | Connect through RDP/SSH and prepare the required tools and project files. | Ask Basis or the server administrator to prepare it. |
| Email account | Check connection settings and access permissions in the provider panel. | Obtain the settings from the email administrator or provider support. |

The [self-managed setup guide](docs/SELF-MANAGED-SETUP.md) explains server access and mailbox preparation.

## What should you know before starting?

Use a **separate test mailbox** dedicated to the trial. Processing may mark messages as read and move them to another folder.

**Your email address and correct password may not be enough to connect.** The account must allow IMAP access: permission for another program to read the mailbox. Being able to sign in through Outlook or webmail does not prove this access is available. If you manage the account, check the provider's connection requirements; otherwise, ask its administrators to confirm them. Some accounts require sign-in methods this version does not support; see the separate guide for [detailed connection requirements](docs/TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable).

### Where is mail read from, and where does it go?

- **Folder to read:** The default is the **inbox (`INBOX`)**. If you want to collect mail from a specific folder instead, enter that folder's name in the settings. For example, selecting an existing `Invoices` folder reads only the messages there.
- **Processed folder:** Choose the mail folder for successfully processed messages in the settings. You can use an existing folder that is different from the source folder. `SAP-Processed` is just the initial example name; you do not need to create a new folder with that name.

Both folders belong to **the same email account**. You do not need to create folders in SAP or on your computer's disk.

## How can you get started?

1. **[Open the walkthrough and download the files](docs/WALKTHROUGH.md).** Prepare the server and mailbox yourself where you have permission, or ask the responsible teams.
2. **Install the SAP programs.** Create, activate and run the installer in SE38. Then save the mailbox settings and test the connection.
3. **Try the supplied example.** Send a test email with a small attachment and check the result, attachment and destination folder.
4. **Add your business action.** For example, agree with the process owner which purchase order a document belongs to, then implement it using the [developer guide's examples](docs/TECHNICAL-GUIDE.md).

## Further reading

| What you need | Guide |
|---|---|
| Installation and first use | [Step-by-step walkthrough](docs/WALKTHROUGH.md) |
| Preparing your own test system without separate Basis/email teams | [Self-managed setup guide](docs/SELF-MANAGED-SETUP.md) |
| Connection requirements, permissions, technical limits and test status | [Technical reference](docs/TECHNICAL-REFERENCE.md) |
| Code examples for adding your business action | [Developer guide](docs/TECHNICAL-GUIDE.md) |

**Current source version: 1.1.0.** Installation and runtime tests for this version on an actual SAP system are still pending. Evaluate it in a test system first; the technical reference describes [what has been tested](docs/TECHNICAL-REFERENCE.md#what-has-been-verified).

## License

[MIT](LICENSE) — you may use, modify and share the project under the license terms.
