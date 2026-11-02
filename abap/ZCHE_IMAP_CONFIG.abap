* Project: abap-imap-inbound
*---------------------------------------------------------------
* ZCHE_IMAP_CONFIG - IMAP mailbox profiles
*
* Buttons: Load profile, Save, Delete, Profiles.
* F8: saves and tests the connection step by step.
*
* Password entry is masked; ordinary variant saving is disabled.
* The profile table keeps only entry date/user and the immutable
* credential revision. The password is written to the namespaced
* secret file and is not read back by this application.
* With source O, Basis maintains the secret on the server.
*
* Classic ABAP 7.00 syntax target.
*---------------------------------------------------------------
REPORT zche_imap_config LINE-SIZE 150 NO STANDARD PAGE HEADING.

TABLES: zche_imap_profile, sscrfields.

INCLUDE zche_imap_common.

TYPES: BEGIN OF ty_f4,
         profile LIKE zche_imap_profile-profile,
         descr   LIKE zche_imap_profile-descr,
         host    LIKE zche_imap_profile-host,
       END OF ty_f4.

DATA: gv_setup(1) TYPE c,
      gv_pwdguard(1) TYPE c.

SELECTION-SCREEN FUNCTION KEY 1.
SELECTION-SCREEN FUNCTION KEY 2.
SELECTION-SCREEN FUNCTION KEY 3.
SELECTION-SCREEN FUNCTION KEY 4.

SELECTION-SCREEN BEGIN OF BLOCK b0 WITH FRAME TITLE t_b0.
PARAMETERS: p_prof  LIKE zche_imap_profile-profile,
            p_descr LIKE zche_imap_profile-descr LOWER CASE,
            p_act   AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b0.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_b1.
PARAMETERS: p_host LIKE zche_imap_profile-host LOWER CASE,
            p_port LIKE zche_imap_profile-port DEFAULT '993',
            p_sec  LIKE zche_imap_profile-security DEFAULT 'IMAPS'
                   VALUE CHECK,
            p_ver  AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_b2.
PARAMETERS: p_user  LIKE zche_imap_profile-username LOWER CASE,
            p_crsrc LIKE zche_imap_profile-credsrc DEFAULT 'O'
                    VALUE CHECK,
            p_pwd(100) TYPE c LOWER CASE.
SELECTION-SCREEN COMMENT /1(79) c_pwst.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t_b3.
PARAMETERS: p_mbox LIKE zche_imap_profile-mailbox LOWER CASE
                   DEFAULT 'INBOX',
            p_done LIKE zche_imap_profile-donebox LOWER CASE
                   DEFAULT 'SAP-Processed',
            p_move LIKE zche_imap_profile-movemode DEFAULT 'MOVE'
                   VALUE CHECK.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE t_b4.
PARAMETERS: p_hprog LIKE zche_imap_profile-hprog
                    DEFAULT 'ZCHE_IMAP_HANDLER_DEMO',
            p_hform LIKE zche_imap_profile-hform DEFAULT 'HANDLE_MAIL',
            p_maxm  LIKE zche_imap_profile-maxmail DEFAULT '50',
            p_maxmb LIKE zche_imap_profile-maxmb DEFAULT '20',
            p_tout  LIKE zche_imap_profile-timeout DEFAULT '120',
            p_ret   LIKE zche_imap_profile-retdays DEFAULT '30'.
SELECTION-SCREEN END OF BLOCK b4.

INITIALIZATION.
  sscrfields-functxt_01 = 'Load profile'.
  sscrfields-functxt_02 = 'Save'.
  sscrfields-functxt_03 = 'Delete'.
  sscrfields-functxt_04 = 'Profiles'.
  t_b0 = 'Profile'.
  t_b1 = 'Mail server'.
  t_b2 = 'Credentials'.
  t_b3 = 'IMAP folders'.
  t_b4 = 'Processing'.
  PERFORM get_setup CHANGING gv_setup.

