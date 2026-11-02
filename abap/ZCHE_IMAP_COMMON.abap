* Project: abap-imap-inbound
*---------------------------------------------------------------
* ZCHE_IMAP_COMMON - shared types and helper forms (INCLUDE)
* Used by ZCHE_IMAP_INBOUND, ZCHE_IMAP_CONFIG, ZCHE_IMAP_MONITOR and the
* handler programs. Included together with ZCHE_IMAP_IO.
*
* Classic ABAP 7.00: no inline
* declarations, constructor expressions or string templates;
* source lines fit ABAPSOURCE; ASCII only.
*---------------------------------------------------------------
TYPES: ty_t_line TYPE STANDARD TABLE OF zche_imap_s_line
                 WITH DEFAULT KEY.
TYPES: ty_t_att TYPE STANDARD TABLE OF zche_imap_s_att
                WITH DEFAULT KEY.
TYPES: BEGIN OF ty_bin,
         data(1024) TYPE x,
       END OF ty_bin.
TYPES: ty_t_bin TYPE STANDARD TABLE OF ty_bin
                WITH DEFAULT KEY.
TYPES: BEGIN OF ty_uid,
         uid(10) TYPE n,
       END OF ty_uid.
TYPES: ty_t_uid TYPE STANDARD TABLE OF ty_uid
                WITH DEFAULT KEY.

CONSTANTS: gc_version(10) TYPE c VALUE '0.9.2'.

DATA: gv_root(200)  TYPE c,
      gv_sep(1)     TYPE c,
      gv_filecp(10) TYPE c.

*---------------------------------------------------------------
* Setup settings (ZCHE_IMAP_PARAM): server folder and file code
* page. Written by ZCHE_IMAP_INSTALL.
*---------------------------------------------------------------
FORM get_setup CHANGING cv_ok TYPE c.
  DATA: lv_val(255) TYPE c,
        lv_len      TYPE i.

  CLEAR: cv_ok, gv_root, gv_sep, gv_filecp.
* Files are local to one explicitly selected application server.
  SELECT SINGLE pvalue FROM zche_imap_param INTO lv_val
    WHERE param = 'EXEC_HOST'.
  IF sy-subrc <> 0 OR lv_val <> sy-host.
    EXIT.
  ENDIF.
  SELECT SINGLE pvalue FROM zche_imap_param INTO lv_val
    WHERE param = 'ROOT'.
  IF sy-subrc <> 0 OR lv_val IS INITIAL.
    EXIT.
  ENDIF.
* The installer limits ROOT to 60; attachment paths fit CHAR255.
  IF STRLEN( lv_val ) > 60 OR STRLEN( sy-sysid ) <> 3.
    EXIT.
  ENDIF.
  gv_root = lv_val.
  IF gv_root CA '/'.
    gv_sep = '/'.
  ELSE.
    gv_sep = '\'.
  ENDIF.
  lv_len = STRLEN( gv_root ) - 1.
  IF gv_root+lv_len(1) <> gv_sep.
    CONCATENATE gv_root gv_sep INTO gv_root.
  ENDIF.
  SELECT SINGLE pvalue FROM zche_imap_param INTO lv_val
    WHERE param = 'FILECP'.
  IF sy-subrc <> 0 OR lv_val IS INITIAL.
    EXIT.
  ENDIF.
  gv_filecp = lv_val.
  cv_ok = 'X'.
ENDFORM.

