"! Converter in the ADT console - F9 converts the classic reports of
"! mt_program and writes the report classes and their notes. Put in the
"! names of your own reports; nothing is changed in the system.
CLASS z2ui5_cl_cgui_converter_run DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    DATA mt_program TYPE string_table.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_cgui_converter_run IMPLEMENTATION.

  METHOD constructor.

    " selection screens, CL_SALV_TABLE and REUSE_ALV_GRID_DISPLAY
    mt_program = VALUE #( ( `DEMO_SEL_SCREEN_WITH_TABSTRIP` )
                          ( `DEMO_SELECTION_SCREEN_EVENTS` )
                          ( `SALV_DEMO_TABLE_SIMPLE` )
                          ( `ROIF_CEPC` ) ) ##NO_TEXT.

  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.

    LOOP AT mt_program INTO DATA(lv_program).
      DATA(ls_result) = z2ui5_cl_cgui_converter=>convert_program( lv_program ).
      out->write( |===== { lv_program } =====| ) ##NO_TEXT.
      out->write( ls_result-code ).
      out->write( `----- notes -----` ) ##NO_TEXT.
      LOOP AT ls_result-notes INTO DATA(lv_note).
        out->write( |- { lv_note }| ) ##NO_TEXT.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