AT SELECTION-SCREEN OUTPUT.
  PERFORM protect_password_ui CHANGING gv_pwdguard.
  IF gv_pwdguard IS INITIAL.
    CLEAR p_pwd.
  ENDIF.
  LOOP AT SCREEN.
    IF screen-name = 'P_PWD'.
      screen-invisible = '1'.
      IF p_crsrc = 'O' OR gv_pwdguard IS INITIAL.
        screen-input = '0'.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
  PERFORM pw_status.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_prof.
  PERFORM f4_profile USING 'X'.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'SPOS' OR 'PRIN'.
      CLEAR p_pwd.
      PERFORM show_msg USING 'E'
        'Variant saving/printing is disabled on this screen.'.
    WHEN 'FC01'.
      PERFORM load_profile.
    WHEN 'FC02'.
      PERFORM save_on_screen.
    WHEN 'FC03'.
      PERFORM delete_profile.
    WHEN 'FC04'.
      PERFORM f4_profile USING ' '.
      PERFORM load_profile.
  ENDCASE.

START-OF-SELECTION.
  PERFORM save_and_test.

*---------------------------------------------------------------
* Block ordinary selection-screen variant saving and printing.
* No claim is made about privileged external variant APIs.
FORM protect_password_ui CHANGING cv_ok TYPE c.
  DATA: lv_exists(1) TYPE c,
        lv_param(30) TYPE c,
        lt_exclude TYPE STANDARD TABLE OF sy-ucomm,
        lv_code LIKE sy-ucomm.

  CLEAR cv_ok.
  lv_code = 'SPOS'.
  APPEND lv_code TO lt_exclude.
  lv_code = 'PRIN'.
  APPEND lv_code TO lt_exclude.
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status = sy-pfkey
    TABLES
      p_exclude = lt_exclude
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc = 0.
    cv_ok = 'X'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM pw_status.
  DATA: ls_prof    TYPE zche_imap_profile,
        lv_date(10) TYPE c,
        lv_auth(1) TYPE c.

  CLEAR c_pwst.
  PERFORM profile_auth USING p_prof '03' CHANGING lv_auth.
  IF lv_auth IS INITIAL.
    EXIT.
  ENDIF.
  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'S'
                     CHANGING lv_auth.
  IF lv_auth IS INITIAL.
    c_pwst = 'No profile display authorization (S_TABU_DIS).'.
    EXIT.
  ENDIF.
  IF p_crsrc = 'O'.
    c_pwst = 'Basis keeps the password on the server (setup-server).'.
    EXIT.
  ENDIF.
  IF gv_pwdguard IS INITIAL.
    c_pwst = 'New password entry unavailable; use Basis source O.'.
    EXIT.
  ENDIF.
  SELECT SINGLE * FROM zche_imap_profile INTO ls_prof
    WHERE profile = p_prof.
  IF sy-subrc = 0 AND NOT ls_prof-pwdat IS INITIAL.
    WRITE ls_prof-pwdat TO lv_date DD/MM/YYYY.
    CONCATENATE 'Password saved:' lv_date ls_prof-pwusr
                '(type a new password to change it)'
                INTO c_pwst SEPARATED BY space.
  ELSE.
    c_pwst = 'No password entered yet.'.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* iv_field = 'X': writes directly to field P_PROF on the screen
