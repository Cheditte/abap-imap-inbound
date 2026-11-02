# From setup to your first email and scheduled use

> **English** | [Türkçe](tr/WALKTHROUGH.md) · [Overview](../README.md) · [Field guide](SCREEN-GUIDE.md)

Prepare the mailbox, SAP host and SAP programs first. Then open a test email in SAP and, if needed, schedule the same process in the background.

## Choose your goal first

**List only** shows message identifiers without downloading mail or attachments. **Normal processing** downloads content, runs the selected ABAP handler, and moves successful mail to the destination folder.

![Routes for setup, listing, the first email and scheduled use](assets/diagrams/goals-en.svg)

| Goal | Route | How do you recognize completion? |
|---|---|---|
| Install for the first time | [Three preparations](#prepare), then [SAP setup](#install) | Programs and authorizations ready; profile connection succeeds. |
| Check connectivity | [Path A — List only](#list-only) | Message identifiers or an empty-mailbox result; no content download. |
| Open mail and an attachment | [Path B — First email](#first-mail) | Monitor content and attachment available; successful mail in the destination. |
| Add my business action | [Developer guide](TECHNICAL-GUIDE.md) | Your validated ABAP action replaces the demonstration. |
| Run automatically | [Path C — Variant and job](#daily-use) | Job runs on the selected host; log and spool reviewed. |

This guide describes the `v0.9.2` release candidate. **Do not begin a new installation with its release asset:** SAP installation stops at a profile table name longer than the ABAP Dictionary limit. A corrected installer is awaiting SAP verification. [Validation record](../VALIDATION.md).

The SAP examples use English menu labels. They show the SE38 and SM36 preparation screens. [Screenshot scope](screenshots/README.md).

<a id="prepare"></a>
## Three preparations before you start

![Mailbox, SAP host and SAP ERP preparation](assets/diagrams/setup-en.svg)

We assume you can create and activate programs in SE38. **Use a test SAP system and a dedicated test mailbox.** Prepare the host and mailbox yourself if you administer them; otherwise pass the listed requirements to their administrators.

### Download the files once

In the [repository](https://github.com/Cheditte/abap-imap-inbound), choose **Code → Download ZIP** and extract the whole archive. Git and abapGit are optional. Keep `server`, `script` and `ZCHE_IMAP_INSTALL.abap` from the same version. Give the same archive to whoever prepares the host.

## 1. Prepare the mail server

**Goal:** choose the account SAP will read and two mail folders.

![Source mail folder, processing in SAP and a different destination folder](assets/diagrams/mail-flow-en.svg)

1. Obtain the **actual IMAP hostname, port and security type** from the provider or administrator. Do not enter your email address as the hostname.
2. Confirm that the account permits IMAP and password/app-password sign-in. A correct password alone may be insufficient. This version does not support Microsoft 365 / Exchange Online or OAuth-only accounts.
3. Select the source folder. `INBOX` is the default inbox; use the actual IMAP name for another folder.
4. Choose **a different existing destination folder in the same account** for successful mail. `SAP-Processed` is only an example; you do not have to create that name.

**Continue when:** connection details, an approved sign-in method and both actual folder names are ready. Keep passwords out of support tickets and screenshots. [Detailed requirements](TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable).

## 2. Prepare the machine running SAP

**Goal:** prepare mail retrieval tools on the Windows/Linux machine running SAP. This can be different from your SAP GUI computer.

![Prepare the tools, project files and protected folder on the SAP host](assets/diagrams/host-prep-en.svg)

| Preparation | Purpose | Expected output |
|---|---|---|
| PowerShell | Runs the project's host commands. | Windows PowerShell 5.1; Linux PowerShell 7.4+. |
| curl | Connects to the mail server using encrypted IMAP. | Version 7.66.0+ with `imaps` support. |
| Project files and folder | Holds mail, attachments and connection files. | Matching script versions and protected directories. |
| Network and certificates | Allows the SAP host to reach the mail service. | Actual mail endpoint/port reachable; certificate trust prepared. |

If you hold administrator access, follow the [RDP/SSH and file transfer guide](SELF-MANAGED-SETUP.md). Otherwise share the table with the responsible team. Run the [Windows](TECHNICAL-REFERENCE.md#windows) or [Linux setup commands](TECHNICAL-REFERENCE.md#linux) on the SAP machine.

**Continue when:** the host check reports `PROTOCOL 2`, `VERSION 0.9.2` and the correct folder, ending in `OK`. Record the **SAP application server and full working-folder path**. Use that same host in subsequent steps.

<a id="install"></a>
## 3. Install the programs in SAP ERP

![SAP setup: create the program, run the installer, prepare roles and save a profile](assets/diagrams/sap-steps-en.svg)

### 3.1. Create the installer program

1. In **SE38**, enter `ZCHE_IMAP_INSTALL` and choose **Create**.

   ![SE38 initial screen with ZCHE_IMAP_INSTALL and the Create button](screenshots/sap-se38-installer-entry.png)

   **On this screen:** enter the program name, then choose **Create** to open its attributes.

2. Enter a description; choose **Executable program** in **Type**.

   ![Initial program attributes dialog; Title and Type are still empty](screenshots/sap-program-attributes.png)

   **On this screen:** enter a title such as “IMAP installation”, choose **Executable program** in the empty **Type** field, then save. The image shows the dialog before those fields are filled.

3. Use your customer package, for example a package you created as `ZCHE_IMAP`. `$TMP` is for a temporary local trial only.
4. Replace the starter code with the **entire source** from [the installer file](../ZCHE_IMAP_INSTALL.abap). Do not upload the GitHub page saved as HTML.
5. Save, check syntax and activate with **Ctrl+F3**.

**Continue when:** the program is active without syntax errors.

### 3.2. Run the installer

Execute `ZCHE_IMAP_INSTALL` with **F8**:

| Option | First installation |
|---|---|
| DDIC, Programs, SM69 commands, Server check | Selected. Prepares tables, programs, commands and the final check. |
| Server folder | The **actual full path** prepared in part 2. |
| Code page | Automatic unless your developer confirms another [technical setting](TECHNICAL-REFERENCE.md#sap-installation-options-and-checks). |
| Overwrite existing programs | Cleared for a new installation; use the [upgrade route](#upgrade) for updates. |
| Uninstall | **Cleared.** |

Execute with F8 and read the whole result list. **Continue when:** installation and the final host check succeed. Resolve a failed step before continuing.

Generated objects go into `$TMP`; putting the installer itself in a package does not change this. For maintained use, reassign the objects to your customer package and prepare transport. [Package and transport](TECHNICAL-REFERENCE.md#2b-before-production-package-and-transport).

<a id="authorization"></a>
### 3.3. Create the authorization object and role

This permits users to work with the intended profile:

1. **SU20:** create authorization field `ZCHE_PROF` with installer-created data element `ZCHE_IMAP_PROFID`.
2. **SU21:** create object `ZCHE_IMAP` containing `ZCHE_PROF` and `ACTVT`.
3. **PFCG:** grant required profile activities: `03` display, `02` configuration/reprocessing, `16` execution.
4. Complete table, command and file grants using the [authorization matrix](../SECURITY.md). `S_TABU_DIS`, `S_LOG_COM` and `S_DATASET` are required. Assign the role and complete user comparison.

Work with the security administrator if those permissions belong to another team. **Continue when:** your user and the intended job user have the required grants.

### 3.4. Set up a mailbox profile

A **profile** is the saved name for connection and processing settings. Open **SE38 → `ZCHE_IMAP_CONFIG` → F8**. F8 **inside the configuration screen saves settings and checks connectivity**.

| Field | First use |
|---|---|
| Profile / Active | Your chosen name, for example `MAIL_DEMO`; Active selected. Use this name in later steps. |
| Server, Port, Security | Actual values from the mail administrator; certificate verification selected. |
| User / Password source | Actual login; default `O` means the administrator prepares the password on the host. |
| Folder to read | `INBOX` or the actual alternative source folder. |
| Processed folder | A different existing folder in the same account; `SAP-Processed` is optional. |
| Move method | `MOVE`; the mail server must support it. |
| Handler program / FORM | `ZCHE_IMAP_HANDLER_DEMO` / `HANDLE_MAIL`, the supplied example. |

For source `O`, the administrator [prepares the host credential](TECHNICAL-REFERENCE.md#profile-fields-and-server-managed-passwords) with the actual `SID_CLIENT_PROFILE` key. Source `S` is SAP-screen password entry with different protection/grant requirements. Saved passwords are not displayed again.

[Remaining fields explained](SCREEN-GUIDE.md#profile). **Continue when:** settings are saved and the connection check succeeds for the intended account.

<a id="list-only"></a>
<a id="4-test-the-three-parts-together"></a>
## Path A — Check connectivity and list messages

1. Open **SE38 → `ZCHE_IMAP_INBOUND` → F8** to reach the selection screen.
2. Enter **only your dedicated test profile**. An empty profile selection includes all active profiles.
3. **Select List only (no downloads/changes) yourself.** Do not assume it is selected on entry.
4. Execute with F8. A `UID` is the mail server's message identifier, not a business document number.

**Success:** eligible message identifiers or an empty-mailbox result. This path **does not download bodies/attachments, call the handler or move mail**. [Selection fields](SCREEN-GUIDE.md#processing).

<a id="first-mail"></a>
## Path B — Open the first email and attachment in SAP

![From the mailbox into SAP: read the message and process attachments with your ABAP code](assets/diagrams/usage-en.svg)

### B1. Process a dedicated test message

1. Send a small PDF/text attachment to the test account. If using another source folder, put the message there.
2. Keep the supplied demo handler in the same test profile.
3. Return to INBOUND, **clear List only** and execute with F8.

**Normal mail processing starts now.** Mail and attachments are retrieved; the example attempts to read attachments. Successful mail moves to the destination and may be marked as read. The example does not create an invoice or purchase order.

### B2. Verify in the monitor

1. Open **SE38 → `ZCHE_IMAP_MONITOR` → F8** to reach its selection screen.
2. Choose your profile and a date range covering the run; execute with F8.
3. Double-click the mail row to read headers, body and attachment details.
4. Open/download an attachment. PDF, text and supported images can open in an appropriate viewer; other file types download only.
5. Check the mailbox: successful mail should be in your chosen destination.

| Status | Meaning and next step |
|---|---|
| `S` — Done | Processing and movement complete; verify attachment and destination. |
| `E` — Error | Read the explanation and correct the cause. Ordinary runs skip earlier failures. |
| `H` — To move | Business result committed; movement pending. A normal run attempts movement recovery only. |
| `R` — Retry | An authorized user requested reprocessing; a normal run may try again. |

**Success:** an `S` record, an accessible attachment and the message in the destination verified together. Do not delete logs/files to force replay. [Errors and retry](SCREEN-GUIDE.md#errors).

### B3. Add your ABAP action

Follow the [developer guide](TECHNICAL-GUIDE.md) to copy the handler to your customer program. Preserve the allowed name prefix and transaction contract. Use your business key to prevent a document being created twice. The processor owns the commit.

<a id="daily-use"></a>
<a id="5-schedule-regular-processing"></a>
## Path C — Run automatically at agreed intervals

**Flow:** selections → variant → SM36 → SM37 log/spool. A variant stores settings; the job runs the program with those settings.

### C1. Prepare a list-only variant first

In INBOUND, enter your profile, **select List only**, and leave retry cleared. Save a variant under an unused name such as `IMAP_LIST_DEMO`; the name is only an example. Reload it to check the stored selections.

### C2. Define the job in SM36

1. Open **SM36** and enter an unused job name. `ZCHE_IMAP_LIST_DEMO` in the image is only an example.

   ![Initial SM36 job definition; target, step and start condition are not yet set](screenshots/sap-sm36-job-definition.png)

   **On this screen:** **Job Name** identifies the job, **Target** selects its server, **Step** sets the program/variant, and **Start condition** sets timing. This is an unsaved definition; complete it using the steps below.

2. Use **Job Class C** unless your organization specifies another class.
3. Set **Target** to the installation's application server. In a multi-server system, do not leave host selection to chance.
4. Choose **Step → ABAP program**; enter `ZCHE_IMAP_INBOUND` and your list-only variant. Check the execution user and save the step.

### C3. Set the start condition and inspect the result

1. For the first check, choose **Start condition → Immediate** with **Periodic Job cleared**. Save the condition and the main job.
2. In **SM37**, search by your job name, user and execution time. Widen status filters and refresh if needed.
3. Read **Job log** and **Spool**. **Finished does not mean mail was moved:** list-only jobs do not download content. Review counts and error details.

After checking the real job user and selected host, prepare **a separate variant and job** for Path B's normal processing. Clear List only only in that variant. Agree the interval with operations; use **Date/Time + Periodic Job + Period values** in SM36. Confirm the SAP/job timezone. Monitor initial runs through the monitor, log/spool and mailbox together.

<a id="upgrade"></a>
## If you already have an installation

Do not repeat first-install instructions without review. Stop scheduled work and follow the [upgrade procedure](TECHNICAL-REFERENCE.md#8-update-an-existing-installation).

For `0.9.0 / 0.9.1 → 0.9.2`, replace and activate the SAP installer source with the current file and deploy both matching host modules. After backup/review, select **Programs + Overwrite existing programs (update) + Server check**; assess required SM69/DDIC steps for your installation. Overwrite can replace local source changes. Do not resume jobs before host and profile checks succeed.

Old `ZIMAP_` and new `ZCHE_IMAP_` jobs must not process the same mailbox together. Old history is not migrated automatically.

## When you need help

[Field guide](SCREEN-GUIDE.md) explains screen choices. [Technical reference](TECHNICAL-REFERENCE.md) covers connectivity, host setup and transport. [SECURITY](../SECURITY.md) covers roles and credentials. Share the failed step and error text, without passwords or real mail content.
