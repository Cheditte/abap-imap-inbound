*---------------------------------------------------------------
* ZIMAP_MONITOR - processed and failed mails
*
* List: by profile, status and date. Double-click a line to see
* the headers, body and attachments of the mail.
*   Attachment or "Original mail" line: the file is downloaded to
*   your PC. PDF, images and text can open in a viewer; all other
*   types, including original mail, are downloaded only.
*   "Reprocess": a failed mail is processed in the next run.
*
* 4.6C compatible; lines at most 72 characters; ASCII only.
* Uses the new SAP GUI classes if they exist, otherwise the WS_*
* functions.
*---------------------------------------------------------------
REPORT zimap_monitor LINE-SIZE 200 NO STANDARD PAGE HEADING.

TABLES zimap_log.

INCLUDE zimap_common.
INCLUDE zimap_io.

SELECT-OPTIONS: s_prof FOR zimap_log-profile,
                s_stat FOR zimap_log-status,
                s_date FOR zimap_log-chdat.
PARAMETERS p_limit TYPE i DEFAULT 1000.

DATA: gt_log       TYPE STANDARD TABLE OF zimap_log,
      gs_log       TYPE zimap_log,
      gv_kind(1)   TYPE c,
      gv_path(255) TYPE c,
      gv_name(150) TYPE c,
      gv_setup(1)  TYPE c,
      gv_auth(1)   TYPE c.

INITIALIZATION.
  s_date-sign   = 'I'.
  s_date-option = 'BT'.
  s_date-low    = sy-datum - 30.
  s_date-high   = sy-datum.
  APPEND s_date.

START-OF-SELECTION.
  PERFORM table_auth USING 'ZIMAP_LOG' 'S' CHANGING gv_auth.
  IF gv_auth IS INITIAL.
    WRITE: / 'No log display authorization (S_TABU_DIS).'.
    EXIT.
  ENDIF.
  IF p_limit < 1 OR p_limit > 1000.
    p_limit = 1000.
  ENDIF.
  PERFORM get_setup CHANGING gv_setup.
  IF gv_setup IS INITIAL.
    WRITE: / 'Setup missing or this is the wrong execution host.'.
    EXIT.
  ENDIF.
  SELECT * FROM zimap_log INTO TABLE gt_log
    UP TO p_limit ROWS
    WHERE profile IN s_prof
      AND status  IN s_stat
      AND chdat   IN s_date
    ORDER BY chdat DESCENDING chtim DESCENDING
             profile uidvalidity mailuid.
  SORT gt_log BY chdat DESCENDING chtim DESCENDING.
  PERFORM write_list.
  WRITE: / 'Display limited to', p_limit,
           'rows; narrow profile/date selections for older mail.'.

TOP-OF-PAGE.
  FORMAT COLOR COL_HEADING.
  WRITE: / 'Status', 12 'Profile', 33 'UID', 45 'Date', 56 'Time',
           65 'From', 106 'Subject', 157 'Att.'.
  FORMAT COLOR OFF.
  ULINE.

AT LINE-SELECTION.
  CASE gv_kind.
    WHEN 'M'.
      PERFORM show_detail.
    WHEN 'A'.
      PERFORM open_on_pc USING gv_path gv_name.
    WHEN 'R'.
      PERFORM mark_retry.
  ENDCASE.
  CLEAR gv_kind.

*---------------------------------------------------------------
FORM status_text USING    iv_status TYPE c
                 CHANGING cv_text   TYPE c.
  CASE iv_status.
    WHEN 'S'. cv_text = 'Done'.
    WHEN 'E'. cv_text = 'Error'.
    WHEN 'H'. cv_text = 'To move'.
    WHEN 'R'. cv_text = 'Retry'.
    WHEN OTHERS. cv_text = iv_status.
  ENDCASE.
ENDFORM.

*---------------------------------------------------------------
FORM set_color USING iv_status TYPE c.
  CASE iv_status.
    WHEN 'S'. FORMAT COLOR COL_POSITIVE INTENSIFIED OFF.
    WHEN 'E'. FORMAT COLOR COL_NEGATIVE INTENSIFIED OFF.
    WHEN 'H'. FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
    WHEN 'R'. FORMAT COLOR COL_GROUP INTENSIFIED OFF.
  ENDCASE.
ENDFORM.

*---------------------------------------------------------------
FORM write_list.
  DATA: lv_text(10) TYPE c,
        lv_uidc(10) TYPE c,
        lv_attc(4)  TYPE c,
        lv_cnt_s    TYPE i,
        lv_cnt_e    TYPE i,
        lv_total    TYPE i.

  LOOP AT gt_log INTO gs_log.
    PERFORM status_text USING gs_log-status CHANGING lv_text.
    PERFORM set_color USING gs_log-status.
    WRITE: / lv_text.
    FORMAT COLOR OFF.