*---------------------------------------------------------------
FORM f4_profile USING iv_field TYPE c.
  DATA: lt_f4  TYPE STANDARD TABLE OF ty_f4,
        lt_ret TYPE STANDARD TABLE OF ddshretval,
        ls_ret TYPE ddshretval,
        lv_auth(1) TYPE c.

  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'S'
                     CHANGING lv_auth.
  IF lv_auth IS INITIAL.
    PERFORM show_msg USING 'E' 'No profile display authorization'.
    EXIT.
  ENDIF.
  SELECT profile descr host FROM zche_imap_profile INTO TABLE lt_f4.
  IF sy-subrc <> 0.
    PERFORM show_msg USING 'S' 'No profiles yet.'.
    EXIT.
  ENDIF.
  IF NOT iv_field IS INITIAL.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'PROFILE'
        dynpprog        = sy-repid
        dynpnr          = sy-dynnr
        dynprofield     = 'P_PROF'
        value_org       = 'S'
      TABLES
        value_tab       = lt_f4
      EXCEPTIONS
        OTHERS          = 1.
  ELSE.
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'PROFILE'
        value_org       = 'S'
      TABLES
        value_tab       = lt_f4
        return_tab      = lt_ret
      EXCEPTIONS
        OTHERS          = 1.
    READ TABLE lt_ret INTO ls_ret INDEX 1.
    IF sy-subrc = 0.
      p_prof = ls_ret-fieldval.
    ENDIF.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM load_profile.
  DATA: ls_prof TYPE zche_imap_profile,
        lv_auth(1) TYPE c.

  PERFORM profile_auth USING p_prof '03' CHANGING lv_auth.
  IF lv_auth IS INITIAL.
    EXIT.
  ENDIF.
  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'S'
                     CHANGING lv_auth.
  IF lv_auth IS INITIAL.
    PERFORM show_msg USING 'E' 'No profile display authorization'.
    EXIT.
  ENDIF.
  IF p_prof IS INITIAL.
    PERFORM show_msg USING 'E' 'Enter the profile name.'.
  ENDIF.
  SELECT SINGLE * FROM zche_imap_profile INTO ls_prof
    WHERE profile = p_prof.
  IF sy-subrc <> 0.
    PERFORM show_msg USING 'S'
      'New profile: fill in the fields, then Save or F8.'.
    EXIT.
  ENDIF.
  p_descr = ls_prof-descr.
  p_act   = ls_prof-active.
  p_host  = ls_prof-host.
  p_port  = ls_prof-port.
  p_sec   = ls_prof-security.
  p_ver   = ls_prof-verify.
  p_user  = ls_prof-username.
  p_crsrc = ls_prof-credsrc.
  p_mbox  = ls_prof-mailbox.
  p_done  = ls_prof-donebox.
  p_move  = ls_prof-movemode.
  p_hprog = ls_prof-hprog.
  p_hform = ls_prof-hform.
  p_maxm  = ls_prof-maxmail.
  p_maxmb = ls_prof-maxmb.
  p_tout  = ls_prof-timeout.
  p_ret   = ls_prof-retdays.
  CLEAR p_pwd.
  PERFORM show_msg USING 'S' 'Profile loaded.'.
ENDFORM.

*---------------------------------------------------------------
FORM save_on_screen.
  DATA: lv_ok(1)    TYPE c,
        lv_msg(200) TYPE c.

  PERFORM save_profile CHANGING lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'E' lv_msg.
  ELSE.
    PERFORM show_msg USING 'S' lv_msg.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* Validates, writes to the table and to the conf file on the
* server; writes the secret file if a password was entered.
*---------------------------------------------------------------
FORM save_profile CHANGING cv_ok  TYPE c
                           cv_msg TYPE c.
  CLEAR: cv_ok, cv_msg.
  PERFORM profile_auth USING p_prof '02' CHANGING cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Not authorized to change this profile'.
    EXIT.
  ENDIF.
  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'U' CHANGING cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'No profile change authorization (S_TABU_DIS).'.
    EXIT.
  ENDIF.
  PERFORM profile_valid USING p_prof CHANGING cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Profile: A-Z, digits, underscore; no spaces.'.
    EXIT.
  ENDIF.
  PERFORM profile_lock USING p_prof CHANGING cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Profile in use or lock unavailable; try again.'.
    EXIT.
  ENDIF.
  PERFORM save_profile_locked CHANGING cv_ok cv_msg.
  PERFORM profile_unlock USING p_prof.
ENDFORM.

