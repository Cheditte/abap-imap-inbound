# Developer guide: connect your ABAP business logic

> **English** | [Türkçe](tr/TECHNICAL-GUIDE.md) · [README](../README.md) · [Installation walkthrough](WALKTHROUGH.md)

This section is for the developer implementing the business action after a consultant has tested the mailbox flow. Configuration and daily use do not require writing this code; use the walkthrough for those tasks.

The current integration point is a **handler program with a `FORM`**, rather than a public ABAP class. You can call your own classes from inside that handler, provided they respect the transaction contract below.

## 1. Start from the supplied handler

1. Complete a demonstration run using `ZIMAP_HANDLER_DEMO` in a test mailbox.
2. In **SE38**, copy that installed program to a customer name such as `ZIMAP_HANDLER_CUSTOM`. Keep its program type **subroutine pool** and assign your transportable customer package.
3. Keep `INCLUDE zimap_common`, `INCLUDE zimap_io` and the `HANDLE_MAIL` interface. The installer selects the appropriate implementation of `ZIMAP_IO` for the SAP system.
4. In `ZIMAP_CONFIG`, enter your program in **Handler program** and `HANDLE_MAIL` in **Handler FORM**. Save and check the connection result.
5. Test with an authorized job user and inspect the monitor before scheduling business processing.

