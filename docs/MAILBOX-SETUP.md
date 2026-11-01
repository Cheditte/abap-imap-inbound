# Mailbox setup (for the mail team)
> **English** | [Türkçe](tr/MAILBOX-SETUP.md)

abap-imap-inbound reads one or more mailboxes over IMAP and moves each processed mail into a separate folder. It needs an ordinary mail account with IMAP access. This page lists what to request from the mail team and how to set it up on common servers.

## 1. What kind of account

In plain words: **the mail account whose incoming mail SAP should read and process.** If suppliers send invoices to `invoices@example.com`, that is the account you set up here. Use a **dedicated mailbox for the process**, not a person's mailbox. For example `invoices@example.com` for supplier invoices, `orders@example.com` for order confirmations. One mailbox becomes one profile in `ZIMAP_CONFIG`; each profile can run its own business logic.

Why dedicated:
- SAP processes **every** mail in the folder it reads. Personal mail would end up there too.
- The password belongs to the process, not to a person who may leave.
- Permissions and retention can be set for exactly this purpose.

Senders can write to the address directly, or a forwarding / transport rule on the mail server can copy specific mail into it.

## 2. What the account needs

| Need | Details |
|---|---|
| **IMAP enabled** | Over TLS: IMAPS on port 993 (preferred) or STARTTLS on 143. |
| **Login with user name and password** | This version does not support OAuth. The user name is usually the mail address or the login name the server expects. |
| **ASCII password** | Letters, digits and common symbols. Non-ASCII characters (for example `ş`, `ä`) are not standard in the IMAP `LOGIN` command and may fail. |
| **Password policy** | Either no expiry, or an agreed routine to update it in `ZIMAP_CONFIG` before it expires. An expired password stops processing with an `AUTH` error. |
| **Two folders** | The folder to read (usually `INBOX`) and the processed folder (default name `SAP-Processed`). **Create the processed folder** in the mailbox; the connection test checks that it exists. |
| **Rights** | Read mail, set flags, move or copy mail into the processed folder, delete from the inbox. A normal owner login has all of these. |
| **Size limit** | Consider the largest attachment you expect. Profiles also have their own maximum mail size (default 20 MB). |

From the network side: the machine SAP is installed on (the SAP application server) must reach the mail server on the IMAP port, and it must trust the server's certificate (see [SERVER-SETUP.md](SERVER-SETUP.md#4-policypsd1-your-limits), `CaCert`).

## 3. Request template

You can send this to the mail team:

> We need a mailbox for automated processing in SAP.
>
> - Address: `invoices@example.com` (shared/functional mailbox, not a personal one)
> - Access: IMAP over TLS (IMAPS 993, or STARTTLS 143), login with user name and password
> - Password: ASCII characters only; no expiry, or tell us the expiry date in advance
> - Folders: `INBOX` and a new folder `SAP-Processed`
> - Access from: the machine(s) SAP is installed on `<host names / IP addresses>`
> - Please tell us: server name, port, login name format, and which CA signed the server certificate
>
> SAP reads new mail every few minutes, processes it and moves it to `SAP-Processed`. Nothing is sent from this mailbox.

## 4. Notes for common servers

These are general pointers; check them against your server's documentation.

**Microsoft Exchange Server (on-premise)**
- The IMAP4 services are not started by default. Start the *Microsoft Exchange IMAP4* and *Microsoft Exchange IMAP4 Backend* services and set them to automatic.
- IMAP must be allowed for the mailbox, for example `Set-CASMailbox invoices -ImapEnabled $true`.
- Configure the IMAP certificate and the login type (plain text over TLS) with `Set-ImapSettings`.
- If the server does not support the IMAP `MOVE` command, set **Move method = COPY** in the profile (copy, then delete). Real Exchange servers have not been tested yet.

**Microsoft 365 / Exchange Online**
- Password login for IMAP is switched off by Microsoft; only OAuth works. This version **does not support OAuth**, so it cannot read Microsoft 365 mailboxes. Use Microsoft Graph for those.

**Gmail / Google Workspace**
- Google requires OAuth or app-specific passwords for IMAP. Not tested with this project; Gmail API is the more suitable path.

**Dovecot, Zimbra, hosting providers and other IMAP servers**
- Usually work with a normal mail account: IMAP over TLS, user name and password. The test environment of this project uses GreenMail.

## 5. Check

When the account is ready, the SAP administrator enters it in `ZIMAP_CONFIG` and presses F8. A successful test looks like this:

```
OK  PROFILE    mail.example.com:993 IMAPS user invoices@example.com
OK  DNS        10.0.0.25
OK  PORT       993
OK  LOGIN
OK  INBOX      INBOX: 3 mails
OK  PROCESSED  SAP-Processed
Connection successful. Profile is ready to use.
```

If a step fails, the screen shows the reason and the next step (for example wrong password, folder missing, certificate not trusted).