FORM save_profile_locked CHANGING cv_ok TYPE c cv_msg TYPE c.
  DATA: ls_prof    TYPE zche_imap_profile,
        ls_old     TYPE zche_imap_profile,
        lv_new(1)  TYPE c,
        lv_name(40) TYPE c,
        lv_chars(80) TYPE c,
        lv_logged LIKE zche_imap_log-profile,
        lv_revision TYPE p DECIMALS 0,
        lv_source(100) TYPE c,
        lv_target(100) TYPE c,
        lv_mlen TYPE i,
        lv_dlen TYPE i.

  CLEAR: cv_ok, cv_msg.
  IF p_crsrc = 'S' AND NOT p_pwd IS INITIAL.
    IF gv_pwdguard IS INITIAL OR NOT sy-batch IS INITIAL.
      CLEAR p_pwd.
      cv_msg = 'New password entry unavailable; use Basis source O.'.
      EXIT.
    ENDIF.
  ENDIF.
  IF gv_setup IS INITIAL.
    cv_msg = 'Setup missing/wrong host: rerun ZCHE_IMAP_INSTALL.'.
    EXIT.
  ENDIF.
  IF p_prof IS INITIAL OR
     NOT p_prof CO 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_ '.
    cv_msg = 'Profile name: capitals, digits and _ (max 20).'.
    EXIT.
  ENDIF.
  IF p_host IS INITIAL.
    cv_msg = 'Enter the mail server.'.
    EXIT.
  ENDIF.
  IF p_port IS INITIAL.
    cv_msg = 'Enter the port (IMAPS 993, STARTTLS/NONE 143).'.
    EXIT.
  ENDIF.
  IF p_user IS INITIAL.
    cv_msg = 'Enter the mail user name.'.
    EXIT.
  ENDIF.
  IF p_crsrc <> 'S' AND p_crsrc <> 'O'.
    cv_msg = 'Password source must be S or O.'.
    EXIT.
  ENDIF.
  IF p_move <> 'MOVE'.
    cv_msg = 'Server must support UID MOVE; COPY mode is disabled.'.
    EXIT.
  ENDIF.
  CONCATENATE 'abcdefghijklmnopqrstuvwxyz'
              'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-'
              INTO lv_chars.
  lv_mlen = STRLEN( p_mbox ).
  lv_dlen = STRLEN( p_done ).
  IF lv_mlen = 0 OR lv_dlen = 0.
    cv_msg = 'Enter inbox and processed folder names.'.
    EXIT.
  ENDIF.
  IF p_mbox(lv_mlen) CN lv_chars OR
     p_done(lv_dlen) CN lv_chars OR
     p_mbox(lv_mlen) CA space OR p_done(lv_dlen) CA space.
    cv_msg = 'Folder names: letters, digits and . _ / - (no spaces).'.
    EXIT.
  ENDIF.