*   Numeric text fields: show without leading zeros
    PERFORM no_zeros USING gs_log-mailuid CHANGING lv_uidc.
    PERFORM no_zeros USING gs_log-attcnt CHANGING lv_attc.
    WRITE: 12 gs_log-profile,
           33 lv_uidc,
           45 gs_log-chdat DD/MM/YYYY,
           56 gs_log-chtim USING EDIT MASK '__:__',
           65 gs_log-sender(40),
           106 gs_log-subject(50),
           157 lv_attc.
    IF gs_log-status = 'E'.
      FORMAT COLOR COL_NEGATIVE INTENSIFIED OFF.
      WRITE: / '           ', gs_log-message(140).
      FORMAT COLOR OFF.
    ENDIF.
    gv_kind = 'M'.
    HIDE: gv_kind, gs_log-profile, gs_log-uidvalidity,
          gs_log-mailuid.
    CLEAR gv_kind.
    lv_total = lv_total + 1.
    IF gs_log-status = 'S'.
      lv_cnt_s = lv_cnt_s + 1.
    ELSEIF gs_log-status = 'E'.
      lv_cnt_e = lv_cnt_e + 1.
    ENDIF.
  ENDLOOP.
  ULINE.
  WRITE: / 'Total:', lv_total, '  Done:', lv_cnt_s,
           '  Error:', lv_cnt_e.
  WRITE: / 'Double-click a line for details.'.
ENDFORM.

*---------------------------------------------------------------
* "0000000017" -> "17", "0000" -> "0"
*---------------------------------------------------------------
FORM no_zeros USING    iv_num
              CHANGING cv_text TYPE c.
  cv_text = iv_num.
  SHIFT cv_text LEFT DELETING LEADING '0'.
  IF cv_text IS INITIAL.
    cv_text = '0'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM show_detail.
  DATA: ls_log       TYPE zimap_log,
        ls_mail      TYPE zimap_s_mail,
        lt_body      TYPE ty_t_line,
        ls_line      TYPE zimap_s_line,
        lt_att       TYPE ty_t_att,
        ls_att       TYPE zimap_s_att,
        lv_dir(255)  TYPE c,
        lv_ok(1)     TYPE c,
        lv_msg(255)  TYPE c,
        lv_text(10)  TYPE c,
        lv_uidc(10)  TYPE c,
        lv_size(12)  TYPE c.

  SELECT SINGLE * FROM zimap_log INTO ls_log
    WHERE profile     = gs_log-profile
      AND uidvalidity = gs_log-uidvalidity
      AND mailuid     = gs_log-mailuid.
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.

  PERFORM status_text USING ls_log-status CHANGING lv_text.
  FORMAT COLOR COL_HEADING.
  WRITE: / 'Mail details'.
  FORMAT COLOR OFF.
  PERFORM no_zeros USING ls_log-mailuid CHANGING lv_uidc.
  WRITE: / 'Profile  :', ls_log-profile,
         / 'UID      :', lv_uidc, ls_log-uidvalidity.
  WRITE: / 'Status   :'.
  PERFORM set_color USING ls_log-status.
  WRITE: lv_text.
  FORMAT COLOR OFF.
  WRITE: ls_log-chdat DD/MM/YYYY, ls_log-chtim, ls_log-uname.
  IF NOT ls_log-message IS INITIAL.
    WRITE: / 'Message  :', ls_log-message(150).
  ENDIF.

  IF gv_setup IS INITIAL.
    WRITE: / 'No setup settings (ZIMAP_PARAM).'.
    EXIT.
  ENDIF.
  PERFORM mail_dir USING ls_log-status ls_log-profile
                         ls_log-uidvalidity ls_log-mailuid
                   CHANGING lv_dir.
  PERFORM read_mail_dir USING lv_dir
                        CHANGING ls_mail lt_body lt_att lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    SKIP.
    WRITE: / 'Mail files not found on the server.',
           / '(Retention period may have expired:', lv_dir(80), ')'.
    PERFORM write_retry USING ls_log-status.
    EXIT.
  ENDIF.

  WRITE: / 'From     :', ls_mail-sender(150),
         / 'To       :', ls_mail-recipient(150).
  IF NOT ls_mail-copy_to IS INITIAL.
    WRITE: / 'Cc       :', ls_mail-copy_to(150).
  ENDIF.
  WRITE: / 'Subject  :', ls_mail-subject(150),
         / 'Date     :', ls_mail-maildate.

  SKIP.
  FORMAT COLOR COL_GROUP INTENSIFIED OFF.
  WRITE: / 'Attachments (double-click to open)'.
  FORMAT COLOR OFF.
  FORMAT HOTSPOT ON.
  LOOP AT lt_att INTO ls_att.
    lv_size = ls_att-attsize.
    SHIFT lv_size LEFT DELETING LEADING '0'.
    WRITE: / '  [Open]', ls_att-name(70), lv_size, 'bytes',
             ls_att-mime(40), ls_att-disp.
    gv_kind = 'A'.
    gv_path = ls_att-path.
    gv_name = ls_att-name.
    HIDE: gv_kind, gv_path, gv_name.
  ENDLOOP.
  IF lt_att[] IS INITIAL.
    FORMAT HOTSPOT OFF.
    WRITE: / '  (no attachments)'.
    FORMAT HOTSPOT ON.
  ENDIF.
  WRITE: / '  [Save] Original mail (mail.eml, download only)'.
  gv_kind = 'A'.
  CONCATENATE lv_dir 'mail.eml' INTO gv_path.
  gv_name = 'mail.eml'.
  HIDE: gv_kind, gv_path, gv_name.
  FORMAT HOTSPOT OFF.
  CLEAR: gv_kind, gv_path, gv_name.

  PERFORM write_retry USING ls_log-status.

  SKIP.
  FORMAT COLOR COL_GROUP INTENSIFIED OFF.
  WRITE: / 'Text'.
  FORMAT COLOR OFF.
  LOOP AT lt_body INTO ls_line.
    IF sy-tabix > 300.
      WRITE: / '... (rest is in the original mail)'.
      EXIT.
    ENDIF.
    WRITE: / ls_line-text(180).
  ENDLOOP.
