# Walkthrough: from a mailbox to your first result in SAP

> **English** | [Türkçe](tr/WALKTHROUGH.md) · [Project overview](../README.md) · [Developer guide](TECHNICAL-GUIDE.md)

You do not need to write ABAP to follow this guide and try the supplied demonstration. A functional consultant can coordinate the setup, enter mailbox settings, run the demonstration and inspect the result. Server installation and SAP permissions need help from **Basis**, the team that administers SAP. Adding your own business process needs an ABAP developer.

The demonstration collects mail and attachments, records the result and moves successful mail to another mailbox folder. It does not create invoices or extract values from PDFs.

This guide describes source version **1.1.0**, script protocol **2**. Screenshots show an earlier **1.0** demonstration on SAP ABAP Platform Trial 2025, Linux/Unicode. They help you find the screens; they do not verify the updated version in SAP. Labels and fields may differ.

## Before you start

Use a development or sandbox SAP system and a **dedicated test mailbox**. Normal processing can mark messages as read and move them. Do not start with a personal or live business mailbox.

| Term | Meaning |
|---|---|
| Application server | The Windows or Linux machine on which SAP runs, separate from your laptop. |
| Basis | The team responsible for the SAP server, installation and permissions. |
| Profile | Saved settings for one mailbox and its processing rules. Our example is `INVOICE`. |
| Handler | The ABAP program that decides what happens to each mail. Start with the supplied demonstration. |
| Package / transport | SAP's way to group development objects and move them from development to test and production. |
| UID | The mail server's message number within a particular mailbox generation. |