* Reject case-only differences too: some servers alias those names.
  lv_source = p_mbox.
  lv_target = p_done.
  TRANSLATE lv_source USING
    'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ'.
  TRANSLATE lv_target USING
    'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ'.
  IF lv_source = lv_target.
    cv_msg = 'Read and processed folders must be different.'.
    EXIT.
  ENDIF.
  IF p_hprog IS INITIAL.
    p_hprog = 'ZCHE_IMAP_HANDLER_DEMO'.
  ENDIF.
  IF p_hform IS INITIAL.
    p_hform = 'HANDLE_MAIL'.
  ENDIF.
  PERFORM handler_allowed USING p_hprog p_hform CHANGING cv_ok.
  IF cv_ok IS INITIAL.
    cv_msg = 'Handler rejected by server-owned prefix policy'.
    EXIT.
  ENDIF.
  SELECT SINGLE name FROM trdir INTO lv_name WHERE name = p_hprog.
  IF sy-subrc <> 0.
    CONCATENATE 'Handler program not found:' p_hprog
                INTO cv_msg SEPARATED BY space.
    EXIT.
  ENDIF.

  SELECT SINGLE * FROM zche_imap_profile INTO ls_old
    WHERE profile = p_prof.
  IF sy-subrc <> 0.
    lv_new = 'X'.
    CLEAR ls_old.
  ENDIF.
  IF p_crsrc = 'S' AND p_pwd IS INITIAL AND ls_old-pwdat IS INITIAL.
    cv_msg = 'Enter the password (password source S).'.
    EXIT.
  ENDIF.
  SELECT SINGLE profile FROM zche_imap_log INTO lv_logged
    WHERE profile = p_prof.
  IF sy-subrc = 0.
    IF ls_old-host <> p_host OR ls_old-port <> p_port OR
       ls_old-security <> p_sec OR ls_old-username <> p_user OR
       ls_old-mailbox <> p_mbox OR ls_old-donebox <> p_done OR
       ls_old-movemode <> p_move.
      cv_msg = 'Mail identity in use: create a new profile.'.
      EXIT.
    ENDIF.
  ENDIF.
  lv_revision = ls_old-revision.
  IF lv_revision >= '9999999999'.
    cv_msg = 'Profile revision exhausted; create a new profile.'.
    EXIT.
  ENDIF.
  IF p_crsrc = 'S' AND p_pwd IS INITIAL AND
     ls_old-credrev IS INITIAL.
    cv_msg = 'Migration: reenter password for namespace storage.'.
    EXIT.
  ENDIF.

  ls_prof = ls_old.
  ADD 1 TO lv_revision.
  ls_prof-revision = lv_revision.
  ls_prof-profile  = p_prof.
  ls_prof-descr    = p_descr.
  ls_prof-active   = p_act.
  ls_prof-host     = p_host.
  ls_prof-port     = p_port.
  ls_prof-security = p_sec.
  ls_prof-verify   = p_ver.
  ls_prof-username = p_user.
  ls_prof-credsrc  = p_crsrc.
  ls_prof-mailbox  = p_mbox.
  ls_prof-donebox  = p_done.
  ls_prof-movemode = p_move.
  ls_prof-hprog    = p_hprog.
  ls_prof-hform    = p_hform.
  ls_prof-maxmail  = p_maxm.
  ls_prof-maxmb    = p_maxmb.
  ls_prof-timeout  = p_tout.
  ls_prof-retdays  = p_ret.
  IF NOT lv_new IS INITIAL.
    ls_prof-crdat = sy-datum.
    ls_prof-crusr = sy-uname.
  ENDIF.
  ls_prof-chdat = sy-datum.
  ls_prof-chtim = sy-uzeit.
  ls_prof-chusr = sy-uname.

  IF p_crsrc = 'S' AND NOT p_pwd IS INITIAL.
    ls_prof-credrev = ls_prof-revision.
    PERFORM write_cred USING ls_prof CHANGING cv_ok cv_msg.
    IF cv_ok IS INITIAL.
      EXIT.
    ENDIF.
    ls_prof-pwdat = sy-datum.
    ls_prof-pwusr = sy-uname.
  ENDIF.

  PERFORM write_conf USING ls_prof CHANGING cv_ok cv_msg.
  IF cv_ok IS INITIAL.
    EXIT.
  ENDIF.

  MODIFY zche_imap_profile FROM ls_prof.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    CLEAR cv_ok.
    cv_msg = 'Profile publish failed; prior revision is active.'.
    EXIT.
  ENDIF.
  COMMIT WORK AND WAIT.
  IF sy-subrc <> 0.
    CLEAR cv_ok.
    cv_msg = 'Profile commit failed; check active revision.'.
    EXIT.
  ENDIF.
  IF ls_old-credsrc = 'S' AND ls_old-credrev IS NOT INITIAL
     AND ( ls_prof-credsrc <> 'S' OR
           ls_old-credrev <> ls_prof-credrev ).
    PERFORM delete_old_credential USING ls_old CHANGING cv_msg.
    IF cv_msg IS NOT INITIAL.
      CLEAR p_pwd.
      cv_ok = 'X'.
      EXIT.
    ENDIF.
  ENDIF.
  CLEAR p_pwd.
  cv_ok = 'X'.
  CONCATENATE 'Profile saved:' p_prof INTO cv_msg
              SEPARATED BY space.