ENDFORM.

*---------------------------------------------------------------
FORM write_retry USING iv_status TYPE c.
  IF iv_status <> 'E'.
    EXIT.
  ENDIF.
  SKIP.
  FORMAT HOTSPOT ON COLOR COL_NEGATIVE INTENSIFIED OFF.
  WRITE: / '  [Reprocess]'.
  gv_kind = 'R'.
  HIDE gv_kind.
  FORMAT HOTSPOT OFF COLOR OFF.
  CLEAR gv_kind.
ENDFORM.

*---------------------------------------------------------------
FORM mark_retry.
  DATA lv_ok(1) TYPE c.

  PERFORM table_auth USING 'ZIMAP_LOG' 'U' CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'S' 'No log change authorization'.
    EXIT.
  ENDIF.
  PERFORM profile_lock USING gs_log-profile CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'S' 'Profile in use; try again'.
    EXIT.
  ENDIF.
  UPDATE zimap_log SET status  = 'R'
                       message = 'Marked for reprocessing'
                       chdat   = sy-datum
                       chtim   = sy-uzeit
                       uname   = sy-uname
    WHERE profile     = gs_log-profile
      AND uidvalidity = gs_log-uidvalidity
      AND mailuid     = gs_log-mailuid
      AND status      = 'E'.
  IF sy-subrc = 0.
    COMMIT WORK.
    PERFORM show_msg USING 'S'
      'Mail will be processed in the next ZIMAP_INBOUND run.'.
  ELSE.
    ROLLBACK WORK.
    PERFORM show_msg USING 'S' 'Mail status changed; refresh list'.
  ENDIF.
  PERFORM profile_unlock USING gs_log-profile.
ENDFORM.

