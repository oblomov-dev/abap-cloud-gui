CLASS z2ui5_cl_gui_sample_03 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_gui_sample_03 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA(lo_list) = NEW z2ui5_cl_gui_list( ).
    lo_list->write( `this is a list opoutput` ).

*    client->view_display( lo_screen->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
