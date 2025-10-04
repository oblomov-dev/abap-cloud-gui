CLASS z2ui5_cl_gui_selscreen DEFINITION PUBLIC.
  PUBLIC SECTION.
    METHODS screen_begin
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS screen_end
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS line_begin
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS line_end
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS block_begin
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS block_end
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS parameter
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS radiobutton
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS radiobutton_group
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS checkbox
      IMPORTING
                val           TYPE any
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS button
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS comment
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.
    METHODS select_option
      RETURNING VALUE(result) TYPE REF TO z2ui5_cl_gui_selscreen.

    METHODS stringify
      RETURNING
        value(result) TYPE string.

          PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS z2ui5_cl_gui_selscreen IMPLEMENTATION.
  METHOD checkbox.



  ENDMETHOD.
  METHOD parameter.



  ENDMETHOD.
  METHOD radiobutton.



  ENDMETHOD.
  METHOD radiobutton_group.



  ENDMETHOD.
  METHOD select_option.



  ENDMETHOD.
  METHOD block_begin.



  ENDMETHOD.
  METHOD block_end.



  ENDMETHOD.
  METHOD button.



  ENDMETHOD.
  METHOD comment.



  ENDMETHOD.
  METHOD line_begin.



  ENDMETHOD.
  METHOD line_end.



  ENDMETHOD.
  METHOD screen_begin.



  ENDMETHOD.
  METHOD screen_end.



  ENDMETHOD.

  METHOD stringify.

  ENDMETHOD.

ENDCLASS.
