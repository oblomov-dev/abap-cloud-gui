CLASS z2ui5_cx_cgui_error DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA mv_text TYPE string.

    METHODS constructor
      IMPORTING
        val       TYPE clike          OPTIONAL
        !previous TYPE REF TO cx_root OPTIONAL
          PREFERRED PARAMETER val.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cx_cgui_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).
    CLEAR textid.
    mv_text = val.

  ENDMETHOD.

  METHOD if_message~get_text.

    result = mv_text.
    IF result IS INITIAL AND previous IS BOUND.
      result = previous->get_text( ).
    ENDIF.
    IF result IS INITIAL.
      result = `CGUI_UNKNOWN_ERROR`.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