ENDFORM.

*---------------------------------------------------------------
FORM write_conf USING    is_prof TYPE zche_imap_profile
                CHANGING cv_ok   TYPE c
                         cv_msg  TYPE c.
  DATA: lt_lines     TYPE ty_t_line,
        ls_line      TYPE zche_imap_s_line,
        lv_path(255) TYPE c,
        lv_num(10)   TYPE c,
        lv_dsmsg(100) TYPE c,
        lv_key(28) TYPE c.

  DEFINE add_line.
    CONCATENATE &1 &2 INTO ls_line-text.
    APPEND ls_line TO lt_lines.
  END-OF-DEFINITION.

  ls_line-text = '# Written by ZCHE_IMAP_CONFIG; do not edit by hand'.
  APPEND ls_line TO lt_lines.
  PERFORM storage_key USING is_prof-profile CHANGING lv_key.
  add_line 'PROFILE=' lv_key.
  add_line 'REVISION=' is_prof-revision.
  add_line 'CREDSRC=' is_prof-credsrc.
  add_line 'CREDREV=' is_prof-credrev.
  add_line 'HOST=' is_prof-host.
  lv_num = is_prof-port.
  SHIFT lv_num LEFT DELETING LEADING '0'.
  add_line 'PORT=' lv_num.
  add_line 'SECURITY=' is_prof-security.
  add_line 'VERIFY=' is_prof-verify.
  add_line 'USER=' is_prof-username.
  add_line 'MAILBOX=' is_prof-mailbox.
  add_line 'DONEBOX=' is_prof-donebox.
  add_line 'MOVEMODE=' is_prof-movemode.
  lv_num = is_prof-maxmb.
  SHIFT lv_num LEFT DELETING LEADING '0'.
  add_line 'MAXMB=' lv_num.
  lv_num = is_prof-timeout.
  SHIFT lv_num LEFT DELETING LEADING '0'.
  add_line 'TIMEOUT=' lv_num.
  lv_num = is_prof-retdays.
  SHIFT lv_num LEFT DELETING LEADING '0'.
  add_line 'RETENTION=' lv_num.
  add_line 'CODEPAGE=' gv_filecp.

  CONCATENATE gv_root 'conf' gv_sep lv_key '_'
              is_prof-revision '.conf'
              INTO lv_path.
  PERFORM write_text_file USING lv_path lt_lines
                          CHANGING cv_ok lv_dsmsg.
  IF cv_ok IS INITIAL.
    CONCATENATE 'Cannot write config file (S_DATASET?):' lv_dsmsg
                INTO cv_msg SEPARATED BY space.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
* Password file. The password is never written to the table;
* this file is not read back from SAP.
*---------------------------------------------------------------
FORM write_cred USING is_prof TYPE zche_imap_profile
                CHANGING cv_ok  TYPE c
                         cv_msg TYPE c.
  DATA: lt_lines      TYPE ty_t_line,
        ls_line       TYPE zche_imap_s_line,
        lv_path(255)  TYPE c,
        lv_dsmsg(100) TYPE c,
        lv_key(28) TYPE c.

  CONCATENATE 'PASSWORD=' p_pwd INTO ls_line-text.
  APPEND ls_line TO lt_lines.
  PERFORM storage_key USING is_prof-profile CHANGING lv_key.
  CONCATENATE gv_root 'secret' gv_sep lv_key '_'
              is_prof-credrev '.cred' INTO lv_path.
  PERFORM write_text_file USING lv_path lt_lines
                          CHANGING cv_ok lv_dsmsg.
  CLEAR: lt_lines, ls_line.
  IF cv_ok IS INITIAL.
    CONCATENATE 'Cannot write password file (S_DATASET?):' lv_dsmsg
                INTO cv_msg SEPARATED BY space.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------