*---------------------------------------------------------------
* Folder of the mail on the server. Processed (S):
* Both locations use SID_client_profile/UIDVALIDITY-UID.
*---------------------------------------------------------------
FORM mail_dir USING    iv_status TYPE c
                       iv_prof   TYPE c
                       iv_uidv   TYPE c
                       iv_uid    TYPE n
              CHANGING cv_dir    TYPE c.
  DATA: lv_uidc(10) TYPE c,
        lv_uidv(20) TYPE c,
        lv_key(28) TYPE c.

  lv_uidc = iv_uid.
  SHIFT lv_uidc LEFT DELETING LEADING '0'.
  lv_uidv = iv_uidv.
  CONDENSE lv_uidv NO-GAPS.
  PERFORM storage_key USING iv_prof CHANGING lv_key.
  IF iv_status = 'S'.
    CONCATENATE gv_root 'done' gv_sep lv_key gv_sep
                lv_uidv '-' lv_uidc gv_sep INTO cv_dir.
  ELSE.
    CONCATENATE gv_root 'in' gv_sep lv_key gv_sep
                lv_uidv '-' lv_uidc gv_sep INTO cv_dir.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM storage_key USING iv_prof TYPE c CHANGING cv_key TYPE c.
  CONCATENATE sy-sysid sy-mandt iv_prof INTO cv_key
              SEPARATED BY '_'.
ENDFORM.

FORM profile_valid USING iv_prof TYPE c CHANGING cv_ok TYPE c.
  DATA lv_len TYPE i.

  CLEAR cv_ok.
  lv_len = STRLEN( iv_prof ).
  IF lv_len < 1 OR lv_len > 20.
    EXIT.
  ENDIF.
  IF iv_prof(lv_len) CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
    EXIT.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.

* Scope 1 locks one SID/client/profile across commits.
* E_TABLE is intentional: no generated lock FM is required.
FORM profile_lock USING iv_prof TYPE c CHANGING cv_ok TYPE c.
  DATA: lv_key(28) TYPE c,
        lv_varkey LIKE rstable-varkey.

  CLEAR cv_ok.
  PERFORM storage_key USING iv_prof CHANGING lv_key.
  lv_varkey = lv_key.
  CALL FUNCTION 'ENQUEUE_E_TABLE'
    EXPORTING
      tabname = 'ZCHE_IMAP_PROF'
      varkey  = lv_varkey
      _scope  = '1'
    EXCEPTIONS
      OTHERS  = 1.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

FORM profile_unlock USING iv_prof TYPE c.
  DATA: lv_key(28) TYPE c,
        lv_varkey LIKE rstable-varkey.

  PERFORM storage_key USING iv_prof CHANGING lv_key.
  lv_varkey = lv_key.
  CALL FUNCTION 'DEQUEUE_E_TABLE'
    EXPORTING
      tabname = 'ZCHE_IMAP_PROF'
      varkey  = lv_varkey
      _scope  = '1'.
ENDFORM.

* Generic table checks are not implicit in application Open SQL.
* Fail closed if an old release lacks the checked API contract.
FORM table_auth USING iv_table TYPE c iv_action TYPE c
                CHANGING cv_ok TYPE c.
  DATA: lv_exists(1) TYPE c,
        lv_param(30) TYPE c,
        lv_table LIKE dd25v-viewname,
        lv_action(1) TYPE c.

  CLEAR cv_ok.
  lv_table = iv_table.
  lv_action = iv_action.
  CALL FUNCTION 'VIEW_AUTHORITY_CHECK'
    EXPORTING
      view_action = lv_action
      view_name   = lv_table
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM fm_exists USING iv_func TYPE c CHANGING cv_ok TYPE c.
  CLEAR cv_ok.
  CALL FUNCTION 'FUNCTION_EXISTS'
    EXPORTING funcname = iv_func
    EXCEPTIONS function_not_exist = 1 OTHERS = 2.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM class_exists USING    iv_class TYPE c
                  CHANGING cv_ok    TYPE c.
  DATA lv_class(30) TYPE c.

  CLEAR cv_ok.
  SELECT SINGLE clsname FROM seoclass INTO lv_class
    WHERE clsname = iv_class.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* Runs an SM69 command. The last line of the script is the result
