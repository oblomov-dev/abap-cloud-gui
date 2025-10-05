CLASS z2ui5_cl_gui_list DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.
    METHODS write
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS new_line
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS new_page
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS skip
      IMPORTING
        val           TYPE i OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS uline
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS write_as_checkbox
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS write_as_symbol
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_gui_list.
    METHODS stringify
      RETURNING
        VALUE(result) TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS z2ui5_cl_gui_list IMPLEMENTATION.
  METHOD new_line.



  ENDMETHOD.
  METHOD new_page.



  ENDMETHOD.
  METHOD write.



  ENDMETHOD.
  METHOD skip.

  ENDMETHOD.

  METHOD uline.

  ENDMETHOD.

  METHOD write_as_checkbox.

  ENDMETHOD.

  METHOD write_as_symbol.

  ENDMETHOD.

  METHOD stringify.

  ENDMETHOD.

ENDCLASS.
