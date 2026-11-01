# abap-imap-inbound

> **English** | [Türkçe](README.tr.md)

A way for SAP to collect incoming mail and pass it to your business process, without a separate integration server.

![Project note: why email documents need collecting, the SAP monitoring approach, and a first trial with the supplied example](docs/assets/business-need-en.jpg)

Imagine a shared mailbox where suppliers send invoices. Someone opens each mail, saves the PDF and adds it to a transaction in SAP. This project automates the collection step: SAP checks the mailbox, reads the message and attachments, calls your ABAP business logic, and records the result.

You provide the business rules—for example, which purchase order an attachment belongs to. The project provides the mailbox connection, file handling, processing flow and monitoring screen.

**Current source:** version **1.1.0**, script protocol **2**. Start with the [walkthrough](docs/WALKTHROUGH.md) for installation and first use.

## Start with your role

You do not need to be a developer to try the demonstration or use the configuration and monitoring screens. A functional consultant can lead the setup with Basis support. The [walkthrough](docs/WALKTHROUGH.md) explains the terms, what to enter, how to recognize success and who can resolve each type of error.

| What you want to do | Where to start |
|---|---|
| Understand whether this helps your business process | Read the examples below. |
| Try the supplied example, configure a mailbox or inspect results | [Step-by-step walkthrough](docs/WALKTHROUGH.md). |
| Prepare the SAP server, permissions and transport route | [Basis preparation](docs/WALKTHROUGH.md#0-prepare-the-server-basis) and [package/transport](docs/WALKTHROUGH.md#2b-before-production-package-and-transport). |
| Connect your own business action | [Developer guide with a complete handler example](docs/TECHNICAL-GUIDE.md). |

## Where could you use it?

Supplier invoices, order confirmations, delivery documents and service requests can all arrive by email. This project provides a common way to collect those messages and see what happened to them. Your team decides the business action: attaching a document, validating a reference or starting an agreed workflow requires your own rules and development.

Start by testing collection and monitoring with the supplied demonstration. Then agree the real business behavior with your functional consultant and ABAP developer.

## What it does

- Reads the sender, recipients, subject, body and attachments from an IMAP mailbox.
- Calls an ABAP **handler**: the program you write to decide what happens to each mail.
- Moves successfully handled mail to a folder such as `SAP-Processed`.
- Shows processing results, mail content and attachments in `ZIMAP_MONITOR`.
- Keeps failed messages available for a controlled retry and resumes pending moves without deliberately running a completed handler again.

The supplied handler is a demonstration. Creating invoices, extracting values from PDFs or attaching documents to business objects requires your own handler.

## Why read an existing mailbox?

Mail is still a common entry point for supplier invoices, order confirmations and logistics documents. An existing shared mailbox may already be part of the business process, particularly on older systems or in closed networks.

SAP also supports receiving mail through SAPconnect/SMTP. That involves mail being delivered to SAP. This project serves a different workflow: SAP periodically checks an existing mailbox and collects its contents. See SAP's [inbound communication flow](https://help.sap.com/saphelp_snc700_ehp01/helpdata/en/2b/d9260b4b8a11d1894c0000e8323c4f/content.htm?no_cache=true) for the native SMTP route.

The work runs on the Windows or Linux machine where SAP is installed—its **application server**. SAP starts a controlled server command through **SM69**; PowerShell and `curl` connect to the mailbox and prepare the mail as files. A separate middleware server is not required. PowerShell and an IMAPS-capable `curl` must be installed if the server does not already have them.

## Is it suitable for your system?

This project is intended for a classical ABAP system where Basis can install the server files and configure external commands. It can be useful when:

- the business already uses a dedicated mailbox;
- the mail server permits user-name/password authentication and supports **UID MOVE**;
- the SAP application server can reach the mail server;
- a developer can supply the business handler, and Basis can manage permissions and certificates.

The source deliberately uses old ABAP syntax, with a compatibility target of **4.6C–7.5x**. That target is not a certification: old and non-Unicode SAP releases have not been verified. See [what has been verified](#what-has-been-verified).

OAuth is not implemented. An account that requires OAuth cannot be used with this version. The `COPY` fallback is disabled; a server with UID MOVE support is required.

## How it works

| Program | What the person using it does |
|---|---|
| `ZIMAP_INSTALL` | Installs or updates the project's SAP objects and SM69 commands. |
| `ZIMAP_CONFIG` | Defines the mailbox profile, credentials, limits and handler. |
| `ZIMAP_INBOUND` | Lists eligible messages in test mode, or processes them in a normal run. Usually scheduled as a background job. |
| `ZIMAP_MONITOR` | Displays results and mail content, downloads attachments and marks failed messages for retry. |
| `ZIMAP_HANDLER_DEMO` | Shows the handler interface and a deliberate error example. Copy it for your business logic. |

A normal run lists messages, downloads each eligible mail, calls the handler, records the outcome and moves the mail. A successful handler is recorded before the move. If the move or local archiving is interrupted, a later run attempts to finish that step.

This relies on the handler following the transaction contract. Effects outside the SAP transaction need their own duplicate protection; the project does not promise unconditional “exactly once” processing.

## Installation

The [walkthrough](docs/WALKTHROUGH.md) explains every step, the required information and the expected checks. The three main stages are:

### 1. Basis prepares the application server

Windows needs **Windows PowerShell 5.1**; Linux needs **PowerShell 7**. Both need `curl` with `imaps` in its protocol list. From the unpacked project folder:

**Windows — an administrator PowerShell session:**

**This block asks for three values when you run it:** the actual IMAP hostname from the mail team, and the Windows SAP service account and full working-folder path from Basis. Enter your own value at each prompt and press Enter. Blank values stop setup. `-AllowedHosts` specifies the permitted mail server; enter the same hostname in the SAP profile's **Server** field. Do not enter a password or email address there.

**Copy the entire block, including its braces.** Answer the prompts with your own values, without adding quotation marks. Each block asks for the information it needs again.

```powershell
& {
  $ImapHostName = (Read-Host 'IMAP hostname from the mail team').Trim()
  $SapOsAccount = (Read-Host 'Windows SAP service account confirmed by Basis').Trim()
  $ImapRoot = (Read-Host 'Full working-folder path approved by Basis').Trim()
  if (@($ImapHostName, $SapOsAccount, $ImapRoot) -contains '') {
    throw 'Values are required. Obtain them from the responsible team and run again.'
  }
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File server\setup-server.ps1 `
    -AllowedHosts $ImapHostName -SapAccount $SapOsAccount -Root $ImapRoot
}
```

**Linux — run in Bash.** This block asks for the actual IMAP hostname, Linux SAP execution user and full folder path approved by Basis. Supply your own system values; blank values stop setup.

```bash
{
  read -r -p 'IMAP hostname from the mail team: ' imap_host
  read -r -p 'Linux SAP execution user confirmed by Basis: ' sap_os_user
  read -r -p 'Full working-folder path approved by Basis: ' imap_root
  sudo bash server/setup-server.sh \
    --allowed-hosts "${imap_host:?IMAP hostname is required}" \
    --sap-user "${sap_os_user:?SAP OS user is required}" \
    --root "${imap_root:?Working folder is required}"
}
```

The setup installs **both** `imap.ps1` and `mime.ps1`, creates the working folders, restricts access and writes the Basis policy. The default roots are `C:\sapimap` and `/usr/sap/sapimap`. The parent path must meet the setup's ownership and permission checks; use a short, administrator-controlled path.

### 2. A developer installs the SAP objects

Create `ZIMAP_INSTALL` as an executable program in **SE38**, paste the complete [generated source](ZIMAP_INSTALL.abap), activate it and run it. Confirm the server folder and leave the final server check enabled.

Use a customer package such as `ZIMAP` for maintained development. `$TMP` is suitable for a trial; the installer currently generates its objects there even if the installer itself is packaged. Follow the [package and transport procedure](docs/WALKTHROUGH.md#2b-before-production-package-and-transport) with development and Basis before production use.

The installer creates the project's DDIC objects and programs, checks syntax, defines the SM69 commands and checks the server version, protocol and root. Setup settings are saved after successful checks. Updating existing, different sources requires the explicit **Overwrite existing programs** option.

### 3. An administrator defines a mailbox profile

In `ZIMAP_CONFIG`, enter the server, user, folders and handler. Keep certificate verification enabled and use `MOVE`. Supply a password with source `S`, or let Basis manage it with source `O`. **F8** saves a profile revision and tests the connection.

**For source `O`:** the block asks for your own full profile key, Windows SAP service account and the folder used during setup. The key format is `SID_CLIENT_PROFILE`: obtain SID/client from **System → Status** in SAP and the profile name from `ZIMAP_CONFIG`. `A4H_001_INVOICE` only illustrates the format; do not copy it unchanged. The setup tool asks for the password separately afterwards.

```powershell
& {
  $ProfileKey = (Read-Host 'Full SID_CLIENT_PROFILE key for this system and client').Trim()
  $SapOsAccount = (Read-Host 'Windows SAP service account confirmed by Basis').Trim()
  $ImapRoot = (Read-Host 'Full working-folder path approved by Basis').Trim()
  if (@($ProfileKey, $SapOsAccount, $ImapRoot) -contains '') {
    throw 'Values are required. Obtain them from the responsible team and run again.'
  }
  powershell.exe -NoProfile -File server\setup-server.ps1 `
    -SetPassword $ProfileKey -SapAccount $SapOsAccount -Root $ImapRoot
}
```

The Linux equivalent and the exact fields are in the [walkthrough](docs/WALKTHROUGH.md#3-set-up-a-mailbox-profile).

## First use

1. Run `ZIMAP_INBOUND` with **List only (no downloads/changes)**. It lists eligible message UIDs; it does not download or preview messages, call the handler, move mail or expire local archives.
2. In a test mailbox, run it normally with `ZIMAP_HANDLER_DEMO`. This validates retrieval, parsing, logging and moving, without adding real business documents.
3. Review the results in `ZIMAP_MONITOR`, then connect and test your own handler.
4. Ask Basis to schedule the job on the **same application server** used for installation. Configuration and monitoring also use files on that host.

Normal downloads may mark messages as read. Successful processing also moves them, so use a mailbox dedicated to this integration.

The monitor opens PDF, PNG, JPG/JPEG, GIF, BMP and TXT files through the associated viewer. Other types, including Excel files and the original `.eml`, are **downloaded only**. Failed messages can be marked for retry by an authorized user.

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

## Further reading

- [Walkthrough: installation, first run and upgrades](docs/WALKTHROUGH.md)
- [Developer guide: use the handler in your own process](docs/TECHNICAL-GUIDE.md)
- [Architecture background](docs/DESIGN.md)
- [Server reference](docs/SERVER-SETUP.md) and [mailbox preparation](docs/MAILBOX-SETUP.md)

The walkthrough is the current installation procedure. Other reference guides may still contain 1.0 examples while their revision is in progress.

## License

[MIT](LICENSE)