FORM delete_profile.
  DATA lv_ok(1) TYPE c.

  PERFORM profile_auth USING p_prof '02' CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    EXIT.
  ENDIF.
  PERFORM table_auth USING 'ZCHE_IMAP_PROFILE' 'U' CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'E' 'No profile change authorization'.
    EXIT.
  ENDIF.
  PERFORM profile_valid USING p_prof CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'E' 'Invalid profile name'.
    EXIT.
  ENDIF.
  IF gv_setup IS INITIAL.
    PERFORM show_msg USING 'E' 'Setup missing or wrong host'.
    EXIT.
  ENDIF.
  PERFORM profile_lock USING p_prof CHANGING lv_ok.
  IF lv_ok IS INITIAL.
    PERFORM show_msg USING 'S' 'Profile in use; try again'.
    EXIT.
  ENDIF.
  PERFORM delete_profile_locked.
  PERFORM profile_unlock USING p_prof.
ENDFORM.

FORM delete_profile_locked.
  DATA: lv_answer(1)  TYPE c,
        lv_ok(1)      TYPE c,
        lv_q(200)     TYPE c,
        lv_path(255)  TYPE c,
        lv_key(28) TYPE c,
        lv_logged LIKE zche_imap_log-profile,
        ls_prof TYPE zche_imap_profile.

  SELECT SINGLE profile FROM zche_imap_log INTO lv_logged
    WHERE profile = p_prof.
  IF sy-subrc = 0.
    PERFORM show_msg USING 'S'
      'Profile has mail history: deactivate; use a new name.'.
    EXIT.
  ENDIF.
  SELECT SINGLE * FROM zche_imap_profile INTO ls_prof
    WHERE profile = p_prof.
  IF sy-subrc <> 0.
    PERFORM show_msg USING 'S' 'Profile not found'.
    EXIT.
  ENDIF.
  IF p_prof IS INITIAL.
    PERFORM show_msg USING 'E' 'Enter the profile name.'.
  ENDIF.
  CONCATENATE 'Delete profile' p_prof
    'and current files? Older revisions need admin cleanup.'
    INTO lv_q SEPARATED BY space.
  PERFORM fm_exists USING 'POPUP_TO_CONFIRM' CHANGING lv_ok.
  IF NOT lv_ok IS INITIAL.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Delete profile'
        text_question         = lv_q
        text_button_1         = 'Delete'
        text_button_2         = 'Cancel'
        display_cancel_button = ' '
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1.
  ELSE.
    CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
      EXPORTING
        textline1 = lv_q(70)
        titel     = 'Delete profile'
      IMPORTING
        answer    = lv_answer
      EXCEPTIONS
        OTHERS    = 1.
    IF lv_answer = 'J'.
      lv_answer = '1'.
    ENDIF.
  ENDIF.
  IF lv_answer <> '1'.
    EXIT.
  ENDIF.

  DELETE FROM zche_imap_profile WHERE profile = p_prof.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    PERFORM show_msg USING 'S' 'Profile delete failed'.
    EXIT.
  ENDIF.
  COMMIT WORK.
  PERFORM storage_key USING p_prof CHANGING lv_key.
  IF NOT gv_setup IS INITIAL.
    CONCATENATE gv_root 'conf' gv_sep lv_key '_'
                ls_prof-revision '.conf' INTO lv_path.
    PERFORM delete_file USING lv_path.
    IF ls_prof-credsrc = 'S'.
      CONCATENATE gv_root 'secret' gv_sep lv_key '_'
                  ls_prof-credrev '.cred' INTO lv_path.
    ELSE.
      CONCATENATE gv_root 'secret' gv_sep lv_key '.cred'
                  INTO lv_path.
    ENDIF.
    PERFORM delete_file USING lv_path.
  ENDIF.
  PERFORM show_msg USING 'S'
    'Profile deleted; review old conf/secret revisions with admin.'.
