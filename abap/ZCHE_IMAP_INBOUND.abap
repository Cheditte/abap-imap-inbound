* Project: abap-imap-inbound
*---------------------------------------------------------------
* ZCHE_IMAP_INBOUND - processes the mails in IMAP mailboxes
* Reads the active profiles (ZCHE_IMAP_PROFILE) one by one and passes
* each mail to the handler of the profile. Run as a periodic job.
*
* Statuses (ZCHE_IMAP_LOG-STATUS):
*   H  business logic ran, mail not moved yet
*   S  completed
*   E  error; retry with P_RETRY or ZCHE_IMAP_MONITOR > Reprocess
*   R  to be reprocessed (ZCHE_IMAP_MONITOR)
* A committed H record resumes only the pending move. Handlers must
* honor the LUW contract and deduplicate external business effects.
*
* Classic ABAP 7.00 syntax target.
*---------------------------------------------------------------
REPORT zche_imap_inbound LINE-SIZE 200.

TABLES zche_imap_profile.

INCLUDE zche_imap_common.

SELECT-OPTIONS s_prof FOR zche_imap_profile-profile.
PARAMETERS: p_test  AS CHECKBOX,
            p_retry AS CHECKBOX.

DATA: gv_read TYPE i,
      gv_done TYPE i,
      gv_fail TYPE i,
      gv_skip TYPE i.

START-OF-SELECTION.
  PERFORM main.

*---------------------------------------------------------------
FORM main.
  DATA: lt_prof TYPE STANDARD TABLE OF zche_imap_profile,
        ls_prof TYPE zche_imap_profile,
        lv_ok(1) TYPE c.

  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'S'
                     CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    WRITE: / 'No profile display authorization (S_TABU_DIS).'.
    EXIT.
  ENDIF.
  PERFORM table_auth USING 'ZCHE_IMAP_LOG' 'U' CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    WRITE: / 'No log change authorization (S_TABU_DIS).'.
    EXIT.
  ENDIF.
  PERFORM get_setup CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    WRITE: / 'Setup missing or this is the wrong execution host.',
             'Run ZCHE_IMAP_INSTALL on the selected host.'.
    EXIT.
  ENDIF.

  SELECT * FROM zche_imap_profile INTO TABLE lt_prof
    WHERE profile IN s_prof AND active = 'X'.
  IF sy-subrc <> 0.
    WRITE: / 'No active profile. Define a profile with ZCHE_IMAP_CONFIG.'.
    EXIT.
  ENDIF.

  LOOP AT lt_prof INTO ls_prof.
    PERFORM run_profile USING ls_prof.
  ENDLOOP.

  ULINE.
  IF NOT p_test IS INITIAL.
    WRITE: / 'Test mode. Eligible mails:', gv_read.
  ELSE.
    WRITE: / 'Processed:', gv_done, '  Failed:', gv_fail.
  ENDIF.
* Failed mails stay in the inbox but are not retried every run
  IF gv_skip > 0.
    WRITE: / 'Skipped:  ', gv_skip,
             '  failed earlier; tick "Retry failed mails"',
           / '            or reprocess them in ZCHE_IMAP_MONITOR.'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM run_profile USING is_prof TYPE zche_imap_profile.
  DATA: lt_out      TYPE ty_t_line,
        ls_out      TYPE zche_imap_s_line,
        lt_uid      TYPE ty_t_uid,
        ls_uid      TYPE ty_uid,
        lv_ok(1)    TYPE c,
        lv_msg(255) TYPE c,
        lv_work(1)  TYPE c,
        lv_uidv(20) TYPE c,
        lv_tmp(128)  TYPE c,
        lv_max      TYPE i,
        lv_count    TYPE i,
        lv_key(28)  TYPE c,
        ls_prof     TYPE zche_imap_profile,
        lt_pending  TYPE STANDARD TABLE OF zche_imap_log,
        ls_pending  TYPE zche_imap_log.

  SKIP.
* The description is shown only after the authorization check.
  PERFORM profile_auth USING is_prof-profile '16'
                       CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    WRITE: / 'Not authorized for profile:', is_prof-profile.
    EXIT.
  ENDIF.
  FORMAT COLOR COL_HEADING.
  WRITE: / 'Profile:', is_prof-profile, is_prof-descr(60).
  FORMAT COLOR OFF.

* Configuration and job share this lock across every commit.
  PERFORM profile_lock USING is_prof-profile CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    WRITE: / '  Profile in use or lock unavailable, skipped.'.
    EXIT.
  ENDIF.