* line: "OK" or "ERR <CODE> <description>". Other lines go to
* ct_out. On error cv_msg has the form "ERR ..." (map_error).
*---------------------------------------------------------------
FORM call_cmd USING    iv_cmd   TYPE c
                       iv_param TYPE c
              CHANGING ct_out   TYPE ty_t_line
                       cv_ok    TYPE c
                       cv_msg   TYPE c.
  DATA: lt_prot      TYPE STANDARD TABLE OF btcxpm,
        ls_prot      TYPE btcxpm,
        ls_out       TYPE zche_imap_s_line,
        lv_cmd       LIKE sxpgcolist-name,
        lv_par       LIKE sxpgcolist-parameters,
        lv_rc(4)     TYPE c,
        lv_idx       TYPE i,
        lv_last      TYPE i,
        lv_err       TYPE i,
        lv_text(128) TYPE c,
        lv_protocol TYPE i.

  CLEAR: ct_out, cv_ok, cv_msg.
  lv_cmd = iv_cmd.
  lv_par = iv_param.
  IF lv_par <> iv_param OR lv_cmd <> iv_cmd.
    cv_msg = 'ERR ARG SM69 parameters exceed the target field'.
    EXIT.
  ENDIF.

* Only parameters that exist in every release are used. A
* parameter missing from the interface stops the program at
* runtime.
  CALL FUNCTION 'SXPG_COMMAND_EXECUTE'
    EXPORTING
      commandname                = lv_cmd
      additional_parameters      = lv_par
    TABLES
      exec_protocol              = lt_prot
    EXCEPTIONS
      no_permission              = 1
      command_not_found          = 2
      parameters_too_long        = 3
      security_risk              = 4
      wrong_check_call_interface = 5
      program_start_error        = 6
      program_termination_error  = 7
      x_error                    = 8
      parameter_expected         = 9
      too_many_parameters        = 10
      illegal_command            = 11
      OTHERS                     = 12.
  IF sy-subrc <> 0.
    lv_rc = sy-subrc.
    CONDENSE lv_rc.
    CONCATENATE 'ERR SXPG' lv_rc INTO cv_msg.
    CONCATENATE cv_msg iv_cmd INTO cv_msg SEPARATED BY space.
    EXIT.
  ENDIF.

* When the script ends with an error, SAP adds its own line
* ("... terminated with exit code 1") after the script's ERR line.
* The script's ERR line is the one that says what went wrong.
  LOOP AT lt_prot INTO ls_prot.
    IF NOT ls_prot-message IS INITIAL.
      lv_last = sy-tabix.
      lv_text = ls_prot-message.
      SHIFT lv_text LEFT DELETING LEADING space.
      IF lv_text(4) = 'ERR '.
        lv_err = sy-tabix.
      ENDIF.
      IF lv_text = 'PROTOCOL 2'.
        lv_protocol = lv_protocol + 1.
      ENDIF.
    ENDIF.
  ENDLOOP.

  LOOP AT lt_prot INTO ls_prot.
    lv_idx = sy-tabix.
    lv_text = ls_prot-message.
    SHIFT lv_text LEFT DELETING LEADING space.
    IF lv_text = 'PROTOCOL 2'.
      CONTINUE.
    ENDIF.
    IF lv_err > 0.
      IF lv_idx = lv_err.
        cv_msg = lv_text.
      ELSEIF lv_idx < lv_err.
        ls_out-text = lv_text.
        APPEND ls_out TO ct_out.
      ENDIF.
    ELSEIF lv_idx = lv_last.
      IF lv_text(3) = 'OK '.
        cv_ok = 'X'.
      ELSE.
        cv_msg = lv_text.
      ENDIF.
    ELSE.
      ls_out-text = lv_text.
      APPEND ls_out TO ct_out.
    ENDIF.
  ENDLOOP.

  IF lv_last = 0.
    CONCATENATE 'ERR EXC Command gave no output:' iv_cmd
      INTO cv_msg SEPARATED BY space.
  ENDIF.
  IF NOT cv_ok IS INITIAL AND lv_protocol <> 1.
    CLEAR cv_ok.
    cv_msg = 'ERR CFG Script protocol mismatch; install v0.9.2'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* Turns an error line ("ERR CODE description") into a readable