ENDFORM.

*---------------------------------------------------------------
* F8: save and test the connection (list output)
*---------------------------------------------------------------
FORM save_and_test.
  DATA: lt_out      TYPE ty_t_line,
        ls_out      TYPE zche_imap_s_line,
        lv_ok(1)    TYPE c,
        lv_msg(255) TYPE c,
        lv_ver(20)  TYPE c,
        lv_w1(10)   TYPE c,
        lv_step(12) TYPE c,
        lv_w3(10)   TYPE c,
        lv_rest(128) TYPE c,
        lv_key(28) TYPE c,
        lv_par(80) TYPE c,
        ls_prof TYPE zche_imap_profile.

  WRITE: / 'Profile:', p_prof, p_descr.
  ULINE.
  PERFORM save_profile CHANGING lv_ok lv_msg.
  IF lv_ok IS INITIAL.
    FORMAT COLOR COL_NEGATIVE INTENSIFIED OFF.
    WRITE: / 'Not saved:', lv_msg(120).
    FORMAT COLOR OFF.
    EXIT.
  ENDIF.
  WRITE: / lv_msg(120).
  SKIP.
  WRITE: / 'Connection test'.

  SELECT SINGLE * FROM zche_imap_profile INTO ls_prof
    WHERE profile = p_prof.
  PERFORM storage_key USING p_prof CHANGING lv_key.
  CONCATENATE lv_key ls_prof-revision INTO lv_par
              SEPARATED BY space.
  PERFORM call_cmd USING 'ZCHE_IMAP_TEST' lv_par
                   CHANGING lt_out lv_ok lv_msg.
  LOOP AT lt_out INTO ls_out.
    IF ls_out-text(8) = 'VERSION '.
      lv_ver = ls_out-text+8.
      CONTINUE.
    ENDIF.
    IF ls_out-text(5) = 'STEP '.
*     "STEP LOGIN OK detail" -> "  OK  LOGIN  detail"
      CLEAR: lv_w1, lv_step, lv_w3, lv_rest.
      SPLIT ls_out-text AT space INTO lv_w1 lv_step lv_w3 lv_rest.
      FORMAT COLOR COL_POSITIVE INTENSIFIED OFF.
      WRITE: / '  OK '.
      FORMAT COLOR OFF.
      WRITE: lv_step, lv_rest(100).
    ELSE.
      WRITE: / '  ', ls_out-text(110).
    ENDIF.
  ENDLOOP.
  IF lv_ok IS INITIAL.
    PERFORM write_error USING lv_msg.
  ELSE.
    SKIP.
    FORMAT COLOR COL_POSITIVE.
    WRITE: / 'Connection successful. Profile is ready to use.'.
    FORMAT COLOR OFF.
  ENDIF.
  IF NOT lv_ver IS INITIAL AND lv_ver <> gc_version.
    SKIP.
    WRITE: / 'Warning: script version on server', lv_ver,
             'SAP side', gc_version, '- use the same version.'.
  ENDIF.
ENDFORM.

FORM delete_old_credential USING is_prof TYPE zche_imap_profile
                           CHANGING cv_warning TYPE c.
  DATA: lv_path(255) TYPE c, lv_key(28) TYPE c.
  PERFORM storage_key USING is_prof-profile CHANGING lv_key.
  CONCATENATE gv_root 'secret' gv_sep lv_key '_'
              is_prof-credrev '.cred' INTO lv_path.
  TRY.
    DELETE DATASET lv_path.
    IF sy-subrc <> 0 AND sy-subrc <> 4.
      cv_warning = 'Saved; Basis must remove the previous secret'.
    ENDIF.
  CATCH cx_sy_file_authority.
    cv_warning = 'Saved; S_DATASET 06 needed to remove old secret'.
  ENDTRY.
ENDFORM.
