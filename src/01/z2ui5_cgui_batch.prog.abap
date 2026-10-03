*&---------------------------------------------------------------------*
*& cloud gui - background run of a report class
*&
*& Started as a job by z2ui5_cl_cgui_report (Execute in Background): reads
*& the values of the selection screen from the data cluster INDX(ZC) under
*& p_id, runs the report class p_class without a browser and writes its
*& output into the spool - the list line by line, the ALV with
*& CL_SALV_TABLE. The messages of the run go into the job log.
*&---------------------------------------------------------------------*
REPORT z2ui5_cgui_batch.

PARAMETERS p_class TYPE seoclsname OBLIGATORY.
" the key of INDX(ZC) is a UUID with lower case letters
PARAMETERS p_id    TYPE char22 LOWER CASE OBLIGATORY.

START-OF-SELECTION.
  PERFORM run.

FORM run.

  DATA lt_value  TYPE z2ui5_cl_cgui_variant=>ty_t_value.
  DATA lo_report TYPE REF TO z2ui5_cl_cgui_report.
  DATA lo_list   TYPE REF TO z2ui5_cl_cgui_list.
  DATA lo_alv    TYPE REF TO z2ui5_cl_cgui_alv.
  DATA lr_data   TYPE REF TO data.
  DATA lt_msg    TYPE z2ui5_cl_cgui_report=>ty_t_cgui_message.
  DATA lo_salv   TYPE REF TO cl_salv_table.
  FIELD-SYMBOLS <tab> TYPE STANDARD TABLE.

  IMPORT values = lt_value FROM DATABASE indx(zc) ID p_id.
  IF sy-subrc <> 0.
    MESSAGE 'The values of the run were not found'(001) TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  DELETE FROM DATABASE indx(zc) ID p_id.

  TRY.
      CREATE OBJECT lo_report TYPE (p_class).
    CATCH cx_sy_create_object_error cx_sy_move_cast_error.
      MESSAGE 'The report class cannot be started'(002) TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  lo_report->cgui_run_in_background( EXPORTING values   = lt_value
                                     IMPORTING list     = lo_list
                                               alv      = lo_alv
                                               alv_data = lr_data
                                               messages = lt_msg ).

  LOOP AT lt_msg INTO DATA(ls_msg).
    IF ls_msg-type = 'E' OR ls_msg-type = 'A'.
      MESSAGE ls_msg-text TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE ls_msg-text TYPE 'S'.
    ENDIF.
  ENDLOOP.

  IF lo_list IS BOUND.
    LOOP AT lo_list->to_text( ) INTO DATA(lv_line).
      WRITE / lv_line.
    ENDLOOP.
  ENDIF.

  IF lo_alv IS BOUND AND lr_data IS BOUND.
    ASSIGN lr_data->* TO <tab>.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_salv
                                CHANGING  t_table      = <tab> ).
        lo_salv->get_functions( )->set_all( abap_true ).
        lo_salv->get_columns( )->set_optimize( abap_true ).
        lo_salv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDIF.

ENDFORM.
