CLASS z2ui5_cl_gui_alv DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.

    CLASS-METHODS factory
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_alv.

    METHODS display
      IMPORTING
        val TYPE clike.

    METHODS stringify
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS z2ui5_cl_gui_alv IMPLEMENTATION.
  METHOD display.



  ENDMETHOD.
  METHOD factory.

  ENDMETHOD.

  METHOD stringify.

  ENDMETHOD.

ENDCLASS.
