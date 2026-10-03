*&---------------------------------------------------------------------*
*& cloud gui - print the output of a report
*&
*& Called by z2ui5_cl_cgui_report (Print) with SUBMIT ... AND RETURN:
*& takes the title and the text lines of the output from the ABAP memory
*& (ID cv_memory_id), writes them into a spool request of the user's
*& output device (LP01 / LOCL when he has none) without printing it, and
*& hands the number of the spool request back through the same memory ID
*& - 0 when no request could be created.
*&---------------------------------------------------------------------*
REPORT z2ui5_cgui_print LINE-SIZE 255 NO STANDARD PAGE HEADING.

CONSTANTS cv_memory_id TYPE c LENGTH 20 VALUE 'Z2UI5_CGUI_PRINT'.

START-OF-SELECTION.
  PERFORM print.

FORM print.

  DATA lt_line   TYPE string_table.
  DATA lv_title  TYPE string.
  DATA lv_spool  TYPE i.
  DATA ls_params TYPE pri_params.
  DATA lv_valid  TYPE c LENGTH 1.
  DATA lv_text   TYPE c LENGTH 68.
  DATA lt_dest   TYPE STANDARD TABLE OF pri_params-pdest WITH EMPTY KEY.

  IMPORT lines = lt_line title = lv_title FROM MEMORY ID cv_memory_id.
  FREE MEMORY ID cv_memory_id.
  IF lt_line IS INITIAL.
    EXPORT spool = lv_spool TO MEMORY ID cv_memory_id.
    RETURN.
  ENDIF.

  lv_text = lv_title.
  " the user's default device first, then the usual ones
  lt_dest = VALUE #( ( space ) ( 'LP01' ) ( 'LOCL' ) ).
  LOOP AT lt_dest INTO DATA(lv_dest).
    CLEAR: ls_params, lv_valid.
    CALL FUNCTION 'GET_PRINT_PARAMETERS'
      EXPORTING
        destination    = lv_dest
        immediately    = space
        release        = space
        new_list_id    = abap_true
        line_size      = 255
        list_text      = lv_text
        no_dialog      = abap_true
      IMPORTING
        out_parameters = ls_params
        valid          = lv_valid
      EXCEPTIONS
        OTHERS         = 1.
    IF sy-subrc = 0 AND lv_valid IS NOT INITIAL AND ls_params-pdest IS NOT INITIAL.
      EXIT.
    ENDIF.
    CLEAR lv_valid.
  ENDLOOP.
  IF lv_valid IS INITIAL.
    EXPORT spool = lv_spool TO MEMORY ID cv_memory_id.
    RETURN.
  ENDIF.

  NEW-PAGE PRINT ON PARAMETERS ls_params NO DIALOG.
  LOOP AT lt_line INTO DATA(lv_line).
    WRITE / lv_line.
  ENDLOOP.
  NEW-PAGE PRINT OFF.
  lv_spool = sy-spono.

  EXPORT spool = lv_spool TO MEMORY ID cv_memory_id.

ENDFORM.
