# Server setup (for Basis)
> **English** | [Türkçe](tr/SERVER-SETUP.md)

> **Historical reference:** this page contains 1.0 examples. For current 1.1.0 paths, both script modules, scoped credentials and permissions, follow the [Basis section of the walkthrough](WALKTHROUGH.md#0-prepare-the-server-basis). Do not use the older commands below as the current installation procedure.

SAP itself never talks to the mail server. A small PowerShell script on the **machine SAP is installed on** (in SAP terms, the *application server*) does: SAP starts it through SM69 commands, the script talks IMAP with `curl`, and leaves each mail as plain files that SAP reads. This page explains where the script goes, which account needs which permissions, and what to check.

The mailbox side (what to ask the mail team for) is in [MAILBOX-SETUP.md](MAILBOX-SETUP.md).

```
SAP work process (runs as the SAP OS user)
  │  SM69: ZIMAP_LIST / ZIMAP_FETCH / ZIMAP_DONE / ZIMAP_TEST
  ▼
<root>/bin/imap.ps1 ── curl ── IMAPS ──▶ mail server
  │ reads  <root>/bin/policy.psd1      (your limits)
  │ reads  <root>/conf/<PROFILE>.conf  (written by ZIMAP_CONFIG)
  │ reads  <root>/secret/<PROFILE>.cred
  └ writes <root>/in/<PROFILE>/<UID>/  (mail as files, read by SAP)
```

## 1. Requirements

| | Windows application server | Linux application server |
|---|---|---|
| PowerShell | Windows PowerShell 5.1 (included in Windows Server 2016 and later) | PowerShell 7 (`pwsh`) at `/usr/bin/pwsh` |
| curl with IMAPS | `C:\Windows\System32\curl.exe` (included in Windows Server 2019 and later) | `/usr/bin/curl` from the distribution |
| Account that runs the script | The account of the SAP service `SAP<SID>_<NN>` (usually `SAPService<SID>` or a domain account) | `<sid>adm` |
| Network | From the application server to the mail server: TCP 993 (IMAPS) or 143 (STARTTLS) | same |

Check curl yourself with `curl --version`: the protocol list must contain `imaps`.

Tested: Windows 11 with Windows PowerShell 5.1 (script tests, and `setup-server.ps1` end to end in a test folder with a simulated SAP account, including a connection test against a local mail server) and Linux with PowerShell 7.4 (full SAP flow). A real SAP system on Windows has not been tested yet.

## 2. Install

Copy the project (this repository or a release zip) to the machine SAP is installed on, then run the setup script **as administrator / root** from the project folder.

**Windows** (elevated PowerShell):
```bat
powershell -ExecutionPolicy Bypass -File server\setup-server.ps1 -AllowedHosts mail.example.com
```

**Linux:**
```bash
sudo bash server/setup-server.sh --sap-user <sid>adm --allowed-hosts mail.example.com
```

| Option (Windows / Linux) | Meaning |
|---|---|
| `-Root` / `--root` | Work folder. Default `C:\sapimap` / `/usr/sap/sapimap`. Enter the same path as **Server folder** in `ZIMAP_INSTALL`. |
| `-AllowedHosts` / `--allowed-hosts` | Mail servers SAP may connect to. Required on first run. This is the **IMAP server name of your company's mail server**, as given by the mail team (see [MAILBOX-SETUP.md](MAILBOX-SETUP.md#3-request-template)); it is also shown in a mail client's account settings as the incoming (IMAP) server. Use the host name, not the IP address: it must be exactly what the administrator enters as **Server** in `ZIMAP_CONFIG`, and it must match the server's certificate. Several: `-AllowedHosts a.example.com,b.example.com` / `--allowed-hosts a.example.com,b.example.com`. Change it later by editing `policy.psd1`. |
| `-SapAccount` / `--sap-user` | Account the SAP work processes run as. Windows detects it from the SAP service; Linux needs it (`<sid>adm`). |
| `-AllowInsecure` / `--allow-insecure` | Allows profiles to switch off the certificate check. Test systems only. |
| `-AllowPlainImap` / `--allow-plain` | Allows unencrypted IMAP. Not recommended. |
| `-Force` / `--force` | Replaces an existing `policy.psd1`. Without it, your existing policy is kept. |
| `-SetPassword <PROFILE>` / `--set-password <PROFILE>` | Only writes the mailbox password for a profile whose password source is `O` (see section 6). |

Output on the demo system:
```
== pwsh and curl check
7.4.6 / curl 7.66.0

== Folders: /usr/sap/sapimap
policy.psd1 written: allowed servers 'greenmail'

== Permissions (SAP user: a4hadm)

== Installation test
  VERSION 1.0.0
  STEP POLICY OK allowed: greenmail
  STEP CURL OK curl 7.66.0
  STEP FOLDERS OK
  OK

Server ready. On the SAP side:
  SE38 > ZIMAP_INSTALL > Server folder: /usr/sap/sapimap/
  Then define the mailbox profile with ZIMAP_CONFIG.
```

Running the script again is safe: it copies the current `imap.ps1`, keeps `policy.psd1` (unless `-Force`) and resets the permissions.

## 3. Folders and permissions

The setup script creates these folders and sets the permissions; you do not need to run `icacls` or `chmod` yourself.

| Folder | Content | SAP account | Windows (ACL) | Linux (owner, mode) |
|---|---|---|---|---|
| `bin` | `imap.ps1`, `policy.psd1` | read and execute, **cannot change** | Administrators, SYSTEM: full; SAP account: read & execute | `root:root`, `755` (files `644`) |
| `conf` | profile settings, written by `ZIMAP_CONFIG` | modify | Administrators, SYSTEM: full; SAP account: modify | `<sid>adm:sapsys`, `750` |
| `secret` | mailbox passwords, written by `ZIMAP_CONFIG` or Basis | modify; **nobody else can read** | Administrators, SYSTEM: full; SAP account: modify; inheritance removed | `<sid>adm:sapsys`, `700` |
| `in` | fetched mail, one folder per mail | modify | as `conf` | `<sid>adm:sapsys`, `750` |
| `done`, `tmp`, `log` | processed mail, temporary files, log | modify | as `conf` | `<sid>adm:sapsys`, `750` |

Why `bin` is read-only for SAP: SAP can run the script but cannot change it, so nobody can use SAP authorizations to run their own code on the server.

## 4. `policy.psd1`: your limits

`bin/policy.psd1` is the boundary that SAP cannot cross. Profiles in `ZIMAP_CONFIG` are checked against it every time the script runs; a profile outside it fails with `ERR POLICY`.

| Key | Meaning |
|---|---|
| `WorkDir` | Work folder (same as the setup `Root`). |
| `AllowedHosts` | The only mail servers that can be reached (lowercase names). |
| `AllowInsecure` | `$true` allows profiles to switch off the certificate check. Keep `$false` in production. |
| `AllowPlainImap` | `$true` allows unencrypted IMAP. Keep `$false`. |
| `CaCert` | Path to your company CA certificate file if the mail server's certificate is signed by an internal CA that the operating system does not trust. Empty: the operating system's certificate store is used. |
| `CheckRevoke` | Windows only: check certificate revocation lists. Usually `$false` in closed networks where the revocation servers cannot be reached. |
| `CurlPath` | Optional: a different curl executable. Default `System32\curl.exe` on Windows, `/usr/bin/curl` on Linux. |
| `MaxMailBytes`, `RetentionDaysMax`, `TimeoutSecMax` | Upper limits for mail size, retention of processed files and the IMAP timeout. Profiles cannot set higher values. |

Edit the file with any text editor; it takes effect on the next run.

## 5. Check from SAP

After `ZIMAP_INSTALL` has created the SM69 commands, you can run the self-test in **SM49**: command `ZIMAP_TEST`, no additional parameters. The last line must be `OK`. With a profile name as additional parameter (`ZIMAP_TEST DEMO`) it tests the connection to that mailbox step by step, the same test `ZIMAP_CONFIG` runs with F8.

The commands `ZIMAP_INSTALL` defines:

| | Windows | Linux |
|---|---|---|
| OS command | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` | `/usr/bin/pwsh` |
| Parameters | `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File <root>\bin\imap.ps1 <action>` | `-NoProfile -NonInteractive -File <root>/bin/imap.ps1 <action>` |
| Additional parameters | allowed (profile, UID) | allowed |

`<action>` is `list`, `fetch`, `done` or `test`. The script checks every additional parameter (profile name, UID) against a strict pattern before using it.

## 6. Passwords

By default the administrator types the mailbox password in `ZIMAP_CONFIG`; SAP writes it to `secret/<PROFILE>.cred` and does not store it in the database. If Basis should own the password instead, set **Password source = O** in the profile and write it on the server:

```bat
powershell -ExecutionPolicy Bypass -File server\setup-server.ps1 -SetPassword INVOICE
```
```bash
sudo bash server/setup-server.sh --sap-user <sid>adm --set-password INVOICE
```

The password is read without echo. It never appears on a command line: the script passes it to curl on standard input.

## 7. Several application servers

The SM69 commands and the file reads run on the application server where the work process runs. `ZIMAP_CONFIG` writes the profile files on the server you are logged on to; the `ZIMAP_INBOUND` job reads them on the server the job runs on. With more than one application server, either

- put the work folder on storage shared by all application servers (mounted at the same path), and install the script once per server; or
- run `ZIMAP_CONFIG` and the `ZIMAP_INBOUND` job on the same server (logon group / job target server).

This setup has not been tested yet; feedback is welcome.

### Several SAP systems or clients on one machine

The files in the work folder are named after the profile only: `conf/INVOICE.conf`, `secret/INVOICE.cred`, `in/INVOICE/...`. The SAP system ID and the client are not part of the name.

- **Several clients in one SAP system** (for example 100 and 200) share the same work folder. Profiles are kept per client in SAP, so both clients could define a profile called `INVOICE`; on the server they would then overwrite each other's settings and password. Give the profiles different names, for example `INVOICE_100` and `INVOICE_200`.
- **Several SAP systems on one machine** (rare; for example a development and a test system on the same server): give each system its own work folder, for example `C:\sapimap\DEV` and `C:\sapimap\QAS`. Run the setup script once per folder (`-Root` / `--root`) and enter the matching **Server folder** in `ZIMAP_INSTALL` on each system.

A later version may add the system ID and client to the file names automatically.

## 8. Update and removal

- **Update:** copy the new project version to the server and run the setup script again. It replaces `bin/imap.ps1` and keeps your `policy.psd1`. Then run the new `ZIMAP_INSTALL` in SAP with **Overwrite existing programs**. The connection test in `ZIMAP_CONFIG` warns if the script and the SAP side have different versions.
- **Removal:** after **Uninstall** in `ZIMAP_INSTALL`, delete the SM69 commands `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE`, `ZIMAP_TEST` and the work folder.

## 9. Troubleshooting

| Message | Cause | What to do |
|---|---|---|
| `ERR CFG curl not found` | No curl at the default path | Install curl, or set `CurlPath` in `policy.psd1` |
| `ERR CFG curl does not support IMAPS` | curl built without IMAP/TLS | Use a curl with `imaps` in `curl --version` |
| `ERR CFG folder missing` / `cannot write to folder` | Setup not run, or permissions changed | Run the setup script again |
| `ERR POLICY server not allowed` | Profile server not in `AllowedHosts` | Add it to `policy.psd1` if it is approved |
| `ERR TLS` | Certificate not trusted | Install the company CA in the OS store, or set `CaCert` |
| `ERR CONNECT` | DNS, firewall or port | Check name resolution and the firewall from the application server |
| SM49 error, exit code from SXPG | Command missing or no `S_LOG_COM` authorization | Run `ZIMAP_INSTALL` again; check the role |