*---------------------------------------------------------------
* Downloads the server file to the user's PC and opens it with
* the associated program. Without the new GUI classes (old
* releases) WS_DOWNLOAD / WS_EXECUTE are used.
*---------------------------------------------------------------
FORM open_on_pc USING iv_path TYPE c
                      iv_name TYPE c.
  DATA: lt_bin       TYPE ty_t_bin,
        lv_len       TYPE i,
        lv_ok(1)     TYPE c,
        lv_cls(1)    TYPE c,
        lv_fm(1)     TYPE c,
        lv_type(30)  TYPE c,
        lv_tmps      TYPE string,
        lv_tmp(200)  TYPE c,
        lv_uidc(10)  TYPE c,
        lv_key(28) TYPE c,
        lv_file(255) TYPE c,
        lv_fstr      TYPE string,
        lv_wsname    LIKE rlgrap-filename,
        lv_name(150) TYPE c,
        lv_ext(8) TYPE c,
        lv_idx TYPE i.

  PERFORM read_binary_file USING iv_path
                           CHANGING lt_bin lv_len lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'S'
      'Cannot read file on server (deleted or no authorization).'.
    EXIT.
  ENDIF.

  PERFORM class_exists USING 'CL_GUI_FRONTEND_SERVICES'
                       CHANGING lv_cls.
  IF NOT lv_cls IS INITIAL.
    CALL METHOD ('CL_GUI_FRONTEND_SERVICES')=>('GET_TEMP_DIRECTORY')
      CHANGING
        temp_dir = lv_tmps
      EXCEPTIONS
        OTHERS   = 1.
    CALL METHOD ('CL_GUI_CFW')=>('FLUSH').
    IF STRLEN( lv_tmps ) > 200.
      PERFORM show_msg USING 'S' 'PC temporary path is too long'.
      EXIT.
    ENDIF.
    lv_tmp = lv_tmps.
  ENDIF.
  IF lv_tmp IS INITIAL.
    lv_tmp = 'C:\TEMP'.
  ENDIF.

  lv_uidc = gs_log-mailuid.
  SHIFT lv_uidc LEFT DELETING LEADING '0'.
  PERFORM storage_key USING gs_log-profile CHANGING lv_key.
  CONCATENATE lv_tmp '\zimap_' lv_key '_'
              gs_log-uidvalidity '_' lv_uidc '_'
              iv_name INTO lv_fstr.
  IF STRLEN( lv_fstr ) > 255.
    PERFORM show_msg USING 'S' 'Download file path is too long'.
    EXIT.
  ENDIF.
  lv_file = lv_fstr.

* Download: GUI_DOWNLOAD (file name STRING), else WS_DOWNLOAD
  PERFORM fm_exists USING 'GUI_DOWNLOAD' CHANGING lv_fm.
  IF NOT lv_fm IS INITIAL.
    SELECT SINGLE structure FROM fupararef INTO lv_type
      WHERE funcname = 'GUI_DOWNLOAD' AND parameter = 'FILENAME'.
    IF lv_type <> 'STRING'.
      CLEAR lv_fm.
    ENDIF.
  ENDIF.
  IF NOT lv_fm IS INITIAL.
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        bin_filesize = lv_len
        filename     = lv_fstr
        filetype     = 'BIN'
      TABLES
        data_tab     = lt_bin
      EXCEPTIONS
        OTHERS       = 1.
  ELSE.
    lv_wsname = lv_file.
    IF lv_wsname <> lv_file.
      PERFORM show_msg USING 'S'
        'File path exceeds the legacy download API limit'.
      EXIT.
    ENDIF.
    CALL FUNCTION 'WS_DOWNLOAD'
      EXPORTING
        bin_filesize = lv_len
        filename     = lv_wsname
        filetype     = 'BIN'
      TABLES
        data_tab     = lt_bin
      EXCEPTIONS
        OTHERS       = 1.
  ENDIF.
  IF sy-subrc <> 0.
    PERFORM show_msg USING 'S' 'Could not download the file to the PC.'.
    EXIT.
  ENDIF.

* Saving arbitrary attachments is allowed; executing them is not.
* Only a small document/image allowlist may launch a viewer.
  lv_name = iv_name.
  TRANSLATE lv_name TO LOWER CASE.
  lv_idx = STRLEN( lv_name ).
  WHILE lv_idx > 0.
    SUBTRACT 1 FROM lv_idx.
    IF lv_name+lv_idx(1) = '.'.
      lv_ext = lv_name+lv_idx.
      EXIT.
    ENDIF.
  ENDWHILE.
  IF lv_ext <> '.pdf' AND lv_ext <> '.png' AND
     lv_ext <> '.jpg' AND lv_ext <> '.jpeg' AND
     lv_ext <> '.gif' AND lv_ext <> '.bmp' AND
     lv_ext <> '.txt'.
    CONCATENATE 'Downloaded only (file type not opened):' lv_file
                INTO lv_file SEPARATED BY space.
    PERFORM show_msg USING 'S' lv_file.
    EXIT.
  ENDIF.
* Open safe types with the associated viewer.
  IF NOT lv_cls IS INITIAL.
    CALL METHOD ('CL_GUI_FRONTEND_SERVICES')=>('EXECUTE')
      EXPORTING
        document = lv_fstr
      EXCEPTIONS
        OTHERS   = 1.
  ELSE.
    CALL FUNCTION 'WS_EXECUTE'
      EXPORTING
        document = 'X'
        program  = lv_file
      EXCEPTIONS
        OTHERS   = 1.
  ENDIF.
  IF sy-subrc <> 0.
    CONCATENATE 'File downloaded but could not be opened:' lv_file
                INTO lv_file SEPARATED BY space.
    PERFORM show_msg USING 'S' lv_file.
  ENDIF.
ENDFORM.