* Reload under the lock; the initial selection may be stale.
  SELECT SINGLE * FROM zche_imap_profile INTO ls_prof
    WHERE profile = is_prof-profile AND active = 'X'.
  IF sy-subrc <> 0.
    PERFORM profile_unlock USING is_prof-profile.
    EXIT.
  ENDIF.
  PERFORM storage_key USING ls_prof-profile CHANGING lv_key.
  lv_max = ls_prof-maxmail.
  IF lv_max <= 0.
    lv_max = 50.
  ENDIF.

* Recover H even after a remote MOVE removed the inbox UID.
  IF p_test IS INITIAL.
    SELECT * FROM zche_imap_log INTO TABLE lt_pending
      UP TO lv_max ROWS
      WHERE profile = ls_prof-profile AND status = 'H'
      ORDER BY PRIMARY KEY.
    LOOP AT lt_pending INTO ls_pending.
      PERFORM finish_mail USING ls_prof ls_pending-uidvalidity
                                ls_pending-mailuid.
      lv_count = lv_count + 1.
    ENDLOOP.
  ENDIF.

  PERFORM list_arguments USING lv_key ls_prof-revision p_test
                         CHANGING lv_tmp.
  PERFORM call_cmd USING 'ZCHE_IMAP_LIST' lv_tmp
                   CHANGING lt_out lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    PERFORM write_error USING lv_msg.
  ELSE.
    LOOP AT lt_out INTO ls_out.
      IF ls_out-text(12) = 'UIDVALIDITY '.
        lv_uidv = ls_out-text+12.
        CONDENSE lv_uidv NO-GAPS.
      ELSEIF ls_out-text(4) = 'UID '.
        lv_tmp = ls_out-text+4.
        CONDENSE lv_tmp NO-GAPS.
        IF NOT lv_tmp IS INITIAL AND lv_tmp CO '0123456789 '.
          ls_uid-uid = lv_tmp.
          APPEND ls_uid TO lt_uid.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lv_uidv IS INITIAL OR NOT lv_uidv CO '0123456789 '.
      WRITE: / '  Invalid UIDVALIDITY in script response.'.
      PERFORM profile_unlock USING is_prof-profile.
      EXIT.
    ENDIF.
    LOOP AT lt_uid INTO ls_uid.
      IF lv_count >= lv_max.
        EXIT.
      ENDIF.
      READ TABLE lt_pending INTO ls_pending
        WITH KEY uidvalidity = lv_uidv mailuid = ls_uid-uid.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
      PERFORM process_one USING ls_prof lv_uidv ls_uid-uid
                          CHANGING lv_work.
      IF NOT lv_work IS INITIAL.
        lv_count = lv_count + 1.
      ENDIF.
    ENDLOOP.
    IF lt_uid[] IS INITIAL.
      WRITE: / '  No new mail in the mailbox.'.
    ENDIF.
  ENDIF.

  PERFORM profile_unlock USING is_prof-profile.
ENDFORM.

*---------------------------------------------------------------
* One mail: fetch, read, run the business logic, move.
* cv_work = 'X': real work was done (counts towards MAXMAIL).
*---------------------------------------------------------------
FORM process_one USING    is_prof TYPE zche_imap_profile
                          iv_uidv TYPE c
                          iv_uid  TYPE n
                 CHANGING cv_work TYPE c.
  DATA: ls_log       TYPE zche_imap_log,
        ls_mail      TYPE zche_imap_s_mail,
        ls_input     TYPE zche_imap_s_mail,
        lt_body      TYPE ty_t_line,
        lt_att       TYPE ty_t_att,
        lt_out       TYPE ty_t_line,
        lv_uidc(10)  TYPE c,
        lv_par(128)  TYPE c,
        lv_dir(255)  TYPE c,
        lv_prog(40)  TYPE c,
        lv_form(30)  TYPE c,
        lv_ok(1)     TYPE c,
        lv_msg(255)  TYPE c,
        lv_key(28)   TYPE c,
        lv_status(1) TYPE c,
        lv_logmsg(255) TYPE c,
        lv_limit_text(255) TYPE c,
        lv_limit TYPE i.

  CLEAR cv_work.
  lv_uidc = iv_uid.
  SHIFT lv_uidc LEFT DELETING LEADING '0'.

  SELECT SINGLE * FROM zche_imap_log INTO ls_log
    WHERE profile     = is_prof-profile
      AND uidvalidity = iv_uidv
      AND mailuid     = iv_uid.
  IF sy-subrc = 0.
