# Field guide — what to enter and why

> **English** | [Türkçe](tr/SCREEN-GUIDE.md) · [Usage routes](WALKTHROUGH.md) · [Overview](../README.md)

Follow the [setup and first-use guide](WALKTHROUGH.md) first. Open this reference when you need to understand a field. SAP menu names can vary by release/session language; project field names are shown below.

<a id="profile"></a>
## Mailbox settings — ZCHE_IMAP_CONFIG

A **profile** stores one set of connection and processing settings. `MAIL_DEMO` is an example name, not a pre-created or required profile.

| Field / group | Purpose | What to enter |
|---|---|---|
| Profile | Name for these settings. | 1–20 characters: A–Z, digits and underscore. Reuse the same name in subsequent screens. |
| Description | Helps identify the profile. | A description such as “Test mailbox”; no password or unnecessary account details. |
| Active | Includes the profile in processing. | Selected for the first trial. Deactivation does not delete history. |
| Server | Mail server to connect to. | Actual IMAP hostname from the administrator; not your email address or SAP hostname. |
| Port | Mail service endpoint. | `993` is a common IMAPS example; use the actual supplied port. |
| Security | Connection encryption. | `IMAPS` or `STARTTLS` to match the port. Do not use an unencrypted connection as a first fix. |
| Verify certificate | Checks the identity and trust of the remote server. | **Keep selected.** Resolve hostname/certificate trust errors. |
| User | Mailbox sign-in name. | Actual login from the administrator; it may differ from the email address. |
| Password source | How the password is supplied. | Default `O`: administrator prepares it on the host. To enter it in SAP, type `S` and press Enter to show the password field. |
| Password | New password for source `S`. | Blank/disabled for `O`. Saved passwords are not read back; do not include them in screenshots or variants. |
| Folder to read | Source mail folder. | Default `INBOX`, or the actual IMAP name of another folder. |
| Processed folder | Destination for successful mail. | **A different existing folder** in the same account. `SAP-Processed` is only an initial example. |
| Move method | Action after successful processing. | `MOVE`; the server must support UID MOVE. COPY is unsupported. |
| Handler program | ABAP business program called for each mail. | Start with `ZCHE_IMAP_HANDLER_DEMO`. See [developer guide](TECHNICAL-GUIDE.md) for custom code. |
| Handler FORM | Entry point in that program. | `HANDLE_MAIL` for the demo. |
| Mails per run | Upper processing limit per execution. | Starts at `50`; begin with a small dedicated mailbox. |
| Max mail size (MB) | Per-message size limit. | Starts at `20` MiB; host policy may impose a lower limit. |
| Timeout | Limit for a network call. | Starts at `120` seconds; not the whole job duration. |
| Retention | Completed local archive retention. | Starts at `30` days; does not delete SAP logs or remote destination mail. |

Folder names accept English letters, digits and `. _ / -`, without spaces or non-ASCII characters. Use the actual IMAP folder name rather than a translated Outlook label.

### Buttons

- **Load profile:** loads saved settings, never the stored password.
- **Save:** validates and saves settings; saving alone does not prove connectivity.
- **F8:** saves, then checks the connection.
- **Profiles:** selects an existing profile.
- **Delete:** profile deletion, not trial/reprocessing. Profiles with mail history cannot be deleted; deactivate them instead.

Passwords are plain-text files protected by access permissions, not an encrypted vault. [Credential sources and file permissions](../SECURITY.md).

<a id="processing"></a>
## Listing and processing — ZCHE_IMAP_INBOUND

| Field | Decision |
|---|---|
| Profile selection | Enter only your dedicated test profile. Empty includes all active profiles. |
| List only (no downloads/changes) | **Selected:** lists eligible identifiers. **Cleared:** downloads content, calls the handler and moves successful mail. Do not assume it is selected initially. |
| Retry failed mails | Leave cleared initially. After resolving an error, explicitly include earlier `E` records in retries, subject to the default three-failure cap. |

**List only is not a body preview.** Use a dedicated test message and [normal processing](WALKTHROUGH.md#first-mail) to view content.

<a id="monitor"></a>
## Viewing results — ZCHE_IMAP_MONITOR

| Field / action | What to do |
|---|---|
| Profile | Select the profile you ran. |
| Status | Leave empty initially to include all statuses. |
| Date | Include the run date; initial selection covers the last 30 days. |
| Display limit | At most `1000` rows. Narrow profile/date selections to find older mail. |
| Double-click mail | Opens headers, body and attachment details. |
| Double-click attachment | Downloads to your PC; allowed PDF/text/image types may open in an associated viewer. |
| Original mail | Downloads the original `mail.eml` without opening it automatically. |

Display text may substitute `?` for characters unavailable in the SAP codepage; original EML bytes are preserved. Log records can remain after local payload retention has expired.

<a id="errors"></a>
## Which recovery route should you use?

| Situation | Next action |
|---|---|
| Sign-in failure | Check login, authentication method and IMAP permission with the mail administrator. Keep passwords out of support messages. |
| Connection/certificate error | Check access from the SAP host, actual hostname and trust; keep verification enabled. |
| Authorization / SXPG1 | Check the [role matrix](../SECURITY.md). Connection checks require `S_LOG_COM → ZCHE_IMAP_TEST`. |
| `E` — Error | Resolve the logged cause, then select an authorized retry route. |
| `H` — To move | Business result already committed; normal processing attempts movement recovery. Do not force another handler call. |
| `R` — Retry | An authorized user requested reprocessing; the next normal run may retry. |

Monitor **Reprocess** changes `E` to `R` and permits another attempt even after the cap. Confirm your business code prevents duplicate document creation. The supplied demo intentionally fails if the subject contains `TEST-ERROR`; selecting retry does not change that rule.

<a id="job"></a>
## Variants and jobs — SM36 / SM37

A variant stores profile, List only and retry selections. Use a **List only selected** variant for the first job; use a separate variant with the option cleared for normal processing.

In SM36, **Job Name** identifies the job, **Target** is the installation's SAP host, **Step** defines program/variant/user, and **Start condition** defines timing. In SM37, locate your job and read **Job log** and **Spool**. Finished alone does not prove successful mail processing.

[Step-by-step job route](WALKTHROUGH.md#daily-use).
