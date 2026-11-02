* Project: abap-imap-inbound
*---------------------------------------------------------------
* ZCHE_IMAP_HANDLER_DEMO - sample business logic (subroutine pool)
*
* For a new handler, copy this program (for example
* ZCHE_IMAP_HANDLER_INVOICE) and enter it in the "Handler program"
* field of the profile in ZCHE_IMAP_CONFIG. Keep the FORM interface.
*
* is_mail : profile, UID, sender, recipient, subject, date, folder
* it_body : plain text body (ZCHE_IMAP_S_LINE)
* it_att  : attachments (ZCHE_IMAP_S_ATT); path is the full file path.
*           For binary content use the form READ_BINARY_FILE.
*           disp = 'inline' is usually a signature image.
*
* cv_ok = 'X' : success; the mail is moved to the processed folder.
* cv_ok = ' ' : error; cv_msg is written to ZCHE_IMAP_LOG, the mail
*               stays in the mailbox and can be reprocessed from
*               ZCHE_IMAP_MONITOR.
*
* The processor uses local V1 update tasks and commits H together
* with business changes. Do not COMMIT/ROLLBACK WORK in a handler.
* Do not call RFC or transactions that implicitly commit the LUW.
* A failed local update aborts the LUW before the mail is moved.
* Keep external/nontransactional effects independently idempotent.
*
* Demo behavior: a mail with TEST-ERROR in the subject fails on
* purpose (to try the error scenario).
*---------------------------------------------------------------
PROGRAM zche_imap_handler_demo.

INCLUDE zche_imap_common.

*---------------------------------------------------------------
FORM handle_mail USING    is_mail TYPE zche_imap_s_mail
                          it_body TYPE STANDARD TABLE
                          it_att  TYPE STANDARD TABLE
                 CHANGING cv_ok   TYPE c
                          cv_msg  TYPE c.
  DATA: ls_att   TYPE zche_imap_s_att,
        lt_bin   TYPE ty_t_bin,
        lv_len   TYPE i,
        lv_ok(1) TYPE c.

  CLEAR: cv_ok, cv_msg.

  IF is_mail-subject CS 'TEST-ERROR'.
    cv_msg = 'Deliberate test error (subject contains TEST-ERROR)'.
    EXIT.
  ENDIF.

* Sample: reads the attachments and writes their sizes. Replace
* with real business logic (create a document, attach to GOS..).
  LOOP AT it_att INTO ls_att.
    PERFORM read_binary_file USING    ls_att-path
                             CHANGING lt_bin lv_len lv_ok.
    IF lv_ok IS INITIAL.
      CONCATENATE 'Could not read attachment:' ls_att-name
        INTO cv_msg SEPARATED BY space.
      EXIT.
    ENDIF.
    WRITE: / '    Att:', ls_att-name(60), lv_len, 'bytes'.
  ENDLOOP.
  IF NOT cv_msg IS INITIAL.
    EXIT.
  ENDIF.

  cv_ok = 'X'.
ENDFORM.