*   Business logic already ran: only repeat the move
    IF ls_log-status = 'H' OR ls_log-status = 'S'.
      IF p_test IS INITIAL.
        PERFORM finish_mail USING is_prof iv_uidv iv_uid.
        cv_work = 'X'.
      ENDIF.
      EXIT.
    ENDIF.
    IF ls_log-status = 'E'.
      SELECT SINGLE pvalue FROM zche_imap_param
        INTO lv_limit_text WHERE param = 'MAX_ATTEMPTS'.
      lv_limit = 3.
      IF sy-subrc = 0 AND lv_limit_text CO '0123456789 '.
        lv_limit = lv_limit_text.
      ENDIF.
      IF lv_limit < 1.
        lv_limit = 3.
      ENDIF.
      IF ls_log-attempts >= lv_limit.
        gv_skip = gv_skip + 1.
        EXIT.
      ENDIF.
    ENDIF.
    IF ls_log-status = 'E' AND p_retry IS INITIAL.
      gv_skip = gv_skip + 1.
      EXIT.
    ENDIF.
  ENDIF.

* Dry-run never fetches BODY[] or creates local mail files.
* Older curl versions cannot reliably return a custom PEEK literal.
  IF NOT p_test IS INITIAL.
    WRITE: / '  UID', lv_uidc, 'available (not downloaded)'.
    gv_read = gv_read + 1.
    cv_work = 'X'.
    EXIT.
  ENDIF.

  cv_work = 'X'.
  ls_mail-profile     = is_prof-profile.
  ls_mail-uidvalidity = iv_uidv.
  ls_mail-mailuid     = iv_uid.

  PERFORM storage_key USING is_prof-profile CHANGING lv_key.
  CONCATENATE lv_key lv_uidc iv_uidv is_prof-revision INTO lv_par
              SEPARATED BY space.
  PERFORM call_cmd USING 'ZCHE_IMAP_FETCH' lv_par
                   CHANGING lt_out lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    WRITE: / '  UID', lv_uidc, 'could not be fetched.'.
    PERFORM write_error USING lv_msg.
    PERFORM set_status USING ls_mail 'E' lv_msg
                       CHANGING lv_status lv_logmsg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.

  PERFORM mail_dir USING ' ' is_prof-profile iv_uidv iv_uid
                   CHANGING lv_dir.
  PERFORM read_mail_dir USING lv_dir
                        CHANGING ls_mail lt_body lt_att lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    WRITE: / '  UID', lv_uidc, 'could not be read:', lv_msg(100).
    PERFORM set_status USING ls_mail 'E' lv_msg
                       CHANGING lv_status lv_logmsg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.

  lv_prog = is_prof-hprog.
  lv_form = is_prof-hform.
  IF lv_prog IS INITIAL.
    lv_prog = 'ZCHE_IMAP_HANDLER_DEMO'.
  ENDIF.
  IF lv_form IS INITIAL.
    lv_form = 'HANDLE_MAIL'.
  ENDIF.
  PERFORM handler_allowed USING lv_prog lv_form CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    lv_msg = 'Handler rejected by server-owned prefix policy'.
    PERFORM set_status USING ls_mail 'E' lv_msg
                       CHANGING lv_status lv_logmsg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.
* If the handler is not found, lv_ok stays empty and this
* message is logged
  CLEAR lv_ok.
  CONCATENATE 'Handler not found:' lv_prog lv_form
              INTO lv_msg SEPARATED BY space.
  WRITE: / '  UID', lv_uidc, ls_mail-subject(80).
* Local V1 updates and H are one database LUW. A failed update
* aborts this LUW, including H; no remote mail move has run yet.
* Handler code must not commit, roll back, call RFC or submit
* transactions that end this LUW. Only the processor owns it.
  ls_input = ls_mail.
  SET UPDATE TASK LOCAL.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    lv_msg = 'Local update could not be activated; handler skipped'.
    PERFORM set_status USING ls_mail 'E' lv_msg
                       CHANGING lv_status lv_logmsg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.
  PERFORM (lv_form) IN PROGRAM (lv_prog)
          USING ls_input lt_body lt_att
          CHANGING lv_ok lv_msg IF FOUND.
  IF lv_ok <> 'X'.
    ROLLBACK WORK.
    FORMAT COLOR COL_NEGATIVE INTENSIFIED OFF.
    WRITE: / '  Business logic error:', lv_msg(120).
    FORMAT COLOR OFF.
    PERFORM set_status USING ls_mail 'E' lv_msg
                       CHANGING lv_status lv_logmsg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.

* COMMIT here: business logic changes and status H together
  PERFORM set_status USING ls_mail 'H' space
                     CHANGING lv_status lv_logmsg.
  IF lv_status IS INITIAL.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.
  PERFORM finish_mail USING is_prof iv_uidv iv_uid.
ENDFORM.

