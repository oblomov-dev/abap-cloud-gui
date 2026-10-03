"! cloud gui - check of the print and background paths in the ADT console
"! (F9), the same ways a report goes:
"!   Print       ABAP memory, SUBMIT z2ui5_cgui_print, the spool request,
"!               CONVERT_ABAPSPOOLJOB_2_PDF
"!   Background  the values in INDX(ZC) - deleted again by the program -,
"!               SUBMIT z2ui5_cgui_batch TO SAP-SPOOL with sample 10 (tree),
"!               the spool read back
"! Creates two spool requests that are not printed (SP01)
CLASS z2ui5_cl_cgui_print_check DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS print_check
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out.

    METHODS batch_check
      IMPORTING
        out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.



CLASS z2ui5_cl_cgui_print_check IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( `--- Print` ) ##NO_TEXT.
    print_check( out ).
    out->write( `--- Background` ) ##NO_TEXT.
    batch_check( out ).

  ENDMETHOD.

  METHOD batch_check.

    DATA ls_params TYPE pri_params.
    DATA lv_valid  TYPE c LENGTH 1.
    DATA lv_id     TYPE c LENGTH 22.
    DATA lv_class  TYPE seoclsname VALUE 'Z2UI5_CL_CGUI_SAMPLE_10'.
    DATA lt_buffer TYPE STANDARD TABLE OF char255 WITH EMPTY KEY.
    DATA lv_before TYPE tsp01-rqident.
    DATA lv_after  TYPE tsp01-rqident.

    DATA(lt_value) = VALUE z2ui5_cl_cgui_variant=>ty_t_value(
        ( name = `P_TREE` kind = z2ui5_cl_cgui_variant=>cs_kind-parameter low = `X` ) ).
    TRY.
        lv_id = cl_system_uuid=>create_uuid_c22_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.

    CALL FUNCTION 'GET_PRINT_PARAMETERS'
      EXPORTING
        destination    = 'LP01'
        immediately    = space
        release        = space
        new_list_id    = abap_true
        no_dialog      = abap_true
      IMPORTING
        out_parameters = ls_params
        valid          = lv_valid
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc <> 0 OR lv_valid IS INITIAL.
      out->write( `No print parameters for LP01` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    SELECT MAX( rqident ) FROM tsp01 WHERE rqowner = @sy-uname INTO @lv_before.
    " the way of Execute in Background, without the job
    EXPORT values = lt_value TO DATABASE indx(zc) ID lv_id.
    SUBMIT z2ui5_cgui_batch WITH p_class = lv_class
                            WITH p_id    = lv_id
                            TO SAP-SPOOL SPOOL PARAMETERS ls_params WITHOUT SPOOL DYNPRO
                            AND RETURN.
    SELECT MAX( rqident ) FROM tsp01 WHERE rqowner = @sy-uname INTO @lv_after.
    IMPORT values = lt_value FROM DATABASE indx(zc) ID lv_id.
    DATA(lv_left) = xsdbool( sy-subrc = 0 ).
    " the check leaves nothing behind - the program deletes the values
    " itself, a failed run does not
    DELETE FROM DATABASE indx(zc) ID lv_id.
    " the values of the first check run, left by the upper case P_ID
    DELETE FROM DATABASE indx(zc) ID '0YbityAt7z6lqoufwqTW00'.
    out->write( |Spool request: { lv_after } (before { lv_before }), values left by the program: { lv_left }| ) ##NO_TEXT.
    IF lv_after <= lv_before.
      RETURN.
    ENDIF.

    CALL FUNCTION 'RSPO_RETURN_ABAP_SPOOLJOB'
      EXPORTING
        rqident = lv_after
      TABLES
        buffer  = lt_buffer
      EXCEPTIONS
        OTHERS  = 1.
    out->write( |RSPO_RETURN_ABAP_SPOOLJOB: subrc { sy-subrc }, { lines( lt_buffer ) } lines| ) ##NO_TEXT.
    LOOP AT lt_buffer INTO DATA(lv_line) TO 12.
      out->write( condense( val = lv_line del = ` ` ) ).
    ENDLOOP.

  ENDMETHOD.

  METHOD print_check.

    DATA lv_spool   TYPE i.
    DATA lv_rqident TYPE tsp01-rqident.
    DATA lv_pdf     TYPE xstring.
    DATA lv_program TYPE c LENGTH 40.

    DATA(lt_line) = VALUE string_table( ( `cloud gui - print check` )
                                        ( `` )
                                        ( |Line 1 { sy-datum DATE = USER } { sy-uzeit TIME = USER }| )
                                        ( `Line 2 - umlauts: äöüß` ) ).
    DATA(lv_title) = `cgui print check` ##NO_TEXT.

    EXPORT lines = lt_line title = lv_title TO MEMORY ID z2ui5_cl_cgui_report=>cv_cgui_print_memory.
    lv_program = z2ui5_cl_cgui_report=>cv_cgui_print_program.
    TRY.
        SUBMIT (lv_program) AND RETURN.
      CATCH cx_root INTO DATA(lx_submit).
        out->write( |SUBMIT failed: { lx_submit->get_text( ) }| ) ##NO_TEXT.
        RETURN.
    ENDTRY.
    IMPORT spool = lv_spool FROM MEMORY ID z2ui5_cl_cgui_report=>cv_cgui_print_memory.
    FREE MEMORY ID z2ui5_cl_cgui_report=>cv_cgui_print_memory.
    out->write( |Spool request: { lv_spool }| ) ##NO_TEXT.
    IF lv_spool IS INITIAL.
      out->write( `No spool request - no valid output device (GET_PRINT_PARAMETERS)` ) ##NO_TEXT.
      RETURN.
    ENDIF.

    lv_rqident = lv_spool.
    DATA(lv_function) = `CONVERT_ABAPSPOOLJOB_2_PDF`.
    CALL FUNCTION lv_function
      EXPORTING
        src_spoolid     = lv_rqident
        no_dialog       = abap_true
        " the PDF as xstring in BIN_FILE (note 1320163)
        pdf_destination = 'X'
      IMPORTING
        bin_file    = lv_pdf
      EXCEPTIONS
        OTHERS      = 1.
    out->write( |CONVERT_ABAPSPOOLJOB_2_PDF: subrc { sy-subrc }, PDF { xstrlen( lv_pdf ) } bytes| ) ##NO_TEXT.
    IF xstrlen( lv_pdf ) > 4.
      DATA lv_head TYPE x LENGTH 4.
      lv_head = lv_pdf.
      " %PDF is 25504446
      out->write( |PDF starts with: { lv_head } (25504446 = %PDF)| ) ##NO_TEXT.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