* text and a next step. cv_detail is the technical description.
*---------------------------------------------------------------
FORM map_error USING    iv_line   TYPE c
               CHANGING cv_text   TYPE c
                        cv_hint   TYPE c
                        cv_detail TYPE c.
  DATA: lv_err(10)  TYPE c,
        lv_code(20) TYPE c.

  CLEAR: cv_text, cv_hint, cv_detail.
  SPLIT iv_line AT space INTO lv_err lv_code cv_detail.
  IF lv_err <> 'ERR'.
    cv_text = iv_line.
    EXIT.
  ENDIF.
  CASE lv_code.
    WHEN 'AUTH'.
      cv_text = 'Wrong user name or password.'.
      cv_hint = 'ZCHE_IMAP_CONFIG: enter the password again.'.
    WHEN 'CONNECT'.
      cv_text = 'Cannot reach the mail server.'.
      cv_hint = 'Check server name and port; firewall (Basis).'.
    WHEN 'TLS'.
      cv_text = 'Server certificate could not be verified.'.
      cv_hint = 'Install the company CA cert on the server (Basis).'.
    WHEN 'POLICY'.
      cv_text = 'The Basis policy does not allow this setting.'.
      cv_hint = 'Basis: bin/policy.psd1 (allowed servers).'.
    WHEN 'CFG'.
      cv_text = 'Profile settings are missing or invalid.'.
      cv_hint = 'Save the profile with ZCHE_IMAP_CONFIG.'.
    WHEN 'MAILBOX'.
      cv_text = 'IMAP folder not found.'.
      cv_hint = 'Check the inbox and processed folder names.'.
    WHEN 'NOMAIL'.
      cv_text = 'Mail not found on the server (may be deleted).'.
    WHEN 'SIZE'.
      cv_text = 'Mail exceeds the size limit.'.
      cv_hint = 'ZCHE_IMAP_CONFIG: increase the max mail size (MB).'.
    WHEN 'PARSE'.
      cv_text = 'Mail content is invalid or exceeds parser limits.'.
      cv_hint = 'Review MIME/HTML detail; ask for a corrected mail.'.
    WHEN 'ARG'.
      cv_text = 'Invalid parameter passed to the script.'.
    WHEN 'SXPG1'.
      cv_text = 'No authorization for the OS command.'.
      cv_hint = 'Authorization object S_LOG_COM (ZCHE_IMAP_*).'.
    WHEN 'SXPG2'.
      cv_text = 'SM69 command is not defined.'.
      cv_hint = 'Run the program ZCHE_IMAP_INSTALL.'.
    WHEN OTHERS.
      IF lv_code(4) = 'SXPG'.
        cv_text = 'SM69 command could not be run.'.
        cv_hint = 'Test the command in SM49; script folder (Basis).'.
      ELSE.
        cv_text = 'Unexpected error.'.
      ENDIF.
  ENDCASE.
ENDFORM.

*---------------------------------------------------------------
FORM write_error USING iv_line TYPE c.
  DATA: lv_text(120)   TYPE c,
        lv_hint(120)   TYPE c,
        lv_detail(255) TYPE c.

  PERFORM map_error USING iv_line
                    CHANGING lv_text lv_hint lv_detail.
  FORMAT COLOR COL_NEGATIVE INTENSIFIED OFF.
  WRITE: / '  Error :', lv_text.
  FORMAT COLOR OFF.
  IF NOT lv_hint IS INITIAL.
    WRITE: / '  Action:', lv_hint.
  ENDIF.
  IF NOT lv_detail IS INITIAL.
    WRITE: / '  Detail:', lv_detail(120).
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* Reads the parsed mail folder (header, body, attach).
*---------------------------------------------------------------
FORM read_mail_dir USING    iv_dir  TYPE c
                   CHANGING cs_mail TYPE zche_imap_s_mail
                            ct_body TYPE ty_t_line
                            ct_att  TYPE ty_t_att
                            cv_ok   TYPE c
                            cv_msg  TYPE c.
  DATA: lt_lines     TYPE ty_t_line,
        ls_line      TYPE zche_imap_s_line,
        ls_att       TYPE zche_imap_s_att,
        lv_path(255) TYPE c,
        lv_key(20)   TYPE c,
        lv_val(255)  TYPE c.

  CLEAR: ct_body, ct_att, cv_ok, cv_msg.
  cs_mail-dir = iv_dir.