*---------------------------------------------------------------
FORM finish_mail USING is_prof TYPE zche_imap_profile
                       iv_uidv TYPE c
                       iv_uid  TYPE n.
  DATA: lt_out      TYPE ty_t_line,
        ls_mail     TYPE zche_imap_s_mail,
        lv_uidc(10) TYPE c,
        lv_uidv(20) TYPE c,
        lv_par(128) TYPE c,
        lv_ok(1)    TYPE c,
        lv_msg(255) TYPE c,
        lv_key(28) TYPE c,
        lv_status(1) TYPE c,
        lv_logmsg(255) TYPE c.

  lv_uidc = iv_uid.
  SHIFT lv_uidc LEFT DELETING LEADING '0'.
  lv_uidv = iv_uidv.
  CONDENSE lv_uidv NO-GAPS.
  PERFORM storage_key USING is_prof-profile CHANGING lv_key.
  CONCATENATE lv_key lv_uidc lv_uidv is_prof-revision INTO lv_par
              SEPARATED BY space.
  PERFORM call_cmd USING 'ZCHE_IMAP_DONE' lv_par
                   CHANGING lt_out lv_ok lv_msg.
  IF lv_ok IS INITIAL.
*   Status stays H; the next run only retries the move
    WRITE: / '  UID', lv_uidc, 'processed but could not be moved.'.
    PERFORM write_error USING lv_msg.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.
  ls_mail-profile     = is_prof-profile.
  ls_mail-uidvalidity = iv_uidv.
  ls_mail-mailuid     = iv_uid.
  PERFORM set_status USING ls_mail 'S' space
                     CHANGING lv_status lv_logmsg.
  IF lv_status IS INITIAL.
    gv_fail = gv_fail + 1.
    EXIT.
  ENDIF.
  FORMAT COLOR COL_POSITIVE INTENSIFIED OFF.
  WRITE: / '  UID', lv_uidc, 'completed.'.
  FORMAT COLOR OFF.
  gv_done = gv_done + 1.
ENDFORM.

*---------------------------------------------------------------
FORM set_status USING is_mail   TYPE zche_imap_s_mail
                      iv_status TYPE c
                      iv_msg    TYPE c
                CHANGING cv_ok TYPE c cv_msg TYPE c.
  DATA: ls_log TYPE zche_imap_log,
        lt_marker TYPE ty_t_line,
        ls_marker TYPE zche_imap_s_line,
        lv_dir(255) TYPE c, lv_path(255) TYPE c,
        lv_marker_ok TYPE c, lv_marker_msg(255) TYPE c.

  CLEAR: cv_ok, cv_msg.
  IF NOT p_test IS INITIAL.
    cv_ok = 'X'.
    EXIT.
  ENDIF.

  SELECT SINGLE * FROM zche_imap_log INTO ls_log
    WHERE profile     = is_mail-profile
      AND uidvalidity = is_mail-uidvalidity
      AND mailuid     = is_mail-mailuid.
  IF sy-subrc <> 0.
    CLEAR ls_log.
    ls_log-profile     = is_mail-profile.
    ls_log-uidvalidity = is_mail-uidvalidity.
    ls_log-mailuid     = is_mail-mailuid.
  ENDIF.
  IF NOT is_mail-subject IS INITIAL OR
     NOT is_mail-sender IS INITIAL.
    ls_log-sender    = is_mail-sender.
    ls_log-subject   = is_mail-subject.
    ls_log-messageid = is_mail-messageid.
    ls_log-maildate  = is_mail-maildate.
    ls_log-attcnt    = is_mail-attcnt.
  ENDIF.
  IF iv_status = 'E' AND ls_log-attempts < 9999.
    ls_log-attempts = ls_log-attempts + 1.
  ENDIF.
  ls_log-status  = iv_status.
  ls_log-message = iv_msg.
  ls_log-chdat   = sy-datum.
  ls_log-chtim   = sy-uzeit.
  ls_log-uname   = sy-uname.
  MODIFY zche_imap_log FROM ls_log.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    cv_msg = 'Could not persist mail status; no move attempted'.
    WRITE: / cv_msg.
    EXIT.
  ENDIF.
  COMMIT WORK AND WAIT.
  IF sy-subrc <> 0.
    cv_msg = 'Mail transaction failed; no move attempted'.
    WRITE: / cv_msg.
    EXIT.
  ENDIF.
  IF iv_status = 'E'.
    PERFORM mail_dir USING space is_mail-profile
      is_mail-uidvalidity is_mail-mailuid CHANGING lv_dir.
    CONCATENATE lv_dir 'failed.utc' INTO lv_path.
    ls_marker-text = 'E'.
    APPEND ls_marker TO lt_marker.
    PERFORM write_text_file USING lv_path lt_marker
      CHANGING lv_marker_ok lv_marker_msg.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.