The installer contains the demonstration handler, not your custom copy. Keep custom business code in its own program/package and include it in your transport. See [package and transport](WALKTHROUGH.md#2b-before-production-package-and-transport).

## 2. Understand the inputs and result

`ZIMAP_HANDLER_CUSTOM` is an example name for the program you create. If you choose another, use it consistently in SE38, the example's `PROGRAM` statement and the profile's handler field. Keep the installed include names and the `HANDLE_MAIL` interface as shown.

The processor dynamically calls this exact interface once for each eligible mail needing business processing:

```abap
FORM handle_mail USING    is_mail TYPE zimap_s_mail
                          it_body TYPE STANDARD TABLE
                          it_att  TYPE STANDARD TABLE
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
```

| Parameter | Contents / responsibility |
|---|---|
| `is_mail` | `ZIMAP_S_MAIL`: profile, UIDVALIDITY, UID, sender, recipient, copy recipients, subject, date, Message-ID, working directory and attachment count. Treat it as input. |
| `it_body` | Rows of `ZIMAP_S_LINE`, text in `TEXT`. Plain-text body, or HTML converted to text when no plain body is available. |
| `it_att` | Rows of `ZIMAP_S_ATT`: local `PATH`, safe `NAME`, original `ORIG`, byte size `ATTSIZE`, MIME type and disposition `DISP`. |
| `cv_ok` | Set to exactly `'X'` only when your action succeeded. Any other value is failure. |
| `cv_msg` | On failure, return a useful message, up to the caller's 255-character buffer. Avoid secrets and unnecessary personal data. |

Use `PATH` as the server-side attachment path supplied by the processor. Do not rebuild a path from the sender's original filename. An `inline` disposition often indicates a signature image; decide explicitly which attachments your process accepts. Sender, subject, MIME type and filename are untrusted mail content, not proof of identity or file safety.

## 3. A minimal attachment-reading example

This complete subroutine pool checks that at least one non-inline PDF can be read. It is a **learning example**, not invoice validation, malware scanning or document creation. A declared MIME type does not prove that a file is a valid PDF.

```abap
PROGRAM zimap_handler_custom.

INCLUDE zimap_common.
INCLUDE zimap_io.

FORM handle_mail USING    is_mail TYPE zimap_s_mail
                          it_body TYPE STANDARD TABLE
                          it_att  TYPE STANDARD TABLE
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
  DATA: ls_att   TYPE zimap_s_att,
        lt_bin   TYPE ty_t_bin,
        lv_len   TYPE i,
        lv_ok(1) TYPE c,
        lv_count TYPE i.

  CLEAR: cv_ok, cv_msg, lv_count.
  LOOP AT it_att INTO ls_att.
    IF ls_att-disp = 'inline'.
      CONTINUE.
    ENDIF.
    IF ls_att-mime <> 'application/pdf'.
      CONTINUE.
    ENDIF.
    PERFORM read_binary_file USING ls_att-path
      CHANGING lt_bin lv_len lv_ok.
    IF lv_ok IS INITIAL OR lv_len = 0.
      cv_msg = 'PDF attachment could not be read or is empty'.
      EXIT.
    ENDIF.
*   Add validated business processing here. Do not commit.
    lv_count = lv_count + 1.
  ENDLOOP.
  IF NOT cv_msg IS INITIAL.
    EXIT.
  ENDIF.
  IF lv_count = 0.
    cv_msg = 'No readable non-inline PDF attachment found'.
    EXIT.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.
```

`READ_BINARY_FILE` returns `ty_t_bin`: rows containing **1,024 bytes**, plus `lv_len`, the actual byte count. The last row can be padded. Use the actual length when converting/saving/attaching content, and adapt the row format to the destination API; do not pass 1,024-byte rows directly to an API requiring another structure. A successful read can return zero bytes, so the example checks that separately.

Before setting `cv_ok = 'X'` in a real handler, validate the sender/business context and document content, apply duplicate checks, call the approved business API, and inspect its return values. A completed demonstration run does not validate those business rules.

## 4. Transaction contract: the processor owns the commit

`ZIMAP_INBOUND` activates **local V1 update** before calling the handler. On handler success it writes status `H` and performs `COMMIT WORK AND WAIT`; compatible business database changes and local V1 updates belong to that same database LUW. On a returned failure, it rolls back before writing the error status.

Your handler and every API it calls must respect this contract:

- Do not issue `COMMIT WORK`, `ROLLBACK WORK`, `BAPI_TRANSACTION_COMMIT` or `BAPI_TRANSACTION_ROLLBACK`.
- Do not call RFCs, transactions, reports or APIs that commit/end the LUW implicitly. Check the chosen API on your target SAP release.
- Do not treat V2/background/asynchronous work as atomically completed with status `H`. Design a separate confirmation/reconciliation process if that work is part of the business outcome.
- Keep external or other nontransactional effects independently idempotent. A sent HTTP request, email or external file cannot be undone by rolling back the SAP database.
- Return errors through `cv_ok` and `cv_msg`; avoid interactive dialogs in background processing. Review dumps/update failures through the normal SAP operational tools too.

This is not an unconditional exactly-once guarantee. The transaction protection depends on the handler, its APIs and target-system behavior. Test an actual failing local update in SAP before using it for business documents.

## 5. Retries and duplicate protection

| State / trigger | What the processor does |
|---|---|
| New eligible message | Fetches/parses it and calls the configured handler. |
| Handler returns failure | Rolls back the business LUW and records `E`. Normal runs skip it until retry is requested. |
| Monitor retry | Marks `E` as `R`; a normal run can call the handler again. The processor's explicit retry option can also include `E`. |
| Handler success committed | Records `H` before attempting remote movement. |
| Move fails / process stops after `H` | Keeps movement pending and resumes through the normal processor, including when the original UID is no longer in the inbox. It does not intentionally rerun the completed handler. |
| Move/archive completion | Records `S`. |

SAP log identity is the current system/client's **profile + UIDVALIDITY + UID**. Server storage is additionally scoped by SID/client/profile and bound to the configured mailbox identity. Do not use a UID alone as a global duplicate key. A forwarded or resent business document can have a new mail identity: use a business key, such as a validated supplier/document reference, for duplicate protection in your own process. `Message-ID` alone is not a reliable business uniqueness rule.

Do not edit/delete log records or cached files to force reruns. A profile with history cannot be rebound to another mailbox or deleted; deactivate it and create a new profile instead.

## 6. Start processing from another program

The usual entry point is a separately scheduled `ZIMAP_INBOUND` background job. For a foreground test in a **clean transaction context**, a report can submit the processor:

The example report below asks for a profile in `P_PROF`. Enter the name actually saved in `ZIMAP_CONFIG`; there is no fixed `INVOICE` profile. `ZIMAP_START_DEMO` is a suggested report name; if you choose another, make its SE38 name and `REPORT` statement match.

```abap
REPORT zimap_start_demo.

PARAMETERS p_prof LIKE zimap_profile-profile OBLIGATORY.

START-OF-SELECTION.
SUBMIT zimap_inbound
  WITH s_prof EQ p_prof
  WITH p_test EQ 'X'
  AND RETURN.
```

This example only lists eligible UIDs. Clear `p_test` for an intentional normal processing run. **`AND RETURN` does not create an independent database LUW.** The normal processor commits and rolls back; do not submit it from an open business transaction with uncommitted changes. Use an independent job/session when integrating with another application.

## 7. Files, roles and deployment

- Profile key example: `A4H_001_INVOICE`. SAP publishes `conf/KEY_REVISION.conf`; source `S` references `secret/KEY_CREDREV.cred`, while source `O` uses `secret/KEY.cred`. Do not hand-edit revision numbers or credential pointers.
- `bin` contains `imap.ps1`, `mime.ps1` and Basis-owned `policy.psd1`. SAP must not have write access to executable/policy files. Credential files contain plain text protected by OS permissions.
- Input/archive data lives under the chosen root in scoped mail directories. Do not hard-code that root in the handler; use supplied paths and shared helpers.
- Install SAP objects and both server modules as a matching protocol-2 set. For upgrades and pending old archives, follow the [upgrade procedure](WALKTHROUGH.md#8-update-an-existing-installation).
- Processing, configuration and monitoring are pinned to one application-server host. Include the new handler program in the appropriate `S_DATASET` and business authorization design. See the [role outline](../README.md#access-and-operating-boundaries).

The source avoids modern ABAP syntax, uses ASCII and limits ABAP source to 72 columns. Compatibility with older SAP is a target, not a verified release certification. Keep additions compatible and compile on the actual target system.

## 8. Acceptance checks for your handler

Use a disposable mailbox and your target SAP system. Confirm normal success, missing/invalid attachments, a returned business error with rollback, a failing local V1 update, an authorized retry, and a movement failure after committed handler success. Confirm recovery does not duplicate the business action. Run the scheduled variant with the intended restricted job user on the selected host.

Source/parser/IMAP tests are run manually; see [CONTRIBUTING.md](../CONTRIBUTING.md). They do not execute your business API or replace SAP compiler/runtime acceptance tests. Current project verification limits are in the [README](../README.md#what-has-been-verified).