* ready.flg is written last; if missing, parsing did not finish
  CONCATENATE iv_dir 'ready.flg' INTO lv_path.
  PERFORM read_text_file USING lv_path CHANGING lt_lines cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Mail files not found on the server'.
    EXIT.
  ENDIF.

  CONCATENATE iv_dir 'header.txt' INTO lv_path.
  PERFORM read_text_file USING lv_path CHANGING lt_lines cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Could not read header.txt'.
    EXIT.
  ENDIF.
  LOOP AT lt_lines INTO ls_line.
    PERFORM apply_header_line USING ls_line-text CHANGING cs_mail.
  ENDLOOP.

  CONCATENATE iv_dir 'body.txt' INTO lv_path.
  PERFORM read_text_file USING lv_path CHANGING ct_body cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Could not read body.txt'.
    EXIT.
  ENDIF.

  CONCATENATE iv_dir 'attach.txt' INTO lv_path.
  PERFORM read_text_file USING lv_path CHANGING lt_lines cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Could not read attach.txt'.
    EXIT.
  ENDIF.
  LOOP AT lt_lines INTO ls_line.
    CLEAR ls_att.
    SPLIT ls_line-text AT '|' INTO ls_att-name ls_att-attsize
          ls_att-mime ls_att-disp ls_att-orig.
    CONCATENATE iv_dir 'att' gv_sep ls_att-name INTO ls_att-path.
    APPEND ls_att TO ct_att.
  ENDLOOP.
ENDFORM.

FORM apply_header_line USING iv_line TYPE c
                       CHANGING cs_mail TYPE zche_imap_s_mail.
  DATA: lv_key(20) TYPE c, lv_val(255) TYPE c.
    CLEAR: lv_key, lv_val.
*   The last field takes the rest of the text, '=' signs included
    SPLIT iv_line AT '=' INTO lv_key lv_val.
    CASE lv_key.
      WHEN 'FROM'.      cs_mail-sender    = lv_val.
      WHEN 'TO'.        cs_mail-recipient = lv_val.
      WHEN 'CC'.        cs_mail-copy_to   = lv_val.
      WHEN 'SUBJECT'.   cs_mail-subject   = lv_val.
      WHEN 'DATE'.      cs_mail-maildate  = lv_val.
      WHEN 'MESSAGEID'. cs_mail-messageid = lv_val.
      WHEN 'ATTCOUNT'.  cs_mail-attcnt    = lv_val.
    ENDCASE.
ENDFORM.

*---------------------------------------------------------------
* Splits a long text into chunks of 50 for the screen message
* (message 00/001: &1&2&3&4).
*---------------------------------------------------------------
FORM show_msg USING iv_type TYPE c
                    iv_text TYPE c.
  DATA lv_text(200) TYPE c.

  lv_text = iv_text.
  MESSAGE ID '00' TYPE iv_type NUMBER '001'
          WITH lv_text(50) lv_text+50(50) lv_text+100(50)
               lv_text+150(50).
ENDFORM.

