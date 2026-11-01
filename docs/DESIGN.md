# abap-imap-inbound: end-to-end design
> **English** | [Türkçe](tr/DESIGN.md)

> **Background reference:** detailed examples below may describe 1.0 behavior. Use the current [walkthrough](WALKTHROUGH.md) and [developer guide](TECHNICAL-GUIDE.md) for 1.1.0 installation, file identity and handler transaction rules.

This document describes the whole life cycle, from installation to removal. What has actually been tested is listed in the [README](../README.md#what-has-been-verified).

**Background.** This project polls an existing IMAP mailbox. It lets the SAP application server's operating system handle IMAP and MIME through a controlled SM69 command, while SAP keeps the settings, business logic and monitoring. SAPconnect's native SMTP inbound route and other integration approaches serve different requirements; choose according to the mail setup and landscape. The plain-language explanation is in the [README](../README.md#why-read-an-existing-mailbox).

Two principles come before every decision:

1. **Easy to use.** Every role does its job in one place with as few steps as possible. Error messages say what to do.
2. **Runs on every release.** ABAP 4.6C syntax, lines of at most 72 characters, ASCII only. Everything that depends on the release is checked at runtime.

---

## 1. Roles

| Role | Does what | Where | Effort |
|---|---|---|---|
| **Basis** | Copies the script to the server, runs the setup script, decides which mail servers are allowed | Server: `setup-server.ps1` (Windows) / `setup-server.sh` (Linux) | ~10 min, once |
| **Developer** | Runs `ZIMAP_INSTALL`; writes the business logic (handler) | SE38 | Install ~2 min; handler depends on the job |
| **Administrator** (IT / functional) | Defines mailbox profiles, enters passwords, tests the connection, enables or disables profiles | `ZIMAP_CONFIG` | ~3 min per profile |
| **Operations** | Watches processed and failed mails, reprocesses failed ones | `ZIMAP_MONITOR` | Daily check |
| **Auditor** | Sees who changed what and when | `ZIMAP_PROFILE` change fields, `ZIMAP_LOG` | — |

---

## 2. Architecture

```
                 SAP                                      Application server (Windows / Linux)
┌───────────────────────────────────┐          ┌──────────────────────────────────────────┐
│ ZIMAP_CONFIG  profile + password ─┼─writes─▶ │ conf/<PROFILE>.conf    (settings)        │
│                                   │          │ secret/<PROFILE>.cred  (user/password)   │
│ ZIMAP_INBOUND (job)               │          │                                          │
│   SM69: ZIMAP_LIST  <PROFILE>     │─SXPG───▶ │ bin/imap.ps1  ── curl ──▶ IMAP server    │
│         ZIMAP_FETCH <PROFILE> <UID>          │ bin/policy.psd1 (Basis: allowed servers) │
│         ZIMAP_DONE  <PROFILE> <UID>          │                                          │
│   reads files ◀───────────────────┼──────────│ in/<PROFILE>/<UID>/  header body att ... │
│   PERFORM handler IN PROGRAM      │          │ done/<PROFILE>/...   log/                │
│   ZIMAP_LOG                       │          └──────────────────────────────────────────┘
│ ZIMAP_MONITOR  monitor / reprocess│
└───────────────────────────────────┘
```

**Why this split:**
- MIME parsing happens on the OS side, because old ABAP releases lack the tools for it.
- SAP owns the settings; the administrator changes them without going to Basis.
- Basis draws the security boundary: SAP cannot decide on its own which servers it connects to.

---

## 3. Server side

### 3.1 Folders and permissions
| Folder | Content | SAP service account |
|---|---|---|
| `bin` | `imap.ps1`, `policy.psd1` | read + execute (cannot change) |
| `conf` | profile settings (written by SAP) | modify |
| `secret` | profile credentials (written by SAP) | modify; on Windows other users cannot read |
| `in`, `done`, `tmp`, `log` | working files | modify |

`setup-server.ps1` / `setup-server.sh` create these folders, set permissions, check curl and write `policy.psd1`. Basis does not need to type `icacls` by hand.

### 3.2 `policy.psd1`: the Basis boundary
```powershell
@{
    AllowedHosts     = @('mail.example.com')   # only these servers can be reached
    AllowInsecure    = $false                  # certificate checks cannot be turned off
    AllowPlainImap   = $false                  # no unencrypted IMAP on 143
    MaxMailBytes     = 52428800                # profiles cannot exceed this
    RetentionDaysMax = 365
}
```
A profile in SAP cannot go beyond these limits. If it tries, the script returns `ERR POLICY ...` and the configuration screen shows a readable message.

### 3.3 Script protocol
| Command | Parameters | Output |
|---|---|---|
| `list` | `<PROFILE>` | `UIDVALIDITY n`, `UID n`..., `OK` |
| `fetch` | `<PROFILE> <UID>` | `OK` (files in `in/<PROFILE>/<UID>/`) |
| `done` | `<PROFILE> <UID> <UIDVALIDITY>` | `OK` |
| `test` | `<PROFILE>` | step-by-step diagnosis (DNS, port, TLS, login, folders), `OK` |

- Profile names must match `^[A-Z0-9_]{1,20}$` and UIDs `^\d{1,10}$`; anything else is rejected.
- The password is never on curl's command line; the script passes it on curl's standard input. It does not appear in the process list.
- Settings and credential files are read only as `KEY=VALUE`; they are never passed to curl as options. A value written into a file cannot inject an extra curl option.
- Error codes are fixed and documented: `ARG`, `CFG`, `POLICY`, `CONNECT`, `TLS`, `AUTH`, `MAILBOX`, `NOMAIL`, `SIZE`, `EXC`. The SAP side turns them into readable text with a hint.

---

## 4. SAP side

### 4.1 DDIC (all created by `ZIMAP_INSTALL`)
| Object | Type | Purpose |
|---|---|---|
| `ZIMAP_PARAM` | table | installation settings (server root folder, file code page) |
| `ZIMAP_PROFILE` | table | mailbox profiles |
| `ZIMAP_LOG` | table | status per mail (key: client, profile, UIDVALIDITY, UID) |
| `ZIMAP_S_MAIL`, `ZIMAP_S_ATT`, `ZIMAP_S_LINE` | structures | handler interface (in DDIC so other programs can use them) |
| `ZIMAP_*` | domains / data elements | own types only; the single exception is `MANDT` |

**`ZIMAP_PROFILE` fields:**
- **Identity:** profile ID, description, active flag
- **Connection:** server, port, security (`IMAPS` / `STARTTLS` / `NONE`), certificate check
- **Credentials:** user name; password source (`S` = entered in SAP, `O` = kept on the server by Basis); date and user of the last password change. **The password itself is not in the table.**
- **Mailbox:** inbox folder, processed folder, move method (`MOVE` / `COPY+DELETE`)
- **Processing:** handler program and form, maximum mails per run, maximum mail size, timeout, retention period
- **Changes:** created/changed by and when (for audit)

### 4.2 Programs
| Program | Does what |
|---|---|
| `ZIMAP_INSTALL` | One program that installs and updates everything. Carries a version number; running it again adds missing fields to the tables. Overwrites programs only when "overwrite" is selected. |
| `ZIMAP_CONFIG` | Profile maintenance: load, save, delete, list. **Password** (hidden while typing; not written to the table but to the file on the server). **Connection test** with a step-by-step result and a hint. |
| `ZIMAP_INBOUND` | The processor; runs as a job. One profile or all active profiles. Test mode. A mail is never processed twice (status `H` → `S`). |
| `ZIMAP_MONITOR` | Lists log entries by profile, status and date. Shows mail details (headers, body, attachments) and opens attachments on the PC. Sends failed mails to reprocessing. |
| `ZIMAP_HANDLER_DEMO` | Example handler (subroutine pool). New handlers are copied from it. |

### 4.3 Handler interface
Each profile names its handler; the processor calls it with `PERFORM (form) IN PROGRAM (prog)`:
```abap
FORM handle_mail USING    is_mail TYPE zimap_s_mail
                          it_body TYPE STANDARD TABLE   " ZIMAP_S_LINE
                          it_att  TYPE STANDARD TABLE   " ZIMAP_S_ATT
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
```
- The handler does not `COMMIT WORK`. The processor commits on success and rolls back on failure.
- A helper form reads attachments as binary data.

### 4.4 Authorizations
| Role | Object | Value |
|---|---|---|
| Processor (job user) | `S_LOG_COM` | `ZIMAP_LIST`, `ZIMAP_FETCH`, `ZIMAP_DONE` |
| Processor (job user) | `S_DATASET` | `ZIMAP_INBOUND`, read, `…/in/*` |
| Administrator | `S_DATASET` | `ZIMAP_CONFIG`, **write only**, `…/conf/*`, `…/secret/*` |
| Administrator | `S_LOG_COM` | `ZIMAP_TEST` (connection test) |
| Administrator | `S_TABU_DIS` / program authorization group | maintenance of `ZIMAP_PROFILE` |

The administrator can write the password but cannot read it back from SAP.

---

## 5. User journeys

### 5.1 First installation (about 15 minutes)
1. **Basis:** unpacks the release on the server and runs `setup-server.ps1 -AllowedHosts mail.example.com`. The script prepares folders, permissions and the policy file and checks curl.
2. **Developer:** creates `ZIMAP_INSTALL` in SE38, pastes it, F8. The program installs the DDIC objects, programs and SM69 commands, then tests itself.
3. **Administrator:** `ZIMAP_CONFIG`: enters server, user, folders and password, F8 → the connection test passes.
4. **Basis / developer:** schedules `ZIMAP_INBOUND` as a periodic job in SM36.

### 5.2 Password changed
Administrator → `ZIMAP_CONFIG` → profile → new password → F8. No Basis needed.

### 5.3 New mailbox
Administrator → loads an existing profile, saves it under a new name, changes server, user, folder and handler → test.

### 5.4 A mail failed
1. Operations sees the red line in `ZIMAP_MONITOR` and opens the mail.
2. The error text says what to do, for example *"Handler error: vendor not found (4500012345)"*.
3. They fix the cause and choose **reprocess**.

### 5.5 Update
- Run the new `ZIMAP_INSTALL` with "overwrite".
- Only missing fields are added to tables; data is kept.
- Basis replaces the script in `bin` with the new version.
- Both carry the same version number; the connection test reports a mismatch.

### 5.6 Removal
`ZIMAP_INSTALL` → remove option deletes the objects it created. Basis deletes the server folders.

---

## 6. Error messages: from technical code to next step

| Code | Meaning | Next step |
|---|---|---|
| `AUTH` (curl 67) | Wrong user name or password | `ZIMAP_CONFIG` → enter password |
| `CONNECT` (curl 6/7/28) | Mail server not reachable | Server name/port; firewall (Basis) |
| `TLS` (curl 35/60) | Certificate could not be verified | Install the company CA on the server (Basis) |
| `POLICY` | Connecting to this server is not allowed | Basis: `policy.psd1` → `AllowedHosts` |
| `MAILBOX` | Folder not found | Check folder names in the profile |
| `CFG` | Profile file missing or broken | `ZIMAP_CONFIG` → save the profile |
| SXPG code 2 | SM69 command not found | Run `ZIMAP_INSTALL` again |
| SXPG code 1 | No authorization (`S_LOG_COM`) | Role authorizations |

---

## 7. Security summary
- **The password is not stored in the SAP database.** On the server it is in a file only the SAP service account can read. It cannot be read back from SAP.
- **Reachable servers are limited to the Basis list.** SAP authorizations cannot be used to send data to arbitrary servers.
- **Scripts cannot be changed** by the SAP service account.
- **Every incoming value is validated.** No value typed in SAP reaches curl as an option.
- **Mail content is untrusted data.** Attachments are never executed. Size and count limits apply.
- **Retention of personal data** is set per profile (GDPR and similar regulations).

---

## 8. Compatibility

| Topic | Approach |
|---|---|
| ABAP 4.6C – 7.5x | Old syntax, 72 columns, ASCII; newer features are checked at runtime |
| Unicode / non-Unicode | The installer detects it and installs the matching file I/O include |
| Windows / Linux | Same script: Windows PowerShell 5.1 or PowerShell 7 |
| Missing SAP function module | The installer does not stop; it explains the manual step |

---

## 9. Test strategy
| Layer | How | Status |
|---|---|---|
| Parser | `test/run-tests.ps1` (Windows 5.1 + Linux 7) | done |
| IMAP flow, policy and validation | `test/run-imap-tests.ps1` against GreenMail: disallowed server, bad profile name, option injection, wrong password, missing folder | done |
| ABAP syntax | ADT check run on the trial system | done |
| End-to-end SAP | Trial system: install, profile, connection test, job, monitor, attachments | done (Linux, Unicode) |
| Old releases | A real 4.6C / 6.x / 7.0 system | **not verified**; community feedback welcome |
