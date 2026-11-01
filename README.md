# abap-imap-inbound

> **English** | [Türkçe](README.tr.md)

An open-source project that lets SAP check an email mailbox, collect messages and attachments, and show processing results inside SAP.

![Why email documents need collecting, viewing results in SAP, and a first trial with the supplied example](docs/assets/business-need-en.jpg)

Imagine suppliers sending invoices to a shared email address. Someone opens each message, downloads the PDF and adds it to a transaction in SAP. This project provides a foundation for **automating the collection of those messages and attachments**.

The supplied example lets you check that mail can be retrieved, attachments can be read and results can be recorded. **Creating invoices, reading amounts from PDFs or attaching documents to purchase orders requires development for your business process.**

**Current source version: 1.1.0.** Follow the [step-by-step walkthrough](docs/WALKTHROUGH.md) for installation. Installation and runtime tests for this version on an actual SAP system are still pending; read [what has been verified](#what-has-been-verified) below.

## Who can use it, and who needs to help?

You do not need to write ABAP code to try the supplied example, enter mailbox settings or inspect results. A functional consultant can coordinate setup. Server preparation, SAP permissions and adding your own business process need support from the relevant teams.

| Person / team | What they do |
|---|---|
| Functional consultant or process owner | Defines the need, prepares a test message, enters settings and checks the result. |
| Email administrator | Prepares the mailbox and folders; confirms IMAP access, the sign-in method and connection settings. |
| Basis / SAP system administration | Prepares the machine running SAP, network access, file permissions and SAP user permissions. |
| ABAP developer | Installs the SAP programs and adds your business action, such as attaching a document to a purchase order. |

## Terms you may be seeing for the first time

| Term | Meaning in this project |
|---|---|
| IMAP | A connection method that lets a program read messages and folders on a mail server. |
| Profile | A saved set of mailbox server, user, folder and processing settings in SAP. |
| Handler | The ABAP program that decides what to do with each message. Use the supplied `ZIMAP_HANDLER_DEMO` for your first trial. |
| Application server | The Windows or Linux machine running SAP. Server installation commands run there, rather than on your own computer. |
| Background job | A program SAP runs automatically on a schedule, for example to check for mail regularly. |

## Before you start: is your mailbox suitable?

**Entering your email address and correct password may not be enough to connect.** Being able to sign in through webmail or Outlook does not mean this project can connect using the same details.

Ask your email administrator to confirm:

- **IMAP access is allowed for the account.** Your organization may disable or restrict it. For a shared mailbox, the connecting account must also have permission to access that mailbox.
- **The sign-in method is compatible with this project.** This version connects with a username and password. OAuth, which uses browser authorization or access tokens, is not supported. An account that only accepts OAuth cannot be used with this version.
- **With two-step verification, the normal password may not work.** Some providers offer a separate app password. Your email team must confirm whether that option is available for your account and approved by your organization; it is not available for every account. Conditions vary by provider; see, for example, [Microsoft's connection requirements](https://support.microsoft.com/en-us/outlook/pop-imap-and-smtp-settings-for-outlook-com) and [Google's app-password explanation](https://support.google.com/mail/answer/185833?hl=en).
- **The SAP server can reach the mail server.** A connection that works from your computer may be blocked by a firewall from SAP. Basis and the network team check this.
- **Moving messages is permitted and supported.** Successful messages are moved to another mail folder. The email team must confirm support for the required `UID MOVE` feature.

Use **a separate test mailbox dedicated to this trial** first. Normal processing may mark messages as read and move them to another folder.

### Which settings do you need?

| Setting | Where it comes from and where to use it |
|---|---|
| IMAP hostname | Obtain it from the email team and enter it in the SAP profile's **Server** field. It is not your email address or the SAP server name. |
| Port and connection security | The email team supplies these together. `993 / IMAPS` is a common example; use the values confirmed for your account. |
| Login username | Use the value supplied by the email team. It may differ from your email address. |
| Password | Use the password appropriate to the approved sign-in method. Keep it out of support tickets and screenshots. |
| Folder to read | The actual folder name in the mailbox. The inbox is commonly `INBOX`; confirm its IMAP name rather than using a translated display name. |
| Processed folder | The mail folder for successfully handled messages, explained below. |

Numbers and names above are examples. Use the real settings for your account; ask the responsible team instead of guessing an unknown value.

### Where do you create `SAP-Processed`?

Create it **inside the email mailbox that SAP will read**, as a **mail folder** like the inbox. It is not a folder to create in SAP or on the server's disk.

For example, your test mailbox could contain:

```text
INBOX          → Messages to read (inbox)
SAP-Processed  → Destination for successfully processed messages
```

Ask your email administrator to create it, or use webmail if you have permission. If you create it in Outlook, it must belong to the account that synchronizes with the mail server; a local archive folder on your computer cannot be used.

`SAP-Processed` is a suggested name. If you choose another name, enter that folder's actual IMAP name/path in the SAP profile's **Processed folder** field. Create the folder first. This project accepts English letters, digits and `. _ / -` in folder names, with no spaces or non-ASCII characters.

## Installation: what order should you follow?

This is a roadmap. The screens and commands are in the [step-by-step installation guide](docs/WALKTHROUGH.md).

1. **Download the project files.** Use **Code → Download ZIP** at the top of this page and unpack the entire archive. Git is not required. Use server and SAP files from the same download.
2. **Prepare the test mailbox.** Obtain the settings above and create the processed folder.
3. **Have Basis prepare the server.** Processing runs on the SAP application server. Two helper tools, PowerShell and `curl`, retrieve mail there; no separate integration server is needed. Basis prepares network access and a protected working folder, then gives you its full path. [Server preparation](docs/WALKTHROUGH.md#0-prepare-the-server-basis).
4. **Install the SAP programs.** Someone with SAP development permission creates `ZIMAP_INSTALL` in the **SE38** program editor, loads the matching source file from this project and runs it. It creates the required SAP programs and tables. [SAP installation steps](docs/WALKTHROUGH.md#1-create-the-installer-program).
5. **Save a mailbox profile.** In `ZIMAP_CONFIG`, choose a profile name and enter your actual server, user and folder settings. For the first trial, select `ZIMAP_HANDLER_DEMO` as the handler and `MOVE` as the move method. Password source `S` means entering the password in SAP; `O` means Basis saves it on the server. **F8** saves the settings and tests the connection; saved settings alone do not prove the connection works. [Mailbox profile setup](docs/WALKTHROUGH.md#3-set-up-a-mailbox-profile).

For maintained use, your development team should create a **package**, such as `ZIMAP`: a group for managing related SAP development objects. The installer currently creates its objects in the local trial area `$TMP`; saving the installer in a package does not change that. Plan [package and transport steps](docs/WALKTHROUGH.md#2b-before-production-package-and-transport) with Basis and development to move the objects to test and production systems.

## What should you do in the first trial?

1. Send an email with a small PDF or text attachment to the test mailbox.
2. Open `ZIMAP_INBOUND` through **SE38** in SAP and enter the profile name you saved. Select **List only (no downloads/changes)** and run it. This lists eligible message numbers (`UID`); it does not show content or attachments, or move messages.
3. If listing succeeds, run the same test profile with `ZIMAP_HANDLER_DEMO`, this time **with List only cleared**. It now retrieves the message and attachments, records the example program's result and moves successful mail to the processed folder.
4. Open `ZIMAP_MONITOR` to inspect the result and attachments. A completed message has status `S`; it should also appear in the processed folder you selected in the mailbox.
5. After the trial, work with a developer to add your business rules. Ask Basis to schedule regular runs as a background job on the **same SAP application server** used for installation.

Do not expect the supplied example to create an invoice or purchase order in SAP. The trial checks the mail connection, file retrieval and viewing of results.

The monitor can open PDFs and common images using a suitable application on your computer. Other types, including Excel and the original email file (`.eml`), are downloaded for inspection. Authorized users can select failed messages for another processing attempt.

## Where should you start if the connection fails?

| What you see | Who should check it? |
|---|---|
| Correct email address and password, but sign-in is rejected | Email team: IMAP permission, actual login username, access to the mailbox and a supported sign-in method. |
| Server not found or connection timeout | Basis/network team: actual IMAP hostname, port and network access from the SAP server. |
| Certificate error | Basis/email team: hostname and trusted certificates. Keep certificate verification enabled. |
| Folder not found or messages cannot be moved | Email team: does the folder exist in that mailbox, is its name/path correct, and are move permission and `UID MOVE` support available? |
| SAP permission error | Basis/authorization team: the SAP user's program, file and command permissions. |
| Listing works but no content appears | **List only** shows message numbers. Use the normal trial with the supplied example to retrieve content. |

When asking for help, share the step and error text, without passwords. Detailed checks are in the [installation guide](docs/WALKTHROUGH.md).

<details>
<summary>For Basis and developers: technical details and checks</summary>

## Why read an existing mailbox?

This project has SAP periodically connect to an existing mailbox and collect messages. SAPconnect/SMTP provides another workflow, where mail is delivered to SAP. The choice depends on your requirements; see [SAP's inbound communication explanation](https://help.sap.com/saphelp_snc700_ehp01/helpdata/en/2b/d9260b4b8a11d1894c0000e8323c4f/content.htm?no_cache=true).

The source targets **4.6C–7.5x** compatibility on classical ABAP systems. This is not a certification; compilation and runtime tests on your target SAP release are required.

## Access and operating boundaries

Basis assigns permissions to the intended users and table authorization groups. The application checks table access with `VIEW_AUTHORITY_CHECK`; file and command permissions are additional checks.

| Role | Required access |
|---|---|
| Job user | Display `ZIMAP_PROFILE`; change `ZIMAP_LOG`; execute `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE` through `S_LOG_COM`; read the input mail files through `S_DATASET`; handler-specific permissions. |
| Profile administrator | Display/change `ZIMAP_PROFILE`; execute `ZIMAP_TEST`; write profile and credential files through `S_DATASET` for `ZIMAP_CONFIG`. |
| Monitor user | Display `ZIMAP_LOG`; read input/archive files for `ZIMAP_MONITOR`. Retry additionally requires change access to `ZIMAP_LOG`. |
| Installer | Development permissions for the project objects and the permissions needed to maintain and test SM69 commands. Uninstall has additional cross-client checks. |

- The project does **not** put passwords in its SAP tables. Credentials are plain-text files protected by OS permissions, accessible to the SAP service account and privileged administrators. The application does not display saved passwords.
- SAP password entry disables ordinary variant saving and printing. If the required protection API is unavailable, new SAP password entry is disabled; use Basis-managed source `O`.
- Basis controls allowed mail hosts, TLS exceptions, size limits and timeouts in `bin/policy.psd1`. SAP's service account has read/execute access to `bin`.
- Profile files are separated by system, client and profile, and published as revisions. A profile with mail history cannot be repointed to another mailbox or deleted; deactivate it and create a new profile instead.
- The installation is pinned to one application-server host. It does not provide automatic sharing of local files across application servers.
- Retention expires eligible, completed **local archives** during normal processing. Read-only test mode does not expire them. It does not purge `ZIMAP_LOG` or delete mail from the remote processed folder.

## Known limits

- Folder names use ASCII letters, digits and `. _ / -`, with no spaces. Prefer ASCII passwords for interoperability with older mail servers.
- The first `text/plain` body is used; otherwise HTML is converted to plain text. S/MIME decryption and `winmail.dat` unpacking are not implemented.
- Malformed or unsupported MIME, excessive nesting/part counts, and metadata that cannot fit the SAP file format are rejected instead of being reported as complete.
- The monitor displays at most 1,000 rows per query. Narrow the date, profile or status selection when needed.

## What has been verified

The distinction below applies to the **1.1.0 sources**:

| Area | Evidence |
|---|---|
| Parser and IMAP flow | Local regression runs on Windows with PowerShell 5.1/7 and Linux with PowerShell 7.4, against GreenMail 2.1.14. Includes identity/revision checks, retries, interrupted moves, retention, malformed MIME and size limits. |
| Linux setup | Isolated container setup, self-test and permissions using a separate OS account representing SAP. |
| Source/build | ABAP ASCII/72-column checks, eight-file abaplint grammar check targeting 7.02, PowerShell parsing, Windows native-helper compilation, Bash checks and reproducible installer generation. |
| Actual SAP runtime | The updated 1.1.0 SAP installer, screens and transactions still require validation on SAP. Earlier screenshots show a 1.0 demo on SAP ABAP Platform Trial 2025. |
| Older/non-Unicode SAP | Compatibility target only; not verified on 4.6C–7.0. |
| Windows server setup | Updated setup logic has not been exercised on a real SAP Windows server. |

Checks are run manually; this repository does not include an automated CI workflow. A grammar check does not replace the SAP compiler or runtime tests.

## Updating an existing installation

Read the [upgrade procedure](docs/WALKTHROUGH.md#8-update-an-existing-installation) before replacing files. Version 1.1.0 changes the script protocol, profile namespacing and revision storage.

Update SAP and **both server modules together**. Re-save profiles and re-enter source `S` passwords; Basis-managed credentials use the full system/client/profile key. Old mail directories are preserved but **not automatically migrated**. Pending `H` records and their files need a controlled migration plan.

## Development tests and build

Node.js 22+ and npm are development tools; they are not required on the SAP server. For source checks and parser tests with PowerShell 7:

```powershell
npm ci --ignore-scripts
pwsh -NoProfile -File test/check-source.ps1
pwsh -NoProfile -File test/run-tests.ps1 -Shell pwsh
```

The IMAP suite needs a disposable GreenMail instance with SMTP, IMAPS and its REST API. [CONTRIBUTING.md](CONTRIBUTING.md) contains the manual startup and test commands. Integration tests create a separate user for each run; do not point them at a business mailbox.

After changing ABAP sources, regenerate the installer:

```powershell
pwsh -NoProfile -File installer/build.ps1
```

</details>

## Further reading

- [Walkthrough: installation, first run and upgrades](docs/WALKTHROUGH.md)
- [Developer guide: use the handler in your own process](docs/TECHNICAL-GUIDE.md)
- [Architecture background](docs/DESIGN.md)
- [Server reference](docs/SERVER-SETUP.md) and [mailbox preparation](docs/MAILBOX-SETUP.md)

The walkthrough is the current installation procedure. Other reference guides may still contain 1.0 examples while their revision is in progress.

## License

[MIT](LICENSE)