| Step | Person to involve | Continue when… |
|---|---|---|
| Prepare mailbox | Mail administrator | You have connection details and a processed folder. |
| [0. Server preparation](#0-prepare-the-server-basis) | Basis/server administrator | The server self-test passes. |
| [1. Create](#1-create-the-installer-program) and [2. run the installer](#2-run-the-installer) | User with SAP development permissions | All selected installation steps succeed. |
| [2b. Package and transport](#2b-before-production-package-and-transport) | Developer and Basis | The project has an agreed transport route. |
| [3. Mailbox profile](#3-set-up-a-mailbox-profile) | Consultant/administrator with the assigned role | The connection test succeeds. |
| [4. First run](#4-process-mail) and [5. monitor](#5-monitor-mails-and-attachments) | Consultant/operations | The test message reaches status `S`. |
| [6. Scheduling](#6-schedule-regular-processing) | Basis/operations | The intended background user can run it successfully. |

Enter transaction codes in SAP GUI's command field. For example, use `SE38`, or `/nSE38` if already inside another transaction. Menu names depend on the logon language; examples below use English labels.

### Get the project files

Open the [GitHub repository](https://github.com/Cheditte/abap-imap-inbound), choose **Code → Download ZIP**, and extract the complete archive. You do not need to install Git for this route. Keep the folder structure: Basis needs `server/` together with `script/`, and the developer needs the root-level `ZIMAP_INSTALL.abap`. Use files from the same version rather than mixing downloads.

**An email address and correct password alone may not be enough.** IMAP access must be allowed and the sign-in method must be compatible with this project. Two-step verification or organizational policy may block a normal password. Confirm with the email team; this version cannot be used where OAuth is required. [Mailbox suitability and folder explanation](TECHNICAL-REFERENCE.md#before-you-start-is-your-mailbox-suitable).

### A request you can send to the mail team

> Please provide a dedicated test mailbox for SAP IMAP processing, its login name, IMAP hostname, port and encryption mode. It must allow username/password authentication and UID MOVE. Please create a mail folder named SAP-Processed inside this mailbox, like its inbox, rather than on the server disk or in a local Outlook archive. Confirm that IMAP access and a username/password sign-in method compatible with this project are allowed. Share the password through our approved secret-sharing method. For an internal certificate authority, please give Basis the required CA certificates. SAP will read incoming messages and move successfully handled messages to SAP-Processed.

| Setting | Example | What it means |
|---|---|---|
| Server | `mail.example.com` | Incoming-mail hostname, matching the certificate. |
| Port / security | `993` / `IMAPS` | Encryption from the start. Port `143` with `STARTTLS` is another supported option. |
| User | `invoices@example.com` | Login name from the mail team; it may differ from the visible email address. |
| Source folder | `INBOX` | Where incoming messages arrive. |
| Processed folder | `SAP-Processed` | Where successful messages will be moved. Create it first. |

**Hostnames, users and ports in this table illustrate the format; do not copy them as your installation settings.** Obtain actual values from the mail team. `SAP-Processed` is a suggested folder name. If you choose another name, create that folder first and use the same name in the SAP profile.

OAuth is not implemented. **UID MOVE** is required; the `COPY` fallback is disabled. Folder names accept ASCII letters, digits and `. _ / -`, without spaces. Prefer ASCII passwords for older mail-server interoperability. Keep passwords out of tickets and screenshots.

### A request you can send to Basis

> Please select one application server for this installation and its background job. Confirm SAP's OS execution account, install PowerShell/curl as needed, allow an outgoing connection to the mail host and port, and prepare a protected working folder with the supplied server setup script. Please provide the folder path for ZIMAP_INSTALL and assign roles for installation, profile maintenance, processing and monitoring. Replace all example SID, client, account and path values with ours.

The installation records the chosen server hostname. Configuration, processing and monitoring must use that host. Basis may need to provide a direct logon to it. Project programs and SM69 commands are shared across SAP clients; coordinate updates with other owners.

## 0. Prepare the server (Basis)

**How to use the commands:** copy the complete block for your operating system, including its opening and closing braces. At each prompt, enter only your own value and press Enter; do not add quotation marks or square brackets. Obtain hostname/port values from the mail team and the SAP account/folder from Basis. Each block asks for its own values again and does not depend on a previous terminal session. `ZIMAP_INSTALL`, `ZIMAP_CONFIG`, `ZIMAP_INBOUND`, `ZIMAP_MONITOR` and `ZIMAP_HANDLER_DEMO` are actual program names; keep them unchanged.

**Run these commands on the SAP application server, not on the consultant's laptop.** Use the current repository's `server` and `script` folders together. Setup deploys both `imap.ps1` and `mime.ps1`.

Check connectivity from that server. On Windows, for example:

**This block prompts for the actual hostname and port.** Enter the values supplied by the mail team and press Enter, not your email address or SAP server name. Blank values stop the connection test. Use the same IMAP hostname for setup's `-AllowedHosts` / `--allowed-hosts` and the SAP profile's **Server** field.

```powershell
& {
  $ImapHostName = (Read-Host 'IMAP hostname from the mail team').Trim()
  $ImapPort = (Read-Host 'IMAP port from the mail team').Trim()
  if (@($ImapHostName, $ImapPort) -contains '') {
    throw 'Values are required. Obtain them from the responsible team and run again.'
  }
  Test-NetConnection -ComputerName $ImapHostName -Port ([int]$ImapPort)
}
```

`TcpTestSucceeded : True` confirms a TCP connection, not login or certificate trust. A failure needs DNS, routing, firewall and mail-service checks by the server/network team. The required connection is outgoing from the SAP server to the IMAP port.

### Windows

Use PowerShell 5.1 or later and a curl build whose `curl.exe --version` output includes `imaps`. In Windows PowerShell, use `curl.exe`: `curl` can mean a different command.

Run this block from the repository folder in an administrator PowerShell session. At the prompts, enter the mail team's IMAP hostname and the Windows SAP account and full working folder confirmed by Basis. Blank answers stop setup.

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

At the account prompt, enter the full service account confirmed by Basis; `DOMAIN\SAPServiceA4H` only illustrates the format. Specifying it avoids ambiguity on machines with multiple SAP instances. For a curl installation outside the default location, Basis must supply `-CurlPath` with the full path to the actual `curl.exe` file on the server, quoting the path if it contains spaces.

The default root is `C:\sapimap`. The block above explicitly asks for the folder path; enter the one approved by Basis. Use the same path for self-tests, credential setup and SAP installation. Keep it short: SAP's root field allows 60 characters, and older external-command interfaces also limit the combined command parameters. Do not weaken parent-directory permissions to bypass a setup failure.

Run the self-test. When prompted, enter the same full folder path you used during setup:

```powershell
& {
  $ImapRoot = (Read-Host 'Full working-folder path approved by Basis').Trim()
  if (@($ImapRoot) -contains '') {
    throw 'Values are required. Obtain them from the responsible team and run again.'
  }
  powershell.exe -NoProfile -File (Join-Path $ImapRoot 'bin\imap.ps1') test
}
```

Success identifies `PROTOCOL 2`, `VERSION 1.1.0` and the chosen root, then ends in `OK`. An administrator's self-test is useful, but the later SAP installer check must pass under SAP's actual execution account too.

### Linux

Install PowerShell (`pwsh`) and curl with IMAPS support. The generated SM69 command expects `/usr/bin/pwsh`. Confirm the actual SAP execution user; `a4hadm` is an example.

Run this block in Bash from the repository folder. Obtain the hostname from the mail team and the Linux SAP execution user and full working folder from Basis; enter your own values at each prompt.

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

The default root is `/usr/sap/sapimap`. If its parents are writable by a non-root user/group, setup rejects the path. Basis should select an approved root with protected parents, such as `--root /opt/sapimap` where appropriate, and use it throughout. Do not change ownership of existing SAP directories just to pass this check.

Test with the SAP execution user and chosen root. Answer both prompts with the Linux user and full folder path used during setup:

```bash
{
  read -r -p 'Linux SAP execution user confirmed by Basis: ' sap_os_user
  read -r -p 'Full working-folder path approved by Basis: ' imap_root
  sudo -u "${sap_os_user:?SAP OS user is required}" /usr/bin/pwsh \
    -NoProfile -File "${imap_root:?Working folder is required}/bin/imap.ps1" test
}
```

The result must identify protocol `2`, version `1.1.0` and the chosen root, then end in `OK`. It checks local prerequisites; SAP installation and mailbox access are checked later.

### Certificates and handover

Keep TLS certificate verification enabled. Basis must configure trust for the actual curl build, using its trust store or an approved CA file through `CaCert` in `bin/policy.psd1`. Windows Schannel and other curl TLS backends can use different trust mechanisms.

Basis hands over the root path, selected SAP host and confirmation of the self-test. No password belongs in this handover.

## 1. Create the installer program

This step needs SAP development permissions. If you do not have them, send these steps to a developer.

1. Open **SE38** in SAP GUI.
2. Enter **`ZIMAP_INSTALL`** and choose **Create**.
3. Enter a description, choose **Executable program**, and save.
4. For an isolated trial choose **Local Object** (`$TMP`). For maintained development, create a customer package such as `ZIMAP` with Basis/developer help and save the installer there.
5. Open [ZIMAP_INSTALL.abap](../ZIMAP_INSTALL.abap), copy the complete source, and paste it into the SAP editor.
6. Save, check the syntax and activate. Resolve any SAP compiler error before running.

![SE38: create the installer](screenshots/01-se38-create.png)

Choosing a package for this program does not package its generated objects. The installer currently creates those in `$TMP`; follow [step 2b](#2b-before-production-package-and-transport) for maintained use.

## 2. Run the installer

In **SE38**, enter `ZIMAP_INSTALL` and choose **Execute (F8)**.

![Installer screen from the earlier 1.0 demonstration](screenshots/02-install-screen.png)

For a first installation in development:

| Option | What to select / expect |
|---|---|
| DDIC objects | Selected. Creates project tables, structures, data elements and domains. |
| Programs | Selected. Creates configuration, processing, monitoring, includes and the demo handler. |
| SM69 commands | Selected. Creates the commands SAP uses to start the script. |
| Server check | Selected and required. Confirms SAP can run the expected script version and root. |
| Overwrite programs | Use for an agreed update after backup/review; it can replace local changes. |
| Server folder | The exact root from Basis, such as `C:\sapimap\` or `/usr/sap/sapimap/`. |
| I/O mode / code page | Keep automatic mode unless the developer confirms another choice. These control older systems' file reading. |
| Uninstall | Leave unselected. It removes shared objects across clients; it is not a profile reset. |

Execute and read the entire result list. Continue only when selected steps and the final server check succeed. Otherwise, keep the output for Basis/development.

Development permissions are checked even in SM69/server-only mode. The installer restores backed-up program/text and SM69 entries when applicable, but it is not a full database transaction or system backup. Review DDIC changes and newly created objects after a failed update.

## 2b. Before production: package and transport

`$TMP` is suitable for an experiment; its objects do not enter the normal package transport route. For maintained use, ask development and Basis to use your organization's customer package and transport process.

1. **In development**, create a package such as `ZIMAP` using **SE21** or **SE80**, with the transport layer agreed by Basis.
2. Install and test there. The current installer generates its objects in `$TMP`.
3. Inventory the actual project objects: installer, programs/includes, tables/structures, data elements and domains, plus your custom handler. Do not blindly select unrelated objects matching `ZIMAP*`.
4. Reassign the project's objects through **SE03 → Change Object Directory Entries**, or the applicable **SE80 → Reassign** action. Assign the package and collect objects in a transport request. Verify it contains the definitions and dependencies, not only the installer.
5. Import to the **test system**, prepare its server and local settings, and repeat the first-run checks. Then follow the approved production import process.

**This package/transport procedure has not been tested end to end with this project.** Validate it in your landscape before relying on it.

Transporting ABAP objects does not install PowerShell, OS files, permissions or credentials. Basis must review target-system SM69 command paths and authorizations, and prepare profiles/credentials for the intended system and client.

Do not assume that server-only installer mode works in a locked production system: it still checks development authorization and source consistency. Agree and test target-system setup in advance; this guide does not require relaxing production change controls.

SAP references: [Object Directory and package reassignment](https://help.sap.com/docs/SAP_NETWEAVER_700/109ce05a6c531014b4e8fe6b0570a984/5738e06c4eb711d182bf0000e829fbfe.html), [maintaining external commands](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_752/b17bd20044a44edb9aa7830ee52ffac3/c43a607b505211d189550000e829fbbd.html?locale=en-US&state=PRODUCTION&version=7.52.latest).

## 3. Set up a mailbox profile

Open **SE38 → `ZIMAP_CONFIG` → Execute**. Use the profile-maintenance role assigned by Basis and a logon on the selected application server.

Choose a profile name (for example, **`INVOICE`**) and enter the values from the mail team. The profile's name does not make the demo an invoice application.

`INVOICE` is a **suggested profile name**. You may choose another; use the name you actually save in later runs, job variants and the credential key. Hostname/user/port must come from your mailbox setup. `ZIMAP_HANDLER_DEMO` and `MOVE` are actual selections for this first trial. `50`, `20`, `120` and `30` are starting limits to agree for your process and Basis policy.

![Earlier profile screen; GreenMail connection values are test data](screenshots/04-config-profile.png)

| Field | First-test example | Explanation |
|---|---|---|
| Profile / active | `INVOICE` / selected | Name for these settings; active profiles can be processed. |
| Server / port | Your actual IMAP hostname / port | Obtain both from the mail team; do not copy the example address. |
| Security / verify certificate | Mode supplied by the mail team / selected | Select `IMAPS` or `STARTTLS` to match the port. Keep verification enabled. |
| User | Your actual mailbox login | Enter the login supplied by the mail team, not the example email address. |
| Credential source | `S` or `O` | `S`: enter the password in SAP. `O`: Basis saves it on the server. |
| Inbox / processed folder | Actual folder names in your mailbox | For example, `INBOX` / `SAP-Processed`; both folders must exist. |
| Move mode | `MOVE` | Requires UID MOVE support. |
| Handler program | `ZIMAP_HANDLER_DEMO` | Supplied demonstration; no business document creation. |
| Maximum mails | `50` | Example upper limit per run. |
| Maximum size | `20` | Example MiB per message; server policy can impose a lower limit. |
| Timeout | `120` | Example network timeout in seconds. |
| Retention | `30` | Days to retain eligible completed local archives, not SAP logs or remote mail. |

### Enter the password in SAP or ask Basis

For **source `S`**, enter the password in SAP. It is written to an OS-protected plain-text credential file, not a SAP table. Ordinary variant saving and printing are disabled for this entry. If SAP's required protection API is unavailable, new password entry is disabled: use source `O`. Do not enter a new password through a background variant.

For **source `O`**, Basis needs the full **`SID_CLIENT_PROFILE`** key. For system `A4H`, client `001` and profile `INVOICE`, it is **`A4H_001_INVOICE`**. Find SID and client under **System → Status**.

Basis runs the block for the server's operating system from the repository folder. It first asks for the actual full profile key, SAP OS account and full folder used during installation. Do not copy `A4H_001_INVOICE`; form the key from your own SID, client and profile. The setup tool prompts for the password separately afterwards; do not put it in the command.

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

```bash
{
  read -r -p 'Full SID_CLIENT_PROFILE key for this system and client: ' profile_key
  read -r -p 'Linux SAP execution user confirmed by Basis: ' sap_os_user
  read -r -p 'Full working-folder path approved by Basis: ' imap_root
  sudo bash server/setup-server.sh \
    --set-password "${profile_key:?Full profile key is required}" \
    --sap-user "${sap_os_user:?SAP OS user is required}" \
    --root "${imap_root:?Working folder is required}"
}
```

If a server credential contains `USER`, it must be empty or match the profile user exactly. The SAP OS account and privileged administrators can access credential files; this is file-permission protection, not a vault.

### Save and test

Choose **Execute (F8)**. The program publishes the profile, then tests it. **Saved settings do not by themselves mean the connection succeeded.** Read the connection result.

| Error area | Ask | Check |
|---|---|---|
| Host not allowed / root / wrong server | Basis | Policy, selected host, paths and permissions. |
| Connection / timeout | Basis/network team | DNS, routing, port, firewall and mail service. |
| Certificate / TLS | Basis/mail team | Hostname, chain, expiry and curl trust. Keep verification enabled. |
| Login | Mail team/Basis | Login name, authentication policy and credential source. |
| Folder / UID MOVE | Mail team | Both folders exist and UID MOVE is supported. |

## 4. Process mail

Send a simple message with a small PDF or text attachment to the test mailbox. Use a subject such as `First SAP mail test`.

1. Open **SE38 → `ZIMAP_INBOUND` → Execute**.
2. Enter the profile name saved in step 3. Use `INVOICE` only if that is the name you actually saved.
3. Select **List only (no downloads/changes)** and execute.
4. Confirm eligible message UIDs are listed. This does not download/preview mail, call the handler, move messages or expire archives.
5. Return, clear the list-only checkbox, and execute normally.

![Earlier processor screen; current test mode only lists eligible UIDs](screenshots/06-inbound-screen.png)

The normal demo downloads/parses mail, reads attachments, logs its result and moves successful messages to the processed folder specified in your profile. Downloading may mark mail as read.

Check the monitor and the mailbox: success should reach **`S`**, with the message in the processed folder. Subjects containing **`TEST-ERROR`** intentionally fail in the demonstration.

## 5. Monitor mails and attachments

Open **SE38 → `ZIMAP_MONITOR` → Execute**. Select profile and date range, then execute. Up to **1,000 records** are shown per query; narrow the selection when needed.

![Monitor list from the earlier demonstration](screenshots/08-monitor-list.png)

| Status | Meaning | Next action |
|---|---|---|
| `S` | Handler succeeded and mail movement completed. | Review if needed. |
| `E` | Processing failed before successful handler completion. | Fix the reported cause and authorize retry. |
| `R` | An error was marked for retry. | A normal run attempts it again. |
| `H` | Handler success was committed; mailbox movement is pending. | Resolve the move problem; normal processing resumes the move without intentionally rerunning the completed handler. |

Open a record for its details, body and attachment list. **PDF, PNG, JPG/JPEG, GIF, BMP and TXT** can open through the workstation's associated viewer. Other types, including Excel and the original `.eml`, are **downloaded only**. Save them and open with an appropriate application. Older automatic `.eml` opening screenshots do not describe current behavior.

Log records can outlive their local files. Retention expires eligible completed local archives, but does not clean up `ZIMAP_LOG` or remote processed mail. Agree their retention separately with the data owners.

### Try an error and retry

1. Send a message with `TEST-ERROR` in the subject; run normally with the demo handler.
2. Inspect the intentional error in the monitor.
3. Have a developer correct the cause or select an approved test handler accepting that message. Marking retry does not change the demo's rule.
4. An authorized monitor user selects the retry action. The record becomes `R`; run processing normally again.

Retry requires change access to the log. The processor also offers **retry errors** for an intentional retry of selected `E` messages. `H` uses move recovery. Do not delete log rows or server files to force another attempt.

## 6. Schedule regular processing

Ask Basis to schedule `ZIMAP_INBOUND` through **SM36**, using a variant for the intended profile with **list-only cleared**. Agree the interval with operations.

Use the installation's application server. Test with the actual restricted job user; a developer's successful foreground run is insufficient. Basis checks external-command, file, table and handler-specific permissions. See the [role outline](TECHNICAL-REFERENCE.md#access-and-operating-boundaries).

Before handling real business mail, have an ABAP developer implement and validate the business rules. The [developer guide](TECHNICAL-GUIDE.md) explains the interface. Keep the demo for demonstrations.

## 7. Technical reference: what SAP runs

This optional reference is for Basis/development diagnosis, not a request to run commands manually against live mail.

| SM69 name | Script action and positional arguments |
|---|---|
| `ZIMAP_TEST` | `test`, optionally `KEY REVISION` for a profile test. |
| `ZIMAP_LIST` | `list KEY REVISION`; normal SAP runs add `PURGE` to expire eligible completed local archives. Otherwise listing is read-only. |
| `ZIMAP_FETCH` | `fetch KEY UID UIDVALIDITY REVISION` |
| `ZIMAP_DONE` | `done KEY UID UIDVALIDITY REVISION` |

`KEY` includes SID, client and profile. SAP manages revisions; do not edit them manually. MIME parser tests have a separate local test entry point, not a production SM69 command.

## 8. Update an existing installation

Version 1.1.0 changes the script protocol, profile file names and revision storage. Plan a 1.0 upgrade in development/test first.

1. Stop scheduled processing and coordinate all clients sharing the installation. Back up SAP objects/settings/logs, policy, credentials and mail directories through your approved process.
2. Review pending `H` records with Basis/development. Old unscoped directories are preserved but **not automatically migrated**. Plan reconciliation before resuming; do not delete them or rerun completed business logic to get past the upgrade.
3. Deploy **both** `imap.ps1` and `mime.ps1` from the same version, reviewing/preserving policy. Update SAP objects and commands through the tested package/transport procedure. SAP and script must both use protocol `2`.
4. Check the selected host, roles and profiles. Re-save profiles and re-enter source `S` passwords. Recreate source `O` credentials using the full `SID_CLIENT_PROFILE` key.
5. Repeat server, connection, read-only list, normal demo, error/retry and pending-move recovery checks. Validate the job user and business handler before restarting jobs.

A profile with mail history cannot be redirected to another mailbox or deleted. Deactivate it and create a new profile when mailbox identity changes.

See [verification limits](TECHNICAL-REFERENCE.md#what-has-been-verified) and the [developer guide](TECHNICAL-GUIDE.md). Other reference documents may contain older 1.0 examples; this is the current installation procedure.
