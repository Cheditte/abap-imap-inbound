*---------------------------------------------------------------
* ZIMAP_IO  (LEGACY: non-Unicode systems, 4.6C and later)
* In SAP the content of this file is loaded as the include ZIMAP_IO
* (ZIMAP_INSTALL picks it automatically). Text files are
* read and written in the system code page. On 6.10 and later the
* "Unicode checks active" flag of the programs must be off.
*---------------------------------------------------------------
FORM read_text_file USING    iv_path  TYPE c
                    CHANGING ct_lines TYPE ty_t_line
                             cv_ok    TYPE c.
  DATA: ls_line     TYPE zimap_s_line,
        lv_msg(100) TYPE c.

  CLEAR: ct_lines, cv_ok.
  OPEN DATASET iv_path FOR INPUT IN TEXT MODE MESSAGE lv_msg.
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.
  DO.
    CLEAR ls_line.
    READ DATASET iv_path INTO ls_line-text.
    IF sy-subrc <> 0.
      EXIT.
    ENDIF.
    APPEND ls_line TO ct_lines.
  ENDDO.
  CLOSE DATASET iv_path.
  cv_ok = 'X'.
ENDFORM.

*---------------------------------------------------------------
FORM write_text_file USING    iv_path  TYPE c
                              it_lines TYPE ty_t_line
                     CHANGING cv_ok    TYPE c
                              cv_msg   TYPE c.
  DATA ls_line TYPE zimap_s_line.

  CLEAR: cv_ok, cv_msg.
  OPEN DATASET iv_path FOR OUTPUT IN TEXT MODE MESSAGE cv_msg.
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.
  LOOP AT it_lines INTO ls_line.
    TRANSFER ls_line-text TO iv_path.
  ENDLOOP.
  CLOSE DATASET iv_path.
  cv_ok = 'X'.
ENDFORM.

*---------------------------------------------------------------
FORM delete_file USING iv_path TYPE c.
  DELETE DATASET iv_path.
ENDFORM.

*---------------------------------------------------------------
* Reads an attachment file as rows of 1024 bytes. cv_len is the
* real size; SO_*, GOS and BDS functions use this format.
*---------------------------------------------------------------
FORM read_binary_file USING    iv_path TYPE c
                      CHANGING ct_bin  TYPE ty_t_bin
                               cv_len  TYPE i
                               cv_ok   TYPE c.
  DATA: ls_bin      TYPE ty_bin,
        lv_len      TYPE i,
        lv_rc       TYPE i,
        lv_msg(100) TYPE c.

  CLEAR: ct_bin, cv_len, cv_ok.
  OPEN DATASET iv_path FOR INPUT IN BINARY MODE MESSAGE lv_msg.
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.
  DO.
    CLEAR: ls_bin, lv_len.
    READ DATASET iv_path INTO ls_bin-data LENGTH lv_len.
    lv_rc = sy-subrc.
    IF lv_len > 0.
      APPEND ls_bin TO ct_bin.
      cv_len = cv_len + lv_len.
    ENDIF.
    IF lv_rc <> 0.
      EXIT.
    ENDIF.
  ENDDO.
  CLOSE DATASET iv_path.
  cv_ok = 'X'.
ENDFORM.