* Configuration and processing both enforce this server-owned prefix.
FORM handler_allowed USING iv_prog TYPE c iv_form TYPE c
                     CHANGING cv_ok TYPE c.
  DATA: lv_prefix(255) TYPE c, lv_pattern(256) TYPE c,
        lv_length TYPE i.
  CLEAR cv_ok.
  SELECT SINGLE pvalue FROM zche_imap_param INTO lv_prefix
    WHERE param = 'HANDLER_PREFIX'.
  IF sy-subrc <> 0 OR lv_prefix IS INITIAL.
    EXIT.
  ENDIF.
  lv_length = STRLEN( lv_prefix ).
  IF lv_prefix(1) <> 'Z' AND lv_prefix(1) <> 'Y'.
    EXIT.
  ENDIF.
  IF lv_prefix(lv_length) CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
    EXIT.
  ENDIF.
  CONCATENATE lv_prefix '*' INTO lv_pattern.
  IF iv_prog NP lv_pattern OR iv_form IS INITIAL.
    EXIT.
  ENDIF.
  lv_length = STRLEN( iv_form ).
  IF iv_form(lv_length) CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.
    EXIT.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.

FORM profile_auth USING iv_prof TYPE c iv_activity TYPE c
                  CHANGING cv_ok TYPE c.
  CLEAR cv_ok.
  AUTHORITY-CHECK OBJECT 'ZCHE_IMAP'
    ID 'ZCHE_PROF' FIELD iv_prof
    ID 'ACTVT' FIELD iv_activity.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

FORM list_arguments USING iv_key TYPE c iv_revision TYPE clike
                          iv_test TYPE c CHANGING cv_args TYPE c.
  CONCATENATE iv_key iv_revision INTO cv_args SEPARATED BY space.
  IF iv_test IS INITIAL.
    CONCATENATE cv_args 'PURGE' INTO cv_args SEPARATED BY space.
  ENDIF.
ENDFORM.

INCLUDE zche_imap_io.

CLASS ltc_protocol DEFINITION FOR TESTING. "#AU Risk_Level Harmless
  PRIVATE SECTION.
    METHODS long_profile_purge FOR TESTING.
    METHODS dry_run_no_purge FOR TESTING.
    METHODS invalid_profile FOR TESTING.
    METHODS metadata_equals_preserved FOR TESTING.
    METHODS metadata_unknown_ignored FOR TESTING.
ENDCLASS.
CLASS ltc_protocol IMPLEMENTATION.
  METHOD metadata_equals_preserved.
    DATA ls_mail TYPE zche_imap_s_mail.
    PERFORM apply_header_line USING 'SUBJECT=Amount=42'
      CHANGING ls_mail.
    cl_aunit_assert=>assert_equals(
      act = ls_mail-subject exp = 'Amount=42' ).
  ENDMETHOD.
  METHOD metadata_unknown_ignored.
    DATA ls_mail TYPE zche_imap_s_mail.
    ls_mail-subject = 'Keep'.
    PERFORM apply_header_line USING 'OTHER=Ignore'
      CHANGING ls_mail.
    cl_aunit_assert=>assert_equals(
      act = ls_mail-subject exp = 'Keep' ).
  ENDMETHOD.

  METHOD long_profile_purge.
    DATA lv_args(128) TYPE c.
    PERFORM list_arguments USING 'TST_001_ABCDEFGHIJKLMNOPQRST'
      '0000000001' space CHANGING lv_args.
    cl_aunit_assert=>assert_equals(
      act = lv_args
      exp = 'TST_001_ABCDEFGHIJKLMNOPQRST 0000000001 PURGE' ).
  ENDMETHOD.
  METHOD dry_run_no_purge.
    DATA lv_args(128) TYPE c.
    PERFORM list_arguments USING 'TST_001_DEMO' '0000000001'
      'X' CHANGING lv_args.
    cl_aunit_assert=>assert_equals(
      act = lv_args exp = 'TST_001_DEMO 0000000001' ).
  ENDMETHOD.
  METHOD invalid_profile.
    DATA lv_ok TYPE c.
    PERFORM profile_valid USING '../MAIL' CHANGING lv_ok.
    cl_aunit_assert=>assert_initial( lv_ok ).
  ENDMETHOD.
ENDCLASS.
